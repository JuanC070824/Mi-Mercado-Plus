"""Checkout API Orders: recibe tokens, nunca números de tarjeta ni CVV."""
import hashlib
from uuid import NAMESPACE_URL, uuid5
import requests
from django.conf import settings
from django.core.cache import cache
from django.db import transaction
from django.utils import timezone
from rest_framework import serializers
from rest_framework.exceptions import ValidationError
from . import mercadopago_pruebas as mp
from .models import Pedido, Cotizacion, Pago


# La cuenta vendedora no cambia entre pagos: verificarla una vez cada pocas
# horas ahorra un viaje a Mercado Pago (unos 0,5 s) en cada cobro.
CUENTA_VERIFICADA_SEGUNDOS = 6 * 60 * 60


def _clave_cuenta():
    origen = f'{settings.MERCADOPAGO_TEST_ACCESS_TOKEN}:{settings.MERCADOPAGO_TEST_USER_ID}'
    return 'mp_cuenta_prueba_ok:' + hashlib.sha256(origen.encode()).hexdigest()


def comprobar_cuenta_prueba():
    """Bloquear credenciales reales antes de enviar un token para cobrar."""
    # Solo se recuerda un resultado válido; si se cambia el token o el id, la
    # clave cambia y se vuelve a verificar con Mercado Pago.
    if cache.get(_clave_cuenta()):
        return
    try:
        response = requests.get('https://api.mercadopago.com/users/me',
            headers={'Authorization': f'Bearer {settings.MERCADOPAGO_TEST_ACCESS_TOKEN}'},
            timeout=(3, 5), allow_redirects=False)
        if response.status_code != 200:
            raise mp.ServicioNoDisponible('El pago en línea no está disponible por ahora. Inténtalo más tarde.')
        cuenta = response.json()
    except (requests.RequestException, ValueError) as exc:
        raise mp.ServicioNoDisponible('El pago en línea no está disponible por ahora. Inténtalo más tarde.') from exc
    if (not isinstance(cuenta, dict) or str(cuenta.get('id')) != settings.MERCADOPAGO_TEST_USER_ID
            or cuenta.get('site_id') != 'MPE' or 'test_user' not in (cuenta.get('tags') or [])):
        raise mp.ServicioNoDisponible('El pago en línea no está disponible por ahora. Inténtalo más tarde.')
    cache.set(_clave_cuenta(), True, CUENTA_VERIFICADA_SEGUNDOS)


class PagoIntegradoSerializer(serializers.Serializer):
    pedido_id = serializers.IntegerField(min_value=1)
    token = serializers.RegexField(r'^[A-Za-z0-9_-]{8,256}$', write_only=True)
    payment_method_id = serializers.RegexField(r'^[a-zA-Z0-9_]{1,40}$')
    payment_type_id = serializers.ChoiceField(choices=['credit_card', 'debit_card'])
    installments = serializers.IntegerField(min_value=1, max_value=48, default=1)
    email = serializers.EmailField(max_length=254)
    identification_type = serializers.ChoiceField(choices=['DNI', 'CE', 'RUC', 'PAS'], required=False)
    identification_number = serializers.RegexField(r'^[A-Za-z0-9]{5,20}$', required=False, write_only=True)
    phone = serializers.RegexField(r'^9[0-9]{8}$', required=False, write_only=True)

    def validate(self, attrs):
        # Una lista explícita impide que PAN/CVV o un monto del cliente lleguen
        # accidentalmente al servidor o a la API del proveedor.
        if set(self.initial_data) - set(self.fields):
            raise ValidationError('El formulario contiene campos no admitidos.')
        if bool(attrs.get('identification_type')) != bool(attrs.get('identification_number')):
            raise ValidationError('Completa el tipo y número de documento.')
        if attrs['payment_method_id'] == 'yape':
            if not attrs.get('phone') or attrs['payment_type_id'] != 'debit_card' or attrs['installments'] != 1:
                raise ValidationError('Revisa el celular y los datos de Yape.')
        return attrs


