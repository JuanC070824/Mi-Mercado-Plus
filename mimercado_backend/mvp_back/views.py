from django.contrib.auth.hashers import make_password, check_password
from django.db import transaction, IntegrityError
from django.db.models import Q, Count, Sum, Max
from django.utils import timezone
from django.conf import settings
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.exceptions import ValidationError, NotFound, PermissionDenied
from rest_framework.throttling import ScopedRateThrottle
from . import serializers as s
from .models import (Usuario, UsuarioRol, Producto, Mercado, Puesto, Direccion,
                     Pedido, PedidoPuesto, PedidoDetalle, Cotizacion,
                     CotizacionPuesto, CotizacionDetalle, RepartidorMercado,
                     Categoria, UnidadMedida, HistorialEstado, EntregaParada)
from .authentication import issue_token
from .services import put_item, cart_payload, change_item, checkout, require_buyer, accept_quote, quote_total, lock_user
from .payments import pay_order
from .money import cents
from .dni import (consultar_dni, firmar_consulta, leer_consulta,
                  DniNoEncontrado, DniServicioNoDisponible)


def validated(cls, data):
    serializer=cls(data=data)
    serializer.is_valid(raise_exception=True)
    return serializer.validated_data


def user_payload(user, roles=None, rol_activo=None):
    if roles is None:
        roles=list(UsuarioRol.objects.filter(usuario_id=user.pk).values_list('rol_codigo',flat=True))
    payload={'id':user.pk,'nombres':user.nombres,
             'apellido_paterno':user.apellido_paterno,
             'apellido_materno':user.apellido_materno,
             'celular':user.celular,'correo':user.correo,'roles':roles,
             'fecha_nacimiento':user.fecha_nacimiento,
             'letra_grande':user.letra_grande,
             'sonido':user.sonido,'vibracion':user.vibracion}
    if rol_activo=='vendedor':
        puesto=Puesto.objects.filter(vendedor_id=user.pk,estado='activo').order_by('id').first()
        if puesto:
            payload.update({'puesto_id':puesto.pk,'mercado_id':puesto.mercado_id})
    elif rol_activo=='repartidor':
        asignacion=RepartidorMercado.objects.filter(
            repartidor_id=user.pk,fin_en__isnull=True).order_by('-inicio_en').first()
        if asignacion:
            payload['mercado_id']=asignacion.mercado_id
    return payload


def auth_payload(user, rol_activo=None):
    roles=list(UsuarioRol.objects.filter(usuario_id=user.pk).values_list('rol_codigo',flat=True))
    if rol_activo is None and len(roles)==1:
        rol_activo=roles[0]
    return {'token':issue_token(user),'token_type':'Bearer','expires_in':settings.AUTH_TOKEN_TTL_SECONDS,
            'rol_activo':rol_activo,'usuario':user_payload(user,roles,rol_activo)}

class RegistroView(APIView):
    permission_classes=[AllowAny]
    authentication_classes=[]
    throttle_classes=[ScopedRateThrottle]
    throttle_scope='registro'
    def post(self,request):
        data=validated(s.RegistroSerializer,request.data)
        password=data.pop('password')
        dni=data.pop('dni')
        dni_token=data.pop('dni_token')
        rol=data.pop('rol')
        direccion=data.pop('direccion',None)
        try:
            identidad=leer_consulta(dni_token,dni)
        except ValueError as exc:
            raise ValidationError({'dni':str(exc)})
        data.update({
            'nombres':identidad['nombres'],
            'apellido_paterno':identidad['apellido_paterno'],
            'apellido_materno':identidad.get('apellido_materno') or None,
        })
        data['correo']=data.get('correo','').lower() or None
        if Usuario.objects.filter(celular=data['celular']).exists() or (data['correo'] and Usuario.objects.filter(correo__iexact=data['correo']).exists()):
            raise ValidationError('El celular o correo ya está registrado.')
        try:
            with transaction.atomic():
                user=Usuario.objects.create(**data,password_hash=make_password(password))
                UsuarioRol.objects.create(usuario_id=user.pk,rol_codigo=rol)
                if rol=='comprador' and direccion and str(direccion.get('direccion','')).strip():
                    Direccion.objects.create(
                        comprador_id=user.pk,
                        direccion=str(direccion['direccion']).strip(),
                        referencia=str(direccion.get('referencia') or '').strip() or None,
                        latitud=direccion.get('latitud'),
                        longitud=direccion.get('longitud'),
                        principal=True,
                    )
        except IntegrityError:
            raise ValidationError('No se pudo registrar: datos duplicados o catálogo de roles no instalado.')
        return Response(auth_payload(user,rol),status=201)

