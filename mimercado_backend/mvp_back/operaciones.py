"""Operaciones de reparto sobre el esquema existente; sin datos de demostración."""
import hashlib
import hmac
from math import asin, cos, radians, sin, sqrt
from decimal import Decimal
from django.conf import settings
from django.contrib.auth.hashers import make_password, check_password
from django.db import transaction
from django.utils import timezone
from rest_framework.exceptions import ValidationError, PermissionDenied, NotFound
from .models import (Usuario, UsuarioRol, RepartidorMercado, Mercado, Pedido, PedidoPuesto,
                     Cotizacion, Pago, Entrega, EntregaParada, HistorialEstado, Mensaje)
from .money import cents

VIGENTES = ['asignada', 'aceptada', 'en_recojo', 'en_camino']

def exigir_repartidor(user):
    if not UsuarioRol.objects.filter(usuario_id=user.pk,rol_codigo='repartidor').exists():
        raise PermissionDenied('Esta cuenta no tiene perfil de repartidor.')

def asignacion(user, bloquear=False):
    exigir_repartidor(user)
    qs=RepartidorMercado.objects
    if bloquear: qs=qs.select_for_update()
    return qs.filter(repartidor_id=user.pk,fin_en__isnull=True,autorizado=True,
                     mercado__estado='activo').order_by('id').first()

def codigo_entrega(entrega):
    digest=hmac.new(settings.SECRET_KEY.encode(),f'entrega:{entrega.pk}:{entrega.pedido_id}'.encode(),hashlib.sha256).digest()
    return str(int.from_bytes(digest[:8],'big') % 10000).zfill(4)

def distancia(pedido):
    mercado=pedido.mercado
    if any(v is None for v in [mercado.latitud,mercado.longitud,pedido.latitud,pedido.longitud]): return None
    a,b,c,d=map(lambda x:radians(float(x)),[mercado.latitud,mercado.longitud,pedido.latitud,pedido.longitud])
    return round(6371*2*asin(min(1,sqrt(sin((c-a)/2)**2+cos(a)*cos(c)*sin((d-b)/2)**2))),2)

def apto_para_reparto(pedido):
    if pedido.estado not in ['en_preparacion','listo_para_recojo','en_recojo']: return False
    quote=Cotizacion.objects.filter(pedido_id=pedido.pk,estado='aceptada').first()
    if quote is None: return False
    partes=PedidoPuesto.objects.filter(pedido_id=pedido.pk).exclude(estado__in=['rechazado','cancelado'])
    if not partes.exists() or partes.exclude(estado__in=['en_preparacion','listo','recogido']).exists(): return False
    if pedido.metodo_pago=='yape':
        from .services import quote_total
        if not Pago.objects.filter(pedido_id=pedido.pk,cotizacion_id=quote.pk,estado='aprobado',monto=quote_total(quote)).exists(): return False
    return True

def nombre(user):
    return ' '.join(filter(None,[user.nombres,user.apellido_paterno,user.apellido_materno]))

def pedido_operacion_payload(pedido, comprador=False):
    from .views import pedido_payload
    payload=pedido_payload(pedido)
    quote=Cotizacion.objects.filter(pedido_id=pedido.pk).order_by('-version').first()
    if payload['cotizacion'] is not None: payload['cotizacion']['id']=quote.pk
    entrega=Entrega.objects.filter(pedido_id=pedido.pk).exclude(estado__in=['rechazada','cancelada']).order_by('-id').first()
    pago=Pago.objects.filter(pedido_id=pedido.pk,estado__in=['aprobado','procesando']).order_by('-id').first()
    payload.update({'distancia_km':distancia(pedido),'distancia_tipo':'linea_recta',
        'ganancia_repartidor_centavos':cents(quote.ganancia_repartidor) if quote else 0,
        'pago_aprobado':pago is not None and pago.estado=='aprobado',
        'pago_pendiente':pago is not None and pago.estado=='procesando',
        'pago_simulado':pago is not None and (pago.proveedor_transaccion_id or '').startswith('mock_'),
        'entrega_estado':entrega.estado if entrega else None,
        'repartidor':None})
    if entrega:
        rm=entrega.repartidor_mercado
        payload['repartidor']={'nombre':nombre(rm.repartidor),'celular':rm.repartidor.celular,
            'mercado_id':rm.mercado_id,'movilidad':rm.movilidad,'placa':rm.placa,'calificacion':0}
        if comprador and entrega.estado in VIGENTES: payload['codigo_entrega']=codigo_entrega(entrega)
    if comprador:
        from .models import ResenaPuesto, ResenaRepartidor
        partes=PedidoPuesto.objects.filter(pedido_id=pedido.pk).exclude(estado__in=['rechazado','cancelado'])
        payload['pendiente_calificar']=pedido.estado=='entregado' and (
            partes.exclude(id__in=ResenaPuesto.objects.filter(pedido_id=pedido.pk).values('pedido_puesto_id')).exists()
            or (entrega is not None and not ResenaRepartidor.objects.filter(entrega_id=entrega.pk).exists()))
    return payload

