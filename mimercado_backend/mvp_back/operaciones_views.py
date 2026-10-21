from django.db import transaction
from django.utils import timezone
from django.conf import settings
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.exceptions import ValidationError, PermissionDenied, NotFound
from rest_framework.throttling import ScopedRateThrottle
from . import operaciones as op
from .models import (Mercado, RepartidorMercado, Entrega, Pedido, Cotizacion, Pago,
                     PedidoPuesto, ResenaPuesto, ResenaRepartidor)
from .services import require_buyer
from .money import cents

MOVILIDADES = ['a_pie','carretilla','bicicleta','moto','mototaxi','otro']

def movilidad_validada(data):
    movilidad=data.get('movilidad','a_pie')
    if movilidad not in MOVILIDADES: raise ValidationError('Selecciona tu movilidad.')
    placa=data.get('placa','')
    descripcion=data.get('descripcion_movilidad','')
    if not isinstance(placa,str) or len(placa.strip())>20: raise ValidationError('La placa admite hasta 20 caracteres.')
    if not isinstance(descripcion,str) or len(descripcion.strip())>150: raise ValidationError('La descripción admite hasta 150 caracteres.')
    if movilidad=='otro' and not descripcion.strip(): raise ValidationError('Describe la otra movilidad que utilizarás.')
    return movilidad, placa.strip() if movilidad in ['moto','mototaxi','otro'] else None, descripcion.strip() or None

class RepartidorInicioView(APIView):
    def get(self,request):
        op.exigir_repartidor(request.user)
        rm=op.asignacion(request.user)
        if rm is None:
            pendiente=RepartidorMercado.objects.filter(repartidor_id=request.user.pk,fin_en__isnull=True).first()
            return Response({'autorizado':False,'pendiente':pendiente is not None,
                'mercado_solicitado':pendiente.mercado.nombre if pendiente else None,
                'movilidad':pendiente.movilidad if pendiente else 'a_pie',
                'placa':pendiente.placa if pendiente else None,
                'descripcion_movilidad':pendiente.descripcion_movilidad if pendiente else None,
                'mercados':list(Mercado.objects.filter(estado='activo').order_by('nombre').values('id','nombre'))})
        activa=Entrega.objects.filter(repartidor_mercado_id=rm.pk,estado__in=op.VIGENTES).first()
        entregas=Entrega.objects.filter(repartidor_mercado_id=rm.pk,estado='entregada',entregada_en__date=timezone.localdate())
        ganancia=sum((Cotizacion.objects.get(pedido_id=e.pedido_id,estado='aceptada').ganancia_repartidor for e in entregas),0)
        pedidos=[]
        if rm.disponible and activa is None:
            candidatos=Pedido.objects.filter(mercado_id=rm.mercado_id,estado__in=['en_preparacion','listo_para_recojo','en_recojo']).order_by('creado_en','id')
            asignados=Entrega.objects.exclude(estado__in=['rechazada','cancelada']).values('pedido_id')
            for p in candidatos.exclude(id__in=asignados)[:100]:
                if op.apto_para_reparto(p): pedidos.append(op.pedido_operacion_payload(p))
        return Response({'autorizado':True,'disponible':rm.disponible,
            'mercado':{'id':rm.mercado_id,'nombre':rm.mercado.nombre},'movilidad':rm.movilidad,'placa':rm.placa,
            'descripcion_movilidad':rm.descripcion_movilidad,
            'entregas_hoy':entregas.count(),'ganancia_hoy_centavos':cents(ganancia),
            'sonido':request.user.sonido,'vibracion':request.user.vibracion,
            'historial_hoy':[op.pedido_operacion_payload(e.pedido) for e in entregas.order_by('-entregada_en')[:100]],
            'ofertas':pedidos,'en_curso':op.pedido_operacion_payload(activa.pedido) if activa else None})

    @transaction.atomic
    def patch(self,request):
        rm=op.asignacion(request.user,bloquear=True)
        if rm is None: raise PermissionDenied('Necesitas un mercado autorizado para activar tu disponibilidad.')
        valor=request.data.get('disponible')
        if not isinstance(valor,bool): raise ValidationError('Indica si estás disponible.')
        rm.disponible=valor;rm.save(update_fields=['disponible'])
        return Response({'disponible':rm.disponible})