class DniView(APIView):
    permission_classes=[AllowAny]
    authentication_classes=[]
    throttle_classes=[ScopedRateThrottle]
    throttle_scope='dni'
    def post(self,request):
        data=validated(s.DniSerializer,request.data)
        try:
            identidad=consultar_dni(data['dni'])
        except DniNoEncontrado as exc:
            return Response({'detail':str(exc)},status=404)
        except DniServicioNoDisponible as exc:
            return Response({'detail':str(exc)},status=503)
        return Response({
            'nombres':identidad['nombres'],
            'apellido_paterno':identidad['apellido_paterno'],
            'apellido_materno':identidad['apellido_materno'],
            'registro_token':firmar_consulta(identidad),
        })

class LoginView(APIView):
    permission_classes=[AllowAny]
    authentication_classes=[]
    throttle_classes=[ScopedRateThrottle]
    throttle_scope='login'
    def post(self,request):
        data=validated(s.LoginSerializer,request.data)
        user=Usuario.objects.filter(celular=data['celular']).first()
        if user is None:
            make_password(data['password'])  # costo similar para un celular inexistente
        password_ok=False
        if user is not None:
            def actualizar_hash(password):
                user.password_hash=make_password(password)
                user.save(update_fields=['password_hash'])
            password_ok=check_password(data['password'],user.password_hash,setter=actualizar_hash)
        if user is None or not password_ok or user.estado!='activo':
            return Response({'detail':'Celular o contraseña incorrectos.'},status=401)
        roles=list(UsuarioRol.objects.filter(usuario_id=user.pk).values_list('rol_codigo',flat=True))
        rol_solicitado=data.get('rol')
        if rol_solicitado and rol_solicitado not in roles:
            return Response({'detail':'Esta cuenta no tiene el perfil seleccionado.','roles':roles},status=403)
        return Response(auth_payload(user,rol_solicitado))

class PerfilView(APIView):
    def get(self,request):
        roles=list(UsuarioRol.objects.filter(usuario_id=request.user.pk).values_list('rol_codigo',flat=True))
        activo=roles[0] if len(roles)==1 else None
        return Response(user_payload(request.user,roles,activo))
    def patch(self,request):
        data=validated(s.PerfilActualizarSerializer,request.data)
        celular=data.get('celular',request.user.celular)
        correo=(data.get('correo',request.user.correo) or '').strip().lower() or None
        if celular!=request.user.celular:
            if not check_password(data.get('password_actual',''),request.user.password_hash):
                raise ValidationError({'password_actual':'Escribe tu contraseña actual para cambiar el celular.'})
            if Usuario.objects.filter(celular=celular).exclude(pk=request.user.pk).exists():
                raise ValidationError({'celular':'Este celular ya está registrado.'})
        if correo and Usuario.objects.filter(correo__iexact=correo).exclude(pk=request.user.pk).exists():
            raise ValidationError({'correo':'Este correo ya está registrado.'})
        request.user.celular=celular
        request.user.correo=correo
        campos=['celular','correo']
        for campo in ['sonido','vibracion']:
            if campo in data:
                setattr(request.user,campo,data[campo])
                campos.append(campo)
        try:
            request.user.save(update_fields=campos)
        except IntegrityError:
            raise ValidationError('El celular o correo ya pertenece a otra cuenta.')
        roles=list(UsuarioRol.objects.filter(usuario_id=request.user.pk).values_list('rol_codigo',flat=True))
        activo=roles[0] if len(roles)==1 else None
        return Response(user_payload(request.user,roles,activo))

class MercadosView(APIView):
    permission_classes=[AllowAny]
    def get(self,request):
        mercados=Mercado.objects.filter(estado='activo').order_by('nombre','id').values(
            'id','nombre','direccion','distrito','provincia','departamento','latitud','longitud'
        )
        return Response(list(mercados))

