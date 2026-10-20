from django.contrib.auth.hashers import make_password, check_password
from django.db import transaction, IntegrityError
from django.db.models import Q, Count, Sum
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
                     CotizacionPuesto, CotizacionDetalle, RepartidorMercado)
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
        return Response(list(rows.values('id','nombre','mercado_id','abierto')))

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
            'disponible':p.disponible,'stock':None if p.stock is None else str(p.stock)} for p in rows[:200]])

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
