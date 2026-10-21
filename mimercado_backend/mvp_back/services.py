from collections import defaultdict
from decimal import Decimal
from uuid import uuid4
from django.db import transaction
from django.db.models import Sum
from django.utils import timezone
from rest_framework.exceptions import ValidationError, PermissionDenied, NotFound
from .models import (Usuario, UsuarioRol, Producto, UnidadMedida, Carrito, CarritoPuesto,
                     CarritoItem, Direccion, Pedido, PedidoPuesto, PedidoDetalle,
                     Cotizacion, CotizacionPuesto, CotizacionDetalle, HistorialEstado)
from .money import cents, line_total, soles


def require_buyer(user):
    if not UsuarioRol.objects.filter(usuario_id=user.pk, rol_codigo='comprador').exists():
        raise PermissionDenied('Esta operación requiere rol comprador.')


def lock_user(user):
    current = Usuario.objects.select_for_update().get(pk=user.pk)
    if current.estado != 'activo':
        raise PermissionDenied('Usuario no activo.')
    return current


def product_check(product, quantity):
    if (not product.activo or not product.disponible or
            product.puesto.estado != 'activo' or not product.puesto.abierto or
            product.puesto.mercado.estado != 'activo'):
        raise ValidationError('El producto o su puesto no está disponible.')
    if not product.unidad_codigo:
        raise ValidationError('El producto no tiene unidad.')
    unit = UnidadMedida.objects.get(pk=product.unidad_codigo)
    if not unit.permite_fraccion and quantity != quantity.to_integral_value():
        raise ValidationError('La unidad del producto no admite fracciones.')
    if product.stock is not None and quantity > product.stock:
        raise ValidationError('Stock insuficiente.')


@transaction.atomic
def put_item(user, product_id, quantity):
    require_buyer(user)
    lock_user(user)  # serializa cambios concurrentes de la misma canasta
    try:
        product = Producto.objects.select_related('puesto__mercado').get(pk=product_id)
    except Producto.DoesNotExist:
        raise NotFound('Producto no encontrado.')
    product_check(product, quantity)
    cart = Carrito.objects.filter(comprador_id=user.pk, estado='abierto').first()
    if cart and cart.mercado_id != product.puesto.mercado_id:
        raise ValidationError('La canasta admite varios puestos de un mismo mercado. Vacíala para cambiar de mercado.')
    if not cart:
        cart = Carrito.objects.create(comprador_id=user.pk, mercado_id=product.puesto.mercado_id)
    group, _ = CarritoPuesto.objects.get_or_create(carrito_id=cart.pk, puesto_id=product.puesto_id,
                                                 defaults={'mercado_id': cart.mercado_id})
    # cantidad es absoluta: repetir la solicitud no duplica unidades.
    CarritoItem.objects.update_or_create(carrito_puesto_id=group.pk, producto_id=product.pk,
                                        defaults={'puesto_id': product.puesto_id, 'cantidad': quantity})
    return cart_payload(user)


def cart_payload(user):
    require_buyer(user)
    cart = Carrito.objects.filter(comprador_id=user.pk, estado='abierto').first()
    if not cart:
        return {'id': None, 'mercado_id': None, 'puestos': [], 'total_productos_centavos': 0}
    groups = []
    grand = Decimal('0')
    for group in CarritoPuesto.objects.filter(carrito_id=cart.pk).select_related(
            'puesto__vendedor','puesto__categoria').order_by('id'):
        items = []
        subtotal = Decimal('0')
        for item in CarritoItem.objects.filter(carrito_puesto_id=group.pk).select_related('producto').order_by('id'):
            total = line_total(item.cantidad, item.producto.precio_unitario)
            subtotal += total
            items.append({'id': item.pk, 'producto_id': item.producto_id, 'nombre': item.producto.nombre,
                          'cantidad': str(item.cantidad), 'unidad': item.producto.unidad_codigo,
                          'precio_unitario_centavos': cents(item.producto.precio_unitario),
                          'disponible':item.producto.disponible,'foto_url':item.producto.foto_url,
                          'subtotal_centavos': cents(total)})
        grand += subtotal
        groups.append({'puesto_id': group.puesto_id, 'nombre': group.puesto.nombre,
                       'mercado_id':group.puesto.mercado_id,'abierto':group.puesto.abierto,
                       'casero':' '.join(filter(None,[group.puesto.vendedor.nombres,group.puesto.vendedor.apellido_paterno])),
                       'categoria':group.puesto.categoria.nombre,'lista_mandado':group.lista_mandado,
                       'items': items, 'subtotal_centavos': cents(subtotal)})
    return {'id': cart.pk, 'mercado_id': cart.mercado_id, 'puestos': groups,
            'total_productos_centavos': cents(grand), 'precio_estimado': True}