class PuestosView(APIView):
    permission_classes=[AllowAny]
    def get(self,request):
        rows=Puesto.objects.filter(estado='activo',mercado__estado='activo')
        market=request.query_params.get('mercado_id')
        if market:
            if not market.isdecimal():raise ValidationError('mercado_id debe ser entero.')
            rows=rows.filter(mercado_id=int(market))
        rows=rows.select_related('vendedor','categoria').order_by('nombre','id')
        return Response([{
            'id':p.pk,'nombre':p.nombre,'mercado_id':p.mercado_id,
            'casero':' '.join(filter(None,[p.vendedor.nombres,p.vendedor.apellido_paterno])),
            'categoria':p.categoria.nombre,'abierto':p.abierto,'foto_url':p.foto_url,
            'calificacion':0.0,'resenas':0,
        } for p in rows[:200]])

class CategoriasView(APIView):
    permission_classes=[AllowAny]
    def get(self,request):
        from .models import Categoria
        return Response(list(Categoria.objects.order_by('nombre','id').values('id','nombre')))

class VendedorPuestoView(APIView):
    def _validar_vendedor(self,request):
        if not UsuarioRol.objects.filter(
            usuario_id=request.user.pk,rol_codigo='vendedor').exists():
            raise PermissionDenied('Esta cuenta no tiene el perfil de vendedor.')

    def _actual(self,request):
        self._validar_vendedor(request)
        return Puesto.objects.select_related('mercado','categoria').filter(
            vendedor_id=request.user.pk,estado='activo').order_by('id').first()

    def _payload(self,puesto):
        return {
            'id':puesto.pk,'nombre':puesto.nombre,'numero':puesto.numero,
            'referencia':puesto.descripcion,'foto_url':puesto.foto_url,
            'abierto':puesto.abierto,
            'mercado':{
                'id':puesto.mercado_id,'nombre':puesto.mercado.nombre,
                'direccion':puesto.mercado.direccion,
                'distrito':puesto.mercado.distrito,
            },
            'categoria':{'id':puesto.categoria_id,'nombre':puesto.categoria.nombre},
        }

    def get(self,request):
        puesto=self._actual(request)
        return Response({'tiene_puesto':puesto is not None,
                         'puesto':self._payload(puesto) if puesto else None})

    def post(self,request):
        self._validar_vendedor(request)
        if Puesto.objects.filter(vendedor_id=request.user.pk,estado='activo').exists():
            raise ValidationError('Ya tienes un puesto activo. Puedes editarlo desde esta pantalla.')
        data=validated(s.PuestoVendedorSerializer,request.data)
        mercado=Mercado.objects.filter(pk=data['mercado_id'],estado='activo').first()
        if mercado is None:raise ValidationError({'mercado_id':'Selecciona un mercado activo.'})
        from .models import Categoria
        categoria=Categoria.objects.filter(pk=data['categoria_id']).first()
        if categoria is None:raise ValidationError({'categoria_id':'Selecciona una categoría válida.'})
        try:
            puesto=Puesto.objects.create(
                mercado=mercado,vendedor=request.user,categoria=categoria,
                nombre=data['nombre'].strip(),numero=data.get('numero','').strip() or None,
                descripcion=data.get('referencia','').strip() or None,
                abierto=False,estado='activo')
        except IntegrityError:
            raise ValidationError('Ese número de puesto ya está registrado en el mercado.')
        return Response(self._payload(puesto),status=201)

    def patch(self,request):
        puesto=self._actual(request)
        if puesto is None:raise NotFound('Aún no tienes un puesto activo.')
        data=validated(s.PuestoVendedorSerializer,request.data)
        mercado=Mercado.objects.filter(pk=data['mercado_id'],estado='activo').first()
        if mercado is None:raise ValidationError({'mercado_id':'Selecciona un mercado activo.'})
        from .models import Categoria
        categoria=Categoria.objects.filter(pk=data['categoria_id']).first()
        if categoria is None:raise ValidationError({'categoria_id':'Selecciona una categoría válida.'})
        puesto.mercado=mercado
        puesto.categoria=categoria
        puesto.nombre=data['nombre'].strip()
        puesto.numero=data.get('numero','').strip() or None
        puesto.descripcion=data.get('referencia','').strip() or None
        try:
            puesto.save(update_fields=['mercado','categoria','nombre','numero','descripcion'])
        except IntegrityError:
            raise ValidationError('Ese número de puesto ya está registrado en el mercado.')
        return Response(self._payload(puesto))

