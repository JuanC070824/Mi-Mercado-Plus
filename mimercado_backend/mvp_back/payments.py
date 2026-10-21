from uuid import uuid4
from django.conf import settings
from django.db import transaction, IntegrityError
from django.utils import timezone
from rest_framework.exceptions import ValidationError, NotFound
from .models import Pedido, Cotizacion, Pago
from .services import require_buyer, quote_total
from .money import cents

class RejectedPayment(Exception):
    pass

class UncertainPayment(Exception):
    pass


def provider_charge(phone, code, amount, email):
    """Simulador local: no accede a pasarelas, bancos ni aplicaciones externas."""
    if settings.PAYMENT_MODE != 'mock':
        raise RejectedPayment('El pago de demostración no está habilitado.')
    if code != settings.MOCK_YAPE_CODE:
        raise RejectedPayment('Código de demostración incorrecto. Usa el indicado en la pantalla.')
    return 'mock_' + uuid4().hex


def payment_result(payment, status=200):
    mode = 'mock' if (payment.proveedor_transaccion_id or '').startswith('mock_') else settings.PAYMENT_MODE
    result = {'success': payment.estado=='aprobado', 'pago_id':payment.pk,'pedido_id':payment.pedido_id,
              'estado':payment.estado,'monto_centavos':cents(payment.monto),'moneda':payment.moneda,
              'modo':mode,'simulado':mode=='mock'}
    if payment.estado=='rechazado':
        status=402
    elif payment.estado=='procesando':
        status=409
        result['detail']='Pago en proceso o pendiente de conciliación; no cree otro intento.'
    return result,status


def pay_order(user, data):
    require_buyer(user)
    if settings.PAYMENT_MODE != 'mock':
        raise ValidationError('El pago no está habilitado.')
    # Reserva persistida ANTES de llamar al proveedor. Serializa por pedido.
    with transaction.atomic():
        try:
            order=Pedido.objects.select_for_update().get(pk=data['pedido_id'],comprador_id=user.pk)
        except Pedido.DoesNotExist:
            raise NotFound('Pedido no encontrado.')
        if order.estado in ('cancelado','entregado'):
            raise ValidationError('El pedido no admite este pago.')
        if order.metodo_pago!='yape':
            raise ValidationError('Este endpoint solo procesa pedidos con método Yape.')
        existing=Pago.objects.filter(idempotencia=data['idempotencia']).first()
        if existing:
            if existing.pedido_id!=order.pk:
                raise ValidationError('La clave de idempotencia ya se usó en otra operación.')
            return payment_result(existing)
        existing=Pago.objects.filter(pedido_id=order.pk,estado__in=['aprobado','procesando']).first()
        if existing:
            return payment_result(existing)
        try:
            quote=Cotizacion.objects.select_for_update().get(pedido_id=order.pk,estado='aceptada')
        except Cotizacion.DoesNotExist:
            raise ValidationError('Primero debes aceptar el precio final.')
        total=quote_total(quote)
        if total<=0:
            raise ValidationError('El monto debe ser positivo.')
        try:
            with transaction.atomic():
                payment=Pago.objects.create(pedido_id=order.pk,cotizacion_id=quote.pk,metodo='yape',
                    # Valor heredado permitido por el CHECK del esquema SQL.
                    # No implica conexión externa: provider_charge es exclusivamente local.
                    canal='culqi_sandbox',estado='procesando',monto=total,idempotencia=data['idempotencia'])
        except IntegrityError:
            raise ValidationError('La clave de idempotencia ya se utilizó; consulta tu pedido.')
    try:
        provider_id=provider_charge(data['celular'],data['codigo'],cents(payment.monto),data.get('correo') or user.correo)
    except RejectedPayment as exc:
        Pago.objects.filter(pk=payment.pk,estado='procesando').update(estado='rechazado',confirmado_en=timezone.now())
        payment.refresh_from_db()
        result,status=payment_result(payment)
        result['detail']=str(exc)
        return result,status
    except UncertainPayment as exc:
        # Mantener procesando bloquea cualquier segundo cargo hasta conciliación manual.
        result,_=payment_result(payment)
        result['detail']=str(exc)
        return result,502
    with transaction.atomic():
        Pedido.objects.select_for_update().get(pk=order.pk)
        payment=Pago.objects.select_for_update().get(pk=payment.pk)
        payment.estado='aprobado'
        payment.proveedor_transaccion_id=provider_id
        payment.confirmado_en=timezone.now()
        payment.save(update_fields=['estado','proveedor_transaccion_id','confirmado_en'])
    return payment_result(payment)