@transaction.atomic
def change_item(user, item_id, quantity=None):
    require_buyer(user)
    lock_user(user)
    try:
        item = CarritoItem.objects.select_related('carrito_puesto__carrito').get(
            pk=item_id, carrito_puesto__carrito__comprador_id=user.pk,
            carrito_puesto__carrito__estado='abierto')
    except CarritoItem.DoesNotExist:
        raise NotFound('Ítem no encontrado en tu canasta.')
    if quantity is not None:
        return put_item(user, item.producto_id, quantity)
    group = item.carrito_puesto
    cart = group.carrito
    item.delete()
    if not CarritoItem.objects.filter(carrito_puesto_id=group.pk).exists():
        group.delete()
    if not CarritoPuesto.objects.filter(carrito_id=cart.pk).exists():
        cart.estado = 'abandonado'
        cart.save(update_fields=['estado'])
    return cart_payload(user)


def _productos_para_checkout(ids):
    # FOR UPDATE OF no admite los nombres con esquema usados por estos modelos.
    # Bloquear solo productos y cargar puestos/mercados en consultas aparte.
    return Producto.objects.select_for_update().filter(pk__in=ids).prefetch_related(
        'puesto__mercado').order_by('id')


@transaction.atomic
def checkout(user, address_id, method):
    require_buyer(user)
    lock_user(user)
    try:
        address = Direccion.objects.get(pk=address_id, comprador_id=user.pk, activa=True)
        cart = Carrito.objects.select_for_update().get(comprador_id=user.pk, estado='abierto')
    except Direccion.DoesNotExist:
        raise ValidationError('La dirección no pertenece al comprador o está inactiva.')
    except Carrito.DoesNotExist:
        raise ValidationError('La canasta está vacía.')
    items = list(CarritoItem.objects.filter(carrito_puesto__carrito_id=cart.pk).select_related('carrito_puesto'))
    if not items:
        raise ValidationError('La canasta está vacía.')
    # Bloqueos en orden estable para evitar sobreventa entre compradores.
    products = {p.pk: p for p in _productos_para_checkout([i.producto_id for i in items])}
    for item in items:
        product = products.get(item.producto_id)
        if not product:
            raise ValidationError('Un producto ya no existe.')
        product_check(product, item.cantidad)
    order = Pedido.objects.create(codigo=f'MM-{uuid4().hex[:20]}', comprador_id=user.pk,
        mercado_id=cart.mercado_id, metodo_pago=method, direccion_entrega=address.direccion,
        referencia_entrega=address.referencia, destinatario=' '.join(filter(None,[user.nombres,user.apellido_paterno,user.apellido_materno])),
        celular_contacto=user.celular, latitud=address.latitud, longitud=address.longitud)
    for index, group in enumerate(CarritoPuesto.objects.filter(carrito_id=cart.pk).order_by('id'),1):
        sub = PedidoPuesto.objects.create(pedido_id=order.pk, mercado_id=order.mercado_id,
            puesto_id=group.puesto_id, codigo_bolsa=f'{order.codigo}-{index}', lista_mandado=group.lista_mandado,
            nota=group.nota, audio_url=group.audio_url, responder_antes=timezone.now()+timezone.timedelta(minutes=5))
        for item in [i for i in items if i.carrito_puesto_id==group.pk]:
            product = products[item.producto_id]
            PedidoDetalle.objects.create(pedido_puesto_id=sub.pk, puesto_id=sub.puesto_id,
                producto_id=product.pk, nombre_solicitado=product.nombre, unidad_codigo=product.unidad_codigo,
                cantidad_solicitada=item.cantidad, precio_estimado_unitario=product.precio_unitario)
            if product.stock is not None:
                product.stock -= item.cantidad
                product.save(update_fields=['stock'])
    cart.estado = 'convertido'
    cart.save(update_fields=['estado'])
    HistorialEstado.objects.create(pedido_id=order.pk, estado='pendiente', actor_id=user.pk)
    return order