class VendedorInicioView(APIView):
    def _puesto(self, request):
        if not UsuarioRol.objects.filter(
            usuario_id=request.user.pk,
            rol_codigo='vendedor',
        ).exists():
            raise PermissionDenied('Esta cuenta no tiene el perfil de vendedor.')
        return Puesto.objects.select_related('mercado', 'categoria').filter(
            vendedor_id=request.user.pk,
            estado='activo',
        ).order_by('id').first()

    def get(self, request):
        puesto = self._puesto(request)
        if puesto is None:
            return Response({'tiene_puesto': False})

        activos = list(PedidoPuesto.objects.filter(
            puesto_id=puesto.pk,
        ).exclude(
            estado__in=['recogido', 'rechazado', 'cancelado'],
        ).select_related('pedido__comprador').order_by('pedido__creado_en', 'id'))

        cantidades = {
            fila['pedido_puesto_id']: fila['total']
            for fila in PedidoDetalle.objects.filter(
                pedido_puesto_id__in=[parte.pk for parte in activos],
            ).values('pedido_puesto_id').annotate(total=Count('id'))
        }

        estados = [parte.estado for parte in activos]
        pedidos = [{
            'id': parte.pedido_id,
            'cliente_nombre': (
                parte.pedido.comprador.nombres.split()[0]
                if parte.pedido.comprador.nombres.split() else 'Cliente'
            ),
            'cantidad_productos': cantidades.get(parte.pk, 0),
            'estado': parte.estado,
            'creado_en': parte.pedido.creado_en,
            'responder_antes': parte.responder_antes,
        } for parte in activos[:20]]

        hoy = timezone.localdate()
        cotizaciones = list(CotizacionPuesto.objects.filter(
            pedido_puesto__puesto_id=puesto.pk,
            cotizacion__estado='aceptada',
            pedido__creado_en__date=hoy,
        ).values('id', 'tasa_comision'))
        totales = {
            fila['cotizacion_puesto_id']: fila['total'] or 0
            for fila in CotizacionDetalle.objects.filter(
                cotizacion_puesto_id__in=[fila['id'] for fila in cotizaciones],
            ).values('cotizacion_puesto_id').annotate(total=Sum('subtotal'))
        }
        venta = sum(totales.values())
        comision = sum(
            totales.get(fila['id'], 0) * fila['tasa_comision']
            for fila in cotizaciones
        )

        return Response({
            'tiene_puesto': True,
            'puesto': {
                'id': puesto.pk,
                'nombre': puesto.nombre,
                'numero': puesto.numero,
                'descripcion': puesto.descripcion,
                'foto_url': puesto.foto_url,
                'abierto': puesto.abierto,
                'mercado': {
                    'id': puesto.mercado_id,
                    'nombre': puesto.mercado.nombre,
                },
                'categoria': puesto.categoria.nombre,
            },
            'atencion': {
                'nuevos': estados.count('pendiente'),
                'preparando': sum(
                    estado in ['aceptado', 'pesando', 'pesado', 'en_preparacion']
                    for estado in estados
                ),
                'listos': estados.count('listo'),
            },
            'pedidos_activos': pedidos,
            'resumen': {
                'ventas_centavos': round(venta * 100),
                'comision_centavos': round(comision * 100),
                'recibes_centavos': round((venta - comision) * 100),
            },
        })

    def patch(self, request):
        puesto = self._puesto(request)
        if puesto is None:
            raise NotFound('Aún no tienes un puesto activo.')
        data = validated(s.EstadoPuestoSerializer, request.data)
        puesto.abierto = data['abierto']
        puesto.save(update_fields=['abierto'])
        return Response({'abierto': puesto.abierto})

class ProductosView(APIView):
    permission_classes=[AllowAny]
    def get(self,request):
        rows=Producto.objects.filter(activo=True,puesto__estado='activo',puesto__mercado__estado='activo').order_by('id')
        for key in ['puesto_id','puesto__mercado_id']:
            value=request.query_params.get('mercado_id' if '__' in key else key)
            if value:
                if not value.isdecimal():raise ValidationError('El filtro debe ser entero.')
                rows=rows.filter(**{key:int(value)})
        return Response([{'id':p.pk,'puesto_id':p.puesto_id,'nombre':p.nombre,
            'unidad':p.unidad_codigo,'precio_unitario_centavos':cents(p.precio_unitario),
            'disponible':p.disponible,'foto_url':p.foto_url,
            'stock':None if p.stock is None else str(p.stock)} for p in rows[:200]])