@transaction.atomic
def aceptar_reparto(user,pedido_id):
    rm=asignacion(user,bloquear=True)
    if rm is None: raise PermissionDenied('Necesitas un mercado autorizado para aceptar pedidos.')
    # Bloquear la asignación evita que un repartidor tome dos pedidos simultáneos.
    actual=Entrega.objects.filter(repartidor_mercado_id=rm.pk,estado__in=VIGENTES).first()
    if actual:
        if actual.pedido_id==pedido_id: return actual
        raise ValidationError('Termina tu entrega actual antes de aceptar otra.')
    if not rm.disponible: raise ValidationError('Activa tu disponibilidad para aceptar pedidos.')
    pedido=Pedido.objects.select_for_update().filter(pk=pedido_id,mercado_id=rm.mercado_id).first()
    if pedido is None: raise NotFound('Este pedido no pertenece a tu mercado.')
    if Entrega.objects.filter(pedido_id=pedido.pk,estado__in=VIGENTES+['entregada']).exists():
        raise ValidationError('Otro repartidor ya aceptó este pedido. Actualiza la lista.')
    if not apto_para_reparto(pedido): raise ValidationError('El pedido todavía no está listo para asignarse.')
    entrega=Entrega.objects.create(pedido_id=pedido.pk,mercado_id=rm.mercado_id,
        repartidor_mercado_id=rm.pk,estado='en_recojo',aceptada_en=timezone.now())
    entrega.codigo_entrega_hash=make_password(codigo_entrega(entrega))
    entrega.save(update_fields=['codigo_entrega_hash'])
    for index,parte in enumerate(PedidoPuesto.objects.filter(pedido_id=pedido.pk).exclude(
            estado__in=['rechazado','cancelado']).order_by('id'),1):
        EntregaParada.objects.create(entrega_id=entrega.pk,pedido_id=pedido.pk,pedido_puesto_id=parte.pk,
                                    orden=index,recogido_en=timezone.now() if parte.estado=='recogido' else None)
    pedido.estado='en_recojo';pedido.save(update_fields=['estado'])
    HistorialEstado.objects.create(pedido_id=pedido.pk,estado='en_recojo',actor_id=user.pk,
        observacion='Un repartidor del mercado está recogiendo tu pedido.')
    return entrega

def bloquear_entrega(user,pedido_id):
    rm=asignacion(user)
    if rm is None: raise PermissionDenied('No tienes un mercado autorizado.')
    pedido=Pedido.objects.select_for_update().filter(pk=pedido_id,mercado_id=rm.mercado_id).first()
    if pedido is None: raise NotFound('Entrega no encontrada.')
    entrega=Entrega.objects.select_for_update().filter(pedido_id=pedido.pk,repartidor_mercado_id=rm.pk,
                                                       estado__in=VIGENTES+['entregada']).first()
    if entrega is None: raise NotFound('Esta entrega no está asignada a tu cuenta.')
    return pedido,entrega