def quote_total(quote):
    groups = CotizacionPuesto.objects.filter(cotizacion_id=quote.pk)
    expected = set(PedidoPuesto.objects.filter(pedido_id=quote.pedido_id).exclude(
        estado__in=['rechazado','cancelado']).values_list('id',flat=True))
    actual = set(groups.values_list('pedido_puesto_id',flat=True))
    if not expected or expected != actual:
        raise ValidationError('La cotización no contiene todos los puestos activos.')
    for group in groups:
        expected_lines = set(PedidoDetalle.objects.filter(pedido_puesto_id=group.pedido_puesto_id).exclude(
            disponibilidad='sin_stock').values_list('id',flat=True))
        actual_lines = set(CotizacionDetalle.objects.filter(cotizacion_puesto_id=group.pk).values_list('pedido_detalle_id',flat=True))
        if not expected_lines or expected_lines != actual_lines:
            raise ValidationError('La cotización tiene ítems incompletos.')
    products = CotizacionDetalle.objects.filter(cotizacion_puesto__cotizacion_id=quote.pk).aggregate(total=Sum('subtotal'))['total']
    return soles(products + quote.costo_envio)


@transaction.atomic
def accept_quote(user, order_id, quote_id):
    require_buyer(user)
    try:
        order = Pedido.objects.select_for_update().get(pk=order_id, comprador_id=user.pk)
        quote = Cotizacion.objects.select_for_update().get(pk=quote_id, pedido_id=order.pk)
    except (Pedido.DoesNotExist,Cotizacion.DoesNotExist):
        raise NotFound('Pedido o cotización no encontrados.')
    if order.estado in ['cancelado','entregado']:
        raise ValidationError('El pedido ya no admite aceptación.')
    if quote.estado == 'aceptada':
        return quote
    if quote.estado != 'enviada':
        raise ValidationError('Solo se acepta una cotización enviada.')
    if Cotizacion.objects.filter(pedido_id=order.pk,estado='aceptada').exists():
        raise ValidationError('El pedido ya tiene una cotización aceptada.')
    if quote_total(quote) <= 0:
        raise ValidationError('La cotización debe tener un monto positivo.')
    quote.estado = 'aceptada'
    quote.aceptado_en = timezone.now()
    quote.save(update_fields=['estado','aceptado_en'])
    order.estado = 'en_preparacion'
    order.save(update_fields=['estado'])
    PedidoPuesto.objects.filter(
        pedido_id=order.pk,
        estado='pesado',
    ).update(estado='en_preparacion')
    HistorialEstado.objects.create(pedido_id=order.pk,estado='en_preparacion',actor_id=user.pk,
                                  observacion=f'Precio final aceptado: cotización {quote.pk}.')
    return quote


@transaction.atomic
def cancel_order(user, order_id):
    from .models import Pago, Entrega
    require_buyer(user)
    lock_user(user)
    try:
        order=Pedido.objects.select_for_update().get(pk=order_id,comprador_id=user.pk)
    except Pedido.DoesNotExist:
        raise NotFound('Pedido no encontrado.')
    if order.estado=='cancelado':
        return order
    if order.estado in ('entregado','en_recojo','en_camino') or Entrega.objects.filter(
            pedido_id=order.pk).exclude(estado__in=['cancelada','rechazada']).exists():
        raise ValidationError('El pedido ya pasó a logística; solicita soporte.')
    if Pago.objects.filter(pedido_id=order.pk,estado__in=['aprobado','procesando']).exists():
        raise ValidationError('Hay un pago aprobado o en proceso; solicita soporte.')
    details=list(PedidoDetalle.objects.filter(pedido_puesto__pedido_id=order.pk))
    products={p.pk:p for p in Producto.objects.select_for_update().filter(
        pk__in=[d.producto_id for d in details if d.producto_id]).order_by('id')}
    for detail in details:
        product=products.get(detail.producto_id)
        if product and product.stock is not None:
            product.stock+=detail.cantidad_solicitada
            product.save(update_fields=['stock'])
    PedidoPuesto.objects.filter(pedido_id=order.pk).update(estado='cancelado')
    order.estado='cancelado'
    order.motivo_cancelacion='Cancelado por el comprador antes de pago/logística.'
    order.save(update_fields=['estado','motivo_cancelacion'])
    HistorialEstado.objects.create(pedido_id=order.pk,estado='cancelado',actor_id=user.pk)
    return order