def puesto_vendedor_actual(user):
    if not UsuarioRol.objects.filter(usuario_id=user.pk,rol_codigo='vendedor').exists():
        raise PermissionDenied('Esta cuenta no tiene el perfil de vendedor.')
    puesto=Puesto.objects.filter(vendedor_id=user.pk,estado='activo').order_by('id').first()
    if puesto is None:raise NotFound('Primero crea tu puesto en Mi puesto.')
    return puesto


def producto_payload(producto):
    return {
        'id':producto.pk,'puesto_id':producto.puesto_id,'nombre':producto.nombre,
        'unidad':producto.unidad_codigo,
        'precio_unitario_centavos':cents(producto.precio_unitario),
        'disponible':producto.disponible,'foto_url':producto.foto_url,
    }


class VendedorProductosView(APIView):
    def get(self,request):
        puesto=puesto_vendedor_actual(request.user)
        productos=Producto.objects.filter(puesto_id=puesto.pk,activo=True).order_by('nombre','id')
        return Response({
            'puesto_id':puesto.pk,
            'productos':[producto_payload(p) for p in productos],
            'unidades':list(UnidadMedida.objects.order_by('nombre').values(
                'codigo','nombre','permite_fraccion')),
            'iconos':s.ICONOS_PRODUCTO,
        })

    def post(self,request):
        puesto=puesto_vendedor_actual(request.user)
        data=validated(s.ProductoVendedorSerializer,request.data)
        if not UnidadMedida.objects.filter(pk=data['unidad_codigo']).exists():
            raise ValidationError({'unidad_codigo':'La unidad no existe en la base de datos.'})
        producto=Producto.objects.create(
            puesto=puesto,categoria_id=puesto.categoria_id,
            nombre=data['nombre'].strip(),unidad_codigo=data['unidad_codigo'],
            precio_unitario=data['precio_unitario'],disponible=data['disponible'],
            foto_url=data['icono'],activo=True,
        )
        return Response(producto_payload(producto),status=201)


class VendedorProductoView(APIView):
    def patch(self,request,producto_id):
        puesto=puesto_vendedor_actual(request.user)
        producto=Producto.objects.filter(
            pk=producto_id,puesto_id=puesto.pk,activo=True).first()
        if producto is None:raise NotFound('Producto no encontrado en tu catálogo.')
        data=validated(s.ProductoVendedorSerializer,request.data)
        if not UnidadMedida.objects.filter(pk=data['unidad_codigo']).exists():
            raise ValidationError({'unidad_codigo':'La unidad no existe en la base de datos.'})
        producto.nombre=data['nombre'].strip()
        producto.unidad_codigo=data['unidad_codigo']
        producto.precio_unitario=data['precio_unitario']
        producto.disponible=data['disponible']
        producto.foto_url=data['icono']
        producto.save(update_fields=[
            'nombre','unidad_codigo','precio_unitario','disponible','foto_url'])
        return Response(producto_payload(producto))


def puesto_payload(puesto):
    return {
        'id':puesto.pk,'mercado_id':puesto.mercado_id,'nombre':puesto.nombre,
        'casero':' '.join(filter(None,[puesto.vendedor.nombres,puesto.vendedor.apellido_paterno])),
        'categoria':puesto.categoria.nombre,'abierto':puesto.abierto,
        'calificacion':0.0,'resenas':0,
    }


