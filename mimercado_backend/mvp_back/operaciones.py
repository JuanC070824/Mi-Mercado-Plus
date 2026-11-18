"""Operaciones de reparto sobre el esquema existente; sin datos de demostración."""
import hashlib
import hmac
from collections import defaultdict
from math import asin, cos, radians, sin, sqrt
from decimal import Decimal
from django.conf import settings
from django.contrib.auth.hashers import make_password, check_password
from django.db import transaction
from django.db.models import prefetch_related_objects
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
    # Sin bloqueo, el mercado viene en la misma consulta (el inicio muestra su nombre).
    qs=RepartidorMercado.objects.select_for_update() if bloquear else RepartidorMercado.objects.select_related('mercado')
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

def aptos_para_reparto(pedidos):
    """Pedidos listos para ofrecer a un repartidor, validados con consultas fijas.

    Mismas reglas que antes (y que services.quote_total para Yape), pero sin
    unas 9 consultas por pedido: con la base en la nube eso sumaba segundos.
    """
    from .models import CotizacionDetalle, CotizacionPuesto, PedidoDetalle
    from .money import soles
    pedidos=[p for p in pedidos if p.estado in ['en_preparacion','listo_para_recojo','en_recojo']]
    ids=[p.pk for p in pedidos]
    if not ids: return []
    quotes={q.pedido_id:q for q in Cotizacion.objects.filter(pedido_id__in=ids,estado='aceptada')}
    partes=defaultdict(dict)
    for pid,parte,estado in PedidoPuesto.objects.filter(pedido_id__in=ids).exclude(
            estado__in=['rechazado','cancelado']).values_list('pedido_id','id','estado'):
        partes[pid][parte]=estado
    candidatos=[p for p in pedidos if p.pk in quotes and partes[p.pk]
                and all(e in ['en_preparacion','listo','recogido'] for e in partes[p.pk].values())]
    yape=[p for p in candidatos if p.metodo_pago=='yape']
    if not yape: return candidatos
    quote_ids=[quotes[p.pk].pk for p in yape]
    grupos=defaultdict(dict)
    for gid,qid,parte in CotizacionPuesto.objects.filter(cotizacion_id__in=quote_ids).values_list(
            'id','cotizacion_id','pedido_puesto_id'):
        grupos[qid][gid]=parte
    lineas_esperadas=defaultdict(set)
    for lid,parte in PedidoDetalle.objects.filter(
            pedido_puesto_id__in=[x for p in yape for x in partes[p.pk]]).exclude(
            disponibilidad='sin_stock').values_list('id','pedido_puesto_id'):
        lineas_esperadas[parte].add(lid)
    lineas_cotizadas=defaultdict(set)
    subtotal=defaultdict(Decimal)
    for gid,linea,monto in CotizacionDetalle.objects.filter(
            cotizacion_puesto_id__in=[g for q in quote_ids for g in grupos[q]]).values_list(
            'cotizacion_puesto_id','pedido_detalle_id','subtotal'):
        lineas_cotizadas[gid].add(linea)
        subtotal[gid]+=monto
    pagos={(pid,qid,monto) for pid,qid,monto in Pago.objects.filter(
        pedido_id__in=[p.pk for p in yape],estado='aprobado').values_list('pedido_id','cotizacion_id','monto')}
    aprobados=set()
    for p in yape:
        quote=quotes[p.pk]
        if set(partes[p.pk])!=set(grupos[quote.pk].values()):
            raise ValidationError('La cotización no contiene todos los puestos activos.')
        for gid,parte in grupos[quote.pk].items():
            if not lineas_esperadas[parte] or lineas_esperadas[parte]!=lineas_cotizadas[gid]:
                raise ValidationError('La cotización tiene ítems incompletos.')
        total=soles(sum((subtotal[g] for g in grupos[quote.pk]),Decimal(0))+quote.costo_envio)
        if (p.pk,quote.pk,total) in pagos: aprobados.add(p.pk)
    return [p for p in candidatos if p.metodo_pago!='yape' or p.pk in aprobados]

def apto_para_reparto(pedido):
    return bool(aptos_para_reparto([pedido]))

def nombre(user):
    return ' '.join(filter(None,[user.nombres,user.apellido_paterno,user.apellido_materno]))

def _ultimo_por_pedido(queryset):
    """{pedido_id: primera fila según el orden del queryset}, en una consulta."""
    filas={}
    for fila in queryset: filas.setdefault(fila.pedido_id,fila)
    return filas

def pedidos_sin_calificar(pedido_ids, entregas=None):
    """Ids de pedidos entregados a los que les falta reseñar algún puesto o al repartidor.

    Si se pasan `entregas` ({pedido_id: entrega vigente}), los ids ya son de pedidos
    entregados y no se vuelven a consultar.
    """
    from .models import ResenaPuesto, ResenaRepartidor
    ids=list(pedido_ids) if entregas is not None else list(
        Pedido.objects.filter(pk__in=pedido_ids,estado='entregado').values_list('id',flat=True))
    if not ids: return set()
    partes_activas=defaultdict(set)
    for pid,parte in PedidoPuesto.objects.filter(pedido_id__in=ids).exclude(
            estado__in=['rechazado','cancelado']).values_list('pedido_id','id'):
        partes_activas[pid].add(parte)
    calificadas=set(ResenaPuesto.objects.filter(pedido_id__in=ids).values_list('pedido_puesto_id',flat=True))
    if entregas is None:
        entregas=_ultimo_por_pedido(Entrega.objects.filter(pedido_id__in=ids).exclude(
            estado__in=['rechazada','cancelada']).order_by('-id'))
    entregas={pid:e for pid,e in entregas.items() if pid in ids}
    entregas_calificadas=set(ResenaRepartidor.objects.filter(
        entrega_id__in=[e.pk for e in entregas.values()]).values_list('entrega_id',flat=True))
    return {pid for pid in ids if partes_activas[pid]-calificadas
            or (pid in entregas and entregas[pid].pk not in entregas_calificadas)}

def pedidos_operacion_payload(pedidos, comprador=False):
    """Igual que pedido_operacion_payload pero para una lista, con consultas fijas."""
    from .views import pedidos_payload, ultima_cotizacion_por_pedido
    pedidos=list(pedidos)
    if not pedidos: return []
    ids=[p.pk for p in pedidos]
    prefetch_related_objects(pedidos,'mercado')
    quotes=ultima_cotizacion_por_pedido(ids)
    entregas=_ultimo_por_pedido(Entrega.objects.filter(pedido_id__in=ids).exclude(
        estado__in=['rechazada','cancelada']).select_related('repartidor_mercado__repartidor').order_by('-id'))
    pagos=_ultimo_por_pedido(Pago.objects.filter(pedido_id__in=ids,estado__in=['aprobado','procesando']).order_by('-id'))
    entregados=[p.pk for p in pedidos if p.estado=='entregado']
    sin_calificar=pedidos_sin_calificar(entregados,entregas) if comprador and entregados else set()
    resultado=[]
    for pedido,payload in zip(pedidos,pedidos_payload(pedidos,quotes)):
        quote=quotes.get(pedido.pk)
        entrega=entregas.get(pedido.pk)
        pago=pagos.get(pedido.pk)
        if payload['cotizacion'] is not None: payload['cotizacion']['id']=quote.pk
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
        if comprador: payload['pendiente_calificar']=pedido.pk in sin_calificar
        resultado.append(payload)
    return resultado

def pedido_operacion_payload(pedido, comprador=False):
    return pedidos_operacion_payload([pedido],comprador)[0]

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