def pagar(usuario, datos):
    mp.exigir_configuracion()
    if not mp.configuracion()['integrado_configurado']:
        raise mp.ServicioNoDisponible('El pago en línea no está disponible por ahora. Inténtalo más tarde.')
    # Verificar pertenencia antes de cualquier llamada externa.
    mp.contexto(usuario, datos['pedido_id'])
    comprobar_cuenta_prueba()
    # Reserva persistente antes de salir a la red: dos pestañas no pueden
    # iniciar operaciones distintas sobre el mismo pedido simultáneamente.
    with transaction.atomic():
        pedido = Pedido.objects.select_for_update().filter(pk=datos['pedido_id'], comprador_id=usuario.pk).first()
        if pedido is None:
            from rest_framework.exceptions import NotFound
            raise NotFound('Pedido no encontrado.')
        _, total, _ = mp.contexto(usuario, pedido.pk)
        quote = Cotizacion.objects.select_for_update().get(pedido_id=pedido.pk, estado='aceptada')
        if pedido.estado not in ('en_preparacion', 'listo_para_recojo'):
            raise ValidationError('El pedido ya no admite un nuevo pago.')
        if quote.aceptado_en is None or timezone.now() - quote.aceptado_en > timezone.timedelta(hours=24):
            raise ValidationError('El precio final venció (24 horas). Pide a tus caseros que lo confirmen de nuevo.')
        previo = Pago.objects.filter(pedido_id=pedido.pk).order_by('-id').first()
        if previo and previo.estado not in ('rechazado', 'anulado'):
            raise ValidationError('Ya existe un intento de pago. Verifica su estado antes de volver a pagar.')
        # Cambia solo después de un rechazo confirmado; nunca tras un timeout.
        reference = 'mmp_test_' + hashlib.sha256(
            f'{pedido.codigo}:{quote.pk}:{usuario.pk}:{total}:{datos["token"]}'.encode()).hexdigest()[:48]
        reserva = {'cotizacion_id': quote.pk, 'metodo': 'yape', 'canal': 'culqi_sandbox',
                   'estado': 'procesando', 'monto': total, 'moneda': 'PEN',
                   'idempotencia': reference, 'proveedor_transaccion_id': 'mp_test_pending_' + reference[9:],
                   'confirmado_en': None}
        if previo:
            if previo.idempotencia == reference:
                raise ValidationError('Estos datos de pago ya se usaron. Vuelve a llenar el formulario.')
            for campo, valor in reserva.items():
                setattr(previo, campo, valor)
            previo.save(update_fields=list(reserva))
        else:
            Pago.objects.create(pedido_id=pedido.pk, **reserva)
    payer = {'email': datos['email']}
    if datos.get('identification_type'):
        payer['identification'] = {'type': datos['identification_type'], 'number': datos['identification_number']}
    if datos.get('phone'):
        payer['phone'] = {'area_code': '51', 'number': datos['phone']}
    body = {'type': 'online', 'processing_mode': 'automatic', 'total_amount': str(total),
            'external_reference': reference, 'payer': payer,
            'transactions': {'payments': [{'amount': str(total), 'payment_method': {
                'id': datos['payment_method_id'], 'type': datos['payment_type_id'],
                'token': datos['token'], 'installments': datos['installments']}}]}}
    try:
        data = mp.solicitud('POST', body=body, clave=str(uuid5(NAMESPACE_URL, reference)))
    except (mp.SolicitudRechazada, mp.ServicioNoDisponible):
        Pago.objects.filter(pedido_id=pedido.pk, idempotencia=reference,
                            estado='procesando').update(estado='rechazado')
        raise
    mp.validar_order(data, reference, total)
    # Guardar el id aun si la consulta posterior falla; permite recuperar el
    # resultado sin reutilizar el token ni crear una segunda transacción.
    Pago.objects.filter(pedido_id=pedido.pk, idempotencia=reference).update(
        proveedor_transaccion_id=mp.PREFIJO_PAGO + data['id'])
    # En modo automático la respuesta de creación ya trae el resultado. Solo se
    # vuelve a consultar si aún no es definitivo o le falta el importe pagado.
    actual = data if respuesta_definitiva(data) else mp.solicitud('GET', order_id=data['id'])
    return mp.registrar_order(usuario, pedido.pk, actual)


def respuesta_definitiva(data):
    if data.get('status') == 'failed':
        return True
    return (data.get('status') == 'processed' and bool(data.get('status_detail'))
            and data.get('total_paid_amount') is not None)


def cancelar_intento(usuario, pedido_id):
    """Cancela solo una operación de prueba sin pago; no cancela el pedido."""
    mp.exigir_configuracion()
    pedido, total, reference = mp.contexto(usuario, pedido_id)
    data = mp.buscar_order(reference, total)
    if not data:
        raise ValidationError('No hay un pago pendiente para cancelar. Revisa el estado.')
    if data['status'] in ('canceled', 'expired'):
        return mp.registrar_order(usuario, pedido.pk, data)
    if data['status'] not in ('created', 'action_required'):
        raise ValidationError('Este pago ya no se puede cancelar. Revisa el resultado.')
    mp.solicitud('POST', order_id=data['id'], accion='cancel',
                 clave=str(uuid5(NAMESPACE_URL, reference + ':cancel')))
    actual = mp.solicitud('GET', order_id=data['id'])
    mp.validar_order(actual, reference, total)
    # Si llegó a pagarse al mismo tiempo, conciliar la aprobación y no abrir
    # un segundo formulario. La respuesta del proveedor decide el resultado.
    return mp.registrar_order(usuario, pedido.pk, actual)