def pedido_payload(pedido):
    partes=[]
    paradas={fila['pedido_puesto_id']:fila['orden'] for fila in
             EntregaParada.objects.filter(pedido_id=pedido.pk).values('pedido_puesto_id','orden')}
    for indice,parte in enumerate(PedidoPuesto.objects.filter(
            pedido_id=pedido.pk).select_related('puesto__vendedor','puesto__categoria').order_by('id'),1):
        detalles=[{
            'id':d.pk,'producto_id':d.producto_id,'nombre':d.nombre_solicitado,
            'unidad':d.unidad_codigo,'cantidad':str(d.cantidad_solicitada),
            'precio_estimado_centavos':cents(d.precio_estimado_unitario),
            'disponibilidad':d.disponibilidad,
        } for d in PedidoDetalle.objects.filter(pedido_puesto_id=parte.pk).order_by('id')]
        partes.append({
            'id':parte.pk,'puesto':puesto_payload(parte.puesto),
            'codigo_bolsa':parte.codigo_bolsa,'estado':parte.estado,
            'lista_mandado':parte.lista_mandado,'motivo_rechazo':parte.motivo_rechazo,
            'parada':paradas.get(parte.pk,indice),'detalles':detalles,
        })
    cotizacion=None
    quote=Cotizacion.objects.filter(pedido_id=pedido.pk).order_by('-version').first()
    if quote:
        cot_puestos=[]
        for grupo in CotizacionPuesto.objects.filter(cotizacion_id=quote.pk).select_related('pedido_puesto').order_by('id'):
            cot_puestos.append({
                'pedido_puesto_id':grupo.pedido_puesto_id,
                'tasa_comision':str(grupo.tasa_comision),
                'nota':grupo.pedido_puesto.nota,
                'detalles':[{
                    'pedido_detalle_id':d.pedido_detalle_id,'nombre_final':d.nombre_final,
                    'cantidad_real':str(d.cantidad_real),'precio_unitario_centavos':cents(d.precio_unitario),
                } for d in CotizacionDetalle.objects.filter(cotizacion_puesto_id=grupo.pk).order_by('id')],
            })
        cotizacion={'version':quote.version,'estado':quote.estado,
                    'costo_envio_centavos':cents(quote.costo_envio),'puestos':cot_puestos}
    historial=[{'hora':h.creado_en,'texto':h.observacion or h.estado.replace('_',' ').capitalize()}
               for h in HistorialEstado.objects.filter(pedido_id=pedido.pk).order_by('creado_en','id')]
    return {
        'id':pedido.pk,'codigo':pedido.codigo,'codigo_corto':str(pedido.pk),
        'cliente_nombre':' '.join(filter(None,[pedido.comprador.nombres,pedido.comprador.apellido_paterno])),
        'cliente_celular':pedido.celular_contacto,'mercado_id':pedido.mercado_id,
        'estado':pedido.estado,'metodo_pago':pedido.metodo_pago,
        'direccion':pedido.direccion_entrega,'referencia':pedido.referencia_entrega,
        'puestos':partes,'costo_envio_centavos':cents(quote.costo_envio if quote else 0),
        'historial':historial,'codigo_entrega':'','cotizacion':cotizacion,
        'creado_en':pedido.creado_en,'programado_para':pedido.programado_para,
    }


class VendedorPedidosView(APIView):
    def get(self,request):
        puesto=puesto_vendedor_actual(request.user)
        ids=PedidoPuesto.objects.filter(puesto_id=puesto.pk).values_list('pedido_id',flat=True)
        pedidos=Pedido.objects.filter(pk__in=ids).select_related('comprador').order_by('-creado_en','-id')[:100]
        return Response([pedido_payload(p) for p in pedidos])


class VendedorPedidoAccionView(APIView):
    @transaction.atomic
    def patch(self,request,pedido_puesto_id):
        puesto=puesto_vendedor_actual(request.user)
        parte=PedidoPuesto.objects.select_for_update().filter(
            pk=pedido_puesto_id,puesto_id=puesto.pk).first()
        if parte is None:raise NotFound('Pedido no encontrado para tu puesto.')
        data=validated(s.AccionPedidoPuestoSerializer,request.data)
        accion=data['accion']
        permitidos={
            'aceptar':({'pendiente'},'aceptado'),
            'rechazar':({'pendiente','aceptado','pesando'},'rechazado'),
            'listo':({'en_preparacion'},'listo'),
            'entregar':({'listo'},'recogido'),
        }
        origenes,destino=permitidos[accion]
        if parte.estado not in origenes:
            raise ValidationError(f'El pedido no permite la acción {accion} en su estado actual.')
        parte.estado=destino
        campos=['estado']
        if accion=='aceptar':parte.aceptado_en=timezone.now();campos.append('aceptado_en')
        if accion=='rechazar':parte.motivo_rechazo=data['motivo'].strip();campos.append('motivo_rechazo')
        if accion=='listo':parte.listo_en=timezone.now();campos.append('listo_en')
        parte.save(update_fields=campos)
        HistorialEstado.objects.create(pedido_id=parte.pedido_id,pedido_puesto_id=parte.pk,
            estado=destino,actor_id=request.user.pk,observacion=f'El puesto marcó el pedido como {destino}.')
        activas=PedidoPuesto.objects.filter(pedido_id=parte.pedido_id).exclude(estado__in=['rechazado','cancelado'])
        pedido=parte.pedido
        if not activas.exists():pedido.estado='cancelado'
        elif accion=='listo' and not activas.exclude(estado='listo').exists():pedido.estado='listo_para_recojo'
        elif accion=='entregar' and not activas.exclude(estado='recogido').exists():pedido.estado='en_camino'
        pedido.save(update_fields=['estado'])
        return Response({'id':parte.pk,'estado':parte.estado})