@transaction.atomic
def recoger(user,pedido_id,parte_id):
    pedido,entrega=bloquear_entrega(user,pedido_id)
    if entrega.estado not in ['aceptada','en_recojo']: raise ValidationError('Esta entrega no permite más recojos.')
    parada=EntregaParada.objects.select_for_update().filter(entrega_id=entrega.pk,pedido_puesto_id=parte_id).first()
    if parada is None: raise NotFound('Este puesto no es una parada de tu entrega.')
    if parada.recogido_en is not None: return
    parte=PedidoPuesto.objects.select_for_update().get(pk=parte_id)
    if parte.estado not in ['listo','recogido']: raise ValidationError('Espera a que el vendedor termine de preparar la bolsa.')
    anteriores=EntregaParada.objects.filter(entrega_id=entrega.pk,orden__lt=parada.orden,recogido_en__isnull=True)
    if anteriores.exists(): raise ValidationError('Recoge primero en las paradas anteriores.')
    parte.estado='recogido';parte.save(update_fields=['estado'])
    parada.recogido_en=timezone.now();parada.save(update_fields=['recogido_en'])
    HistorialEstado.objects.create(pedido_id=pedido.pk,pedido_puesto_id=parte.pk,estado='recogido',actor_id=user.pk,
                                   observacion=f'Bolsa recogida en {parte.puesto.nombre}.')

@transaction.atomic
def salir(user,pedido_id):
    pedido,entrega=bloquear_entrega(user,pedido_id)
    if entrega.estado=='en_camino': return
    if entrega.estado not in ['aceptada','en_recojo']: raise ValidationError('La entrega no permite salir a repartir.')
    if not EntregaParada.objects.filter(entrega_id=entrega.pk).exists() or EntregaParada.objects.filter(
            entrega_id=entrega.pk,recogido_en__isnull=True).exists():
        raise ValidationError('Falta recoger en uno o más puestos.')
    entrega.estado='en_camino';entrega.salida_en=timezone.now();entrega.save(update_fields=['estado','salida_en'])
    pedido.estado='en_camino';pedido.save(update_fields=['estado'])
    HistorialEstado.objects.create(pedido_id=pedido.pk,estado='en_camino',actor_id=user.pk,observacion='Tu pedido va en camino.')

@transaction.atomic
def avisar_cliente(user,pedido_id,tipo):
    pedido,entrega=bloquear_entrega(user,pedido_id)
    permitido=entrega.estado=='en_camino' if tipo=='llegue' else entrega.estado in ['aceptada','en_recojo']
    if not permitido: raise ValidationError('Este aviso no corresponde al estado de la entrega.')
    texto='El repartidor llegó a tu dirección.' if tipo=='llegue' else 'El repartidor está recogiendo tus productos en el mercado.'
    if Mensaje.objects.filter(pedido_id=pedido.pk,remitente_id=user.pk,texto=texto).exists(): return
    Mensaje.objects.create(pedido_id=pedido.pk,remitente_id=user.pk,destinatario_id=pedido.comprador_id,texto=texto)
    HistorialEstado.objects.create(pedido_id=pedido.pk,estado=pedido.estado,actor_id=user.pk,observacion=texto)

@transaction.atomic
def completar(user,pedido_id,codigo,efectivo_confirmado):
    pedido,entrega=bloquear_entrega(user,pedido_id)
    if entrega.estado=='entregada': return True
    if entrega.estado!='en_camino': raise ValidationError('Primero recoge todas las bolsas y sal a entregar.')
    if not check_password(codigo,entrega.codigo_entrega_hash or ''): return False
    quote=Cotizacion.objects.get(pedido_id=pedido.pk,estado='aceptada')
    from .services import quote_total
    total=quote_total(quote)
    if pedido.metodo_pago=='yape' and not Pago.objects.filter(pedido_id=pedido.pk,cotizacion_id=quote.pk,
            estado='aprobado',monto=total).exists():
        raise ValidationError('El cliente todavía no ha completado el pago.')
    if pedido.metodo_pago=='efectivo':
        if not efectivo_confirmado: raise ValidationError('Confirma que recibiste el efectivo antes de completar la entrega.')
        Pago.objects.get_or_create(pedido_id=pedido.pk,estado='aprobado',defaults={
            'cotizacion_id':quote.pk,'metodo':'efectivo','canal':'contra_entrega','monto':total,
            'idempotencia':f'efectivo_entrega_{entrega.pk}','confirmado_en':timezone.now()})
    entrega.codigo_validado_en=timezone.now();entrega.entregada_en=timezone.now();entrega.estado='entregada'
    entrega.save(update_fields=['codigo_validado_en','entregada_en','estado'])
    pedido.estado='entregado';pedido.save(update_fields=['estado'])
    HistorialEstado.objects.create(pedido_id=pedido.pk,estado='entregado',actor_id=user.pk,observacion='¡Tu pedido fue entregado!')
    return True