class RepartidorMercadoView(APIView):
    @transaction.atomic
    def post(self,request):
        op.exigir_repartidor(request.user)
        from .services import lock_user
        lock_user(request.user)
        if op.asignacion(request.user): raise ValidationError('Ya tienes un mercado autorizado.')
        mercado_id=request.data.get('mercado_id')
        if not isinstance(mercado_id,int) or isinstance(mercado_id,bool): raise ValidationError('Selecciona un mercado.')
        mercado=Mercado.objects.filter(pk=mercado_id,estado='activo').first()
        if mercado is None: raise ValidationError('Selecciona un mercado activo.')
        movilidad,placa,descripcion=movilidad_validada(request.data)
        rm=RepartidorMercado.objects.filter(repartidor_id=request.user.pk,fin_en__isnull=True,autorizado=False).first()
        if rm is None: rm=RepartidorMercado(repartidor_id=request.user.pk,mercado=mercado)
        rm.mercado=mercado;rm.movilidad=movilidad;rm.placa=placa or None;rm.descripcion_movilidad=descripcion;rm.disponible=False;rm.save()
        return Response({'pendiente':True,'detail':'Solicitud registrada. El responsable del mercado debe autorizarte.'},status=201)

    @transaction.atomic
    def patch(self,request):
        rm=op.asignacion(request.user,bloquear=True)
        if rm is None: raise PermissionDenied('Primero necesitas la autorización de tu mercado.')
        if Entrega.objects.filter(repartidor_mercado_id=rm.pk,estado__in=op.VIGENTES).exists():
            raise ValidationError('Termina tu entrega antes de cambiar de movilidad.')
        rm.movilidad,rm.placa,rm.descripcion_movilidad=movilidad_validada(request.data)
        rm.save(update_fields=['movilidad','placa','descripcion_movilidad'])
        return Response({'guardado':True})

class RepartidorAceptarView(APIView):
    def post(self,request,order_id):
        entrega=op.aceptar_reparto(request.user,order_id)
        return Response({'aceptado':True,'pedido_id':entrega.pedido_id})

class RepartidorAccionView(APIView):
    def post(self,request,order_id):
        accion=request.data.get('accion')
        if accion=='recoger':
            parte=request.data.get('pedido_puesto_id')
            if not isinstance(parte,int) or isinstance(parte,bool): raise ValidationError('Selecciona un puesto de tu ruta.')
            op.recoger(request.user,order_id,parte)
        elif accion=='salir': op.salir(request.user,order_id)
        elif accion in ['llegue','recogiendo']: op.avisar_cliente(request.user,order_id,accion)
        else: raise ValidationError('La acción no es válida.')
        return Response({'guardado':True})

class RepartidorCompletarView(APIView):
    throttle_classes=[ScopedRateThrottle]
    throttle_scope='entrega'
    def post(self,request,order_id):
        import re
        codigo=request.data.get('codigo','')
        if not isinstance(codigo,str) or not re.fullmatch(r'[0-9]{4}',codigo): raise ValidationError('El código de entrega tiene 4 números.')
        if not op.completar(request.user,order_id,codigo,request.data.get('efectivo_confirmado') is True):
            return Response({'detail':'El código no coincide. Pídeselo de nuevo al cliente.'},status=400)
        return Response({'entregado':True})

class CompradorPedidosView(APIView):
    def get(self,request):
        require_buyer(request.user)
        pedidos=Pedido.objects.filter(comprador_id=request.user.pk).order_by('-creado_en','-id')[:100]
        return Response([op.pedido_operacion_payload(p,comprador=True) for p in pedidos])

class CompradorCalificarView(APIView):
    @transaction.atomic
    def post(self,request,order_id):
        require_buyer(request.user)
        pedido=Pedido.objects.select_for_update().filter(pk=order_id,comprador_id=request.user.pk,estado='entregado').first()
        if pedido is None: raise NotFound('Solo puedes calificar tus pedidos entregados.')
        estrellas=request.data.get('puestos',{})
        if not isinstance(estrellas,dict): raise ValidationError('Selecciona las estrellas de cada puesto.')
        partes=list(PedidoPuesto.objects.filter(pedido_id=pedido.pk).exclude(estado__in=['rechazado','cancelado']))
        if set(estrellas)!=set(str(p.pk) for p in partes): raise ValidationError('Califica cada puesto de tu pedido.')
        values=list(estrellas.values())+[request.data.get('repartidor')]
        if any(not isinstance(v,int) or isinstance(v,bool) or not 1<=v<=5 for v in values): raise ValidationError('Elige de una a cinco estrellas.')
        for parte in partes:
            ResenaPuesto.objects.get_or_create(pedido_puesto_id=parte.pk,defaults={'pedido_id':pedido.pk,
                'comprador_id':request.user.pk,'estrellas':estrellas[str(parte.pk)]})
        entrega=Entrega.objects.filter(pedido_id=pedido.pk,estado='entregada').first()
        if entrega:
            ResenaRepartidor.objects.get_or_create(entrega_id=entrega.pk,defaults={'pedido_id':pedido.pk,
                'comprador_id':request.user.pk,'estrellas':request.data['repartidor']})
        return Response({'guardado':True})

class PagoConfiguracionView(APIView):
    def get(self,request):
        require_buyer(request.user)
        return Response({'modo':settings.PAYMENT_MODE,'configurado':settings.PAYMENT_MODE=='mock',
            'codigo_demostracion':settings.MOCK_YAPE_CODE if settings.PAYMENT_MODE=='mock' else None,'prueba':True})