class VendedorDetalleView(APIView):
    def patch(self,request,detalle_id):
        puesto=puesto_vendedor_actual(request.user)
        detalle=PedidoDetalle.objects.select_related('pedido_puesto').filter(
            pk=detalle_id,puesto_id=puesto.pk).first()
        if detalle is None:raise NotFound('Producto del pedido no encontrado.')
        if detalle.pedido_puesto.estado not in ['aceptado','pesando']:
            raise ValidationError('Primero acepta el pedido para revisar sus productos.')
        data=validated(s.DisponibilidadDetalleSerializer,request.data)
        detalle.disponibilidad=data['disponibilidad']
        detalle.save(update_fields=['disponibilidad'])
        if detalle.pedido_puesto.estado=='aceptado':
            detalle.pedido_puesto.estado='pesando'
            detalle.pedido_puesto.save(update_fields=['estado'])
        return Response({'id':detalle.pk,'disponibilidad':detalle.disponibilidad})


class VendedorCotizacionView(APIView):
    @transaction.atomic
    def post(self,request,pedido_puesto_id):
        puesto=puesto_vendedor_actual(request.user)
        parte=PedidoPuesto.objects.select_for_update().filter(
            pk=pedido_puesto_id,puesto_id=puesto.pk).first()
        if parte is None:raise NotFound('Pedido no encontrado para tu puesto.')
        if parte.estado not in ['aceptado','pesando']:
            raise ValidationError('Este pedido no está listo para enviar su precio final.')
        data=validated(s.CotizacionVendedorSerializer,request.data)
        detalles={d.pk:d for d in PedidoDetalle.objects.filter(pedido_puesto_id=parte.pk)}
        recibidos={fila['pedido_detalle_id'] for fila in data['detalles']}
        if len(recibidos)!=len(data['detalles']):
            raise ValidationError('No repitas productos en la cotización.')
        esperados={d.pk for d in detalles.values() if d.disponibilidad!='sin_stock'}
        if recibidos!=esperados:
            raise ValidationError('Incluye exactamente todos los productos que sí entregarás.')
        if any(detalles[i].disponibilidad=='pendiente' for i in recibidos):
            raise ValidationError('Revisa la disponibilidad de todos los productos.')
        unidades_enteras=set(UnidadMedida.objects.filter(permite_fraccion=False).values_list('codigo',flat=True))
        for fila in data['detalles']:
            if (detalles[fila['pedido_detalle_id']].unidad_codigo in unidades_enteras
                    and fila['cantidad_real']!=fila['cantidad_real'].to_integral_value()):
                raise ValidationError('Usa cantidades enteras para unidades y atados.')
        quote=Cotizacion.objects.select_for_update().filter(
            pedido_id=parte.pedido_id,estado='borrador').order_by('-version').first()
        if quote is None:
            version=(Cotizacion.objects.filter(pedido_id=parte.pedido_id).aggregate(
                mayor=Max('version'))['mayor'] or 0)+1
            quote=Cotizacion.objects.create(pedido_id=parte.pedido_id,version=version,
                                             estado='borrador',costo_envio=5)
        grupo,_=CotizacionPuesto.objects.get_or_create(
            cotizacion_id=quote.pk,pedido_id=parte.pedido_id,pedido_puesto_id=parte.pk)
        CotizacionDetalle.objects.filter(cotizacion_puesto_id=grupo.pk).delete()
        for fila in data['detalles']:
            detalle=detalles[fila['pedido_detalle_id']]
            CotizacionDetalle.objects.create(
                cotizacion_puesto_id=grupo.pk,pedido_puesto_id=parte.pk,
                pedido_detalle_id=detalle.pk,nombre_final=fila['nombre_final'].strip(),
                producto_final_id=detalle.producto_id,puesto_id=puesto.pk,
                unidad_codigo=detalle.unidad_codigo,cantidad_real=fila['cantidad_real'],
                precio_unitario=fila['precio_unitario'])
        parte.estado='pesado'
        parte.nota=data.get('nota','').strip() or None
        parte.save(update_fields=['estado','nota'])
        activas=PedidoPuesto.objects.filter(pedido_id=parte.pedido_id).exclude(
            estado__in=['rechazado','cancelado'])
        cotizadas=set(CotizacionPuesto.objects.filter(cotizacion_id=quote.pk).values_list(
            'pedido_puesto_id',flat=True))
        if set(activas.values_list('id',flat=True))==cotizadas:
            quote.estado='enviada';quote.save(update_fields=['estado'])
            Pedido.objects.filter(pk=parte.pedido_id).update(estado='esperando_confirmacion')
        return Response({'id':quote.pk,'estado':quote.estado},status=201)

