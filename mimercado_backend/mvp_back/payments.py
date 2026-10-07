from uuid import uuid4
import requests
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
    """Nunca persiste el código Yape ni devuelve la respuesta cruda del proveedor."""
    if settings.PAYMENT_MODE == 'mock':
        if code != settings.MOCK_YAPE_CODE:
            raise RejectedPayment('Código de simulación incorrecto.')
        return 'mock_' + uuid4().hex
    public, secret = settings.CULQI_PUBLIC_KEY, settings.CULQI_SECRET_KEY
    if settings.PAYMENT_MODE != 'culqi_sandbox' or not public.startswith('pk_test_') or not secret.startswith('sk_test_'):
        raise RejectedPayment('Configura el modo y claves de prueba de Culqi.')
    if not email:
        raise RejectedPayment('Culqi requiere correo para crear el cargo.')
    headers = {'Authorization': f'Bearer {public}', 'Content-Type': 'application/json', 'x-culqi-product': 'online'}
    try:
        response = requests.post('https://secure.culqi.com/v2/tokens/yape', headers=headers,
            json={'number_phone': phone, 'otp': code, 'amount': str(amount)}, timeout=(5,15))
        if not 200 <= response.status_code < 300:
            raise RejectedPayment('Culqi no autorizó la tokenización de prueba.')
        token = response.json().get('id','')
        if not token.startswith('ype_test_'):
            raise RejectedPayment('La respuesta no contiene un token Yape de prueba válido.')
    except (requests.RequestException,ValueError,AttributeError) as exc:
        raise RejectedPayment('No se pudo generar el token de prueba; no se envió un cargo.') from exc
    try:
        response = requests.post('https://api.culqi.com/v2/charges',
            headers={'Authorization': f'Bearer {secret}','Content-Type':'application/json','x-culqi-product':'online'},
            json={'amount': amount,'currency_code':'PEN','email':email,'source_id':token,'capture':True},timeout=(5,15))
        if response.status_code >= 500:
            raise UncertainPayment('Respuesta indeterminada de Culqi; revisar antes de reintentar.')
        if not 200 <= response.status_code < 300:
            raise RejectedPayment('Culqi rechazó el cargo de prueba.')
        charge = response.json().get('id','')
        if not charge.startswith('chr_test_'):
            raise UncertainPayment('No se pudo confirmar la referencia del cargo de prueba.')
        return charge
    except (requests.RequestException,ValueError,AttributeError) as exc:
        raise UncertainPayment('No se pudo confirmar el cargo; revisar antes de reintentar.') from exc


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
    if settings.PAYMENT_MODE not in ('mock','culqi_sandbox'):
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
        if settings.PAYMENT_MODE=='culqi_sandbox':
            if not settings.CULQI_PUBLIC_KEY.startswith('pk_test_') or not settings.CULQI_SECRET_KEY.startswith('sk_test_'):
                raise ValidationError('Se requieren claves pk_test_ y sk_test_; no se admiten claves live.')
            if not (data.get('correo') or user.correo):
                raise ValidationError('Se requiere correo para Culqi.')
        try:
            with transaction.atomic():
                payment=Pago.objects.create(pedido_id=order.pk,cotizacion_id=quote.pk,metodo='yape',
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