class CarritoView(APIView):
    def get(self,request):
        return Response(cart_payload(request.user))

class CarritoItemsView(APIView):
    def post(self,request):
        data=validated(s.ItemSerializer,request.data)
        return Response(put_item(request.user,data['producto_id'],data['cantidad']))

class CarritoItemView(APIView):
    def patch(self,request,item_id):
        data=validated(s.CantidadSerializer,request.data)
        return Response(change_item(request.user,item_id,data['cantidad']))
    def delete(self,request,item_id):
        return Response(change_item(request.user,item_id))

class DireccionesView(APIView):
    def get(self,request):
        require_buyer(request.user)
        return Response(list(Direccion.objects.filter(comprador_id=request.user.pk,activa=True).values(
            'id','etiqueta','direccion','referencia','principal')))
    def post(self,request):
        require_buyer(request.user)
        data=validated(s.DireccionSerializer,request.data)
        with transaction.atomic():
            lock_user(request.user)
            if data['principal']:
                Direccion.objects.filter(comprador_id=request.user.pk,principal=True,activa=True).update(principal=False)
            row=Direccion.objects.create(comprador_id=request.user.pk,**data)
        return Response({'id':row.pk,'direccion':row.direccion},status=201)

class PedidosView(APIView):
    def get(self,request):
        require_buyer(request.user)
        return Response(list(Pedido.objects.filter(comprador_id=request.user.pk).order_by('-id').values('id','codigo','estado','metodo_pago')[:100]))
    def post(self,request):
        data=validated(s.PedidoSerializer,request.data)
        order=checkout(request.user,data['direccion_id'],data['metodo_pago'])
        return Response({'id':order.pk,'codigo':order.codigo,'estado':order.estado,
                         'detail':'Pedido creado. El casero debe pesar y enviar la cotización final.'},status=201)

class PedidoView(APIView):
    def get(self,request,order_id):
        require_buyer(request.user)
        try:order=Pedido.objects.get(pk=order_id,comprador_id=request.user.pk)
        except Pedido.DoesNotExist:raise NotFound('Pedido no encontrado.')
        quotes=[]
        for quote in Cotizacion.objects.filter(pedido_id=order.pk).order_by('-version'):
            total=None
            if quote.estado in ['enviada','aceptada']:
                total=cents(quote_total(quote))
            quotes.append({'id':quote.pk,'version':quote.version,'estado':quote.estado,'total_centavos':total})
        return Response({'id':order.pk,'codigo':order.codigo,'estado':order.estado,
                         'metodo_pago':order.metodo_pago,'cotizaciones':quotes})

class AceptarCotizacionView(APIView):
    def post(self,request,order_id,quote_id):
        quote=accept_quote(request.user,order_id,quote_id)
        return Response({'id':quote.pk,'estado':quote.estado,'total_centavos':cents(quote_total(quote))})

class PagoView(APIView):
    throttle_classes=[ScopedRateThrottle]
    throttle_scope='pago'
    def post(self,request):
        data=validated(s.PagoSerializer,request.data)
        result,status=pay_order(request.user,data)
        return Response(result,status=status)

class CancelarPedidoView(APIView):
    def post(self,request,order_id):
        from .services import cancel_order
        order=cancel_order(request.user,order_id)
        return Response({'id':order.pk,'estado':order.estado})
