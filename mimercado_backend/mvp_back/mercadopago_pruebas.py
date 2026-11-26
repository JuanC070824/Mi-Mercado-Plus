"""Checkout Pro Orders de prueba, conciliado con el flujo interno existente.

Mercado Pago conserva las orders. Su external_reference permite recuperarlas
tras recargar Flutter o reiniciar Render. No se usa memoria local como registro.
"""
import hashlib
import hmac
import re
from decimal import Decimal, InvalidOperation
from urllib.parse import urlsplit, parse_qs
from uuid import NAMESPACE_URL, uuid5

import requests
from django.conf import settings
from django.db import transaction, IntegrityError
from django.utils import timezone
from rest_framework.exceptions import APIException, NotFound, PermissionDenied, ValidationError

from .models import Cotizacion, Pago, Pedido
from .money import cents
from .services import quote_total, require_buyer

API_URL = 'https://api.mercadopago.com/v1/orders'
TEST_ID = re.compile(r'^ORDTST[A-Z0-9]{10,80}$')
AVISO = 'Mercado Pago de prueba: la aprobación verificada registra el pago y permite continuar el reparto. No uses dinero real.'
PREFIJO_PAGO = 'mp_test_'
# Conexión reutilizable con Mercado Pago: evita repetir el saludo TLS en cada
# llamada (pagar, consultar y confirmar suelen ir seguidas).
_SESION = requests.Session()


class ServicioNoDisponible(APIException):
    status_code = 503
    default_detail = 'Mercado Pago de prueba no está configurado.'


class ErrorProveedor(APIException):
    status_code = 502
    default_detail = 'No pudimos confirmar el pago. Verifica el estado antes de volver a pagar.'


class SolicitudRechazada(ErrorProveedor):
    default_detail = 'Mercado Pago no aceptó los datos. Revisa la tarjeta o el celular e inténtalo de nuevo.'


def configuracion():
    return {
        'habilitado': settings.MERCADOPAGO_PRUEBAS_ENABLED,
        'configurado': bool(settings.MERCADOPAGO_PRUEBAS_ENABLED
                           and settings.MERCADOPAGO_TEST_ACCESS_TOKEN
                           and settings.MERCADOPAGO_TEST_USER_ID),
        'entorno': 'prueba', 'conciliacion_habilitada': True,
        'public_key': settings.MERCADOPAGO_TEST_PUBLIC_KEY,
        'integrado_configurado': bool(settings.MERCADOPAGO_TEST_PUBLIC_KEY),
        'aviso': AVISO,
    }


def exigir_configuracion():
    if not configuracion()['configurado']:
        raise ServicioNoDisponible()


def solicitud(metodo, *, order_id=None, body=None, params=None, clave=None, accion=None):
    exigir_configuracion()
    if order_id is not None and not TEST_ID.fullmatch(str(order_id)):
        raise ErrorProveedor('No pudimos confirmar el pago. Verifica el estado antes de volver a pagar.')
    if accion is not None and (accion != 'cancel' or not order_id or metodo != 'POST'):
        raise ErrorProveedor('Operación no admitida.')
    headers = {'Authorization': f'Bearer {settings.MERCADOPAGO_TEST_ACCESS_TOKEN}',
               'Content-Type': 'application/json', 'Accept': 'application/json'}
    if clave:
        headers['X-Idempotency-Key'] = clave
    try:
        response = _SESION.request(
            metodo, API_URL + (f'/{order_id}' if order_id else '') + (f'/{accion}' if accion else ''),
            headers=headers, json=body, params=params, timeout=(3, 10), allow_redirects=False)
        if response.status_code not in (200, 201):
            # No devolver cuerpos del proveedor: pueden contener datos privados.
            if response.status_code in (401, 403):
                raise ServicioNoDisponible('El pago en línea no está disponible por ahora. Inténtalo más tarde.')
            if metodo == 'POST' and response.status_code in (400, 422):
                raise SolicitudRechazada()
            raise ErrorProveedor()
        data = response.json()
    except (requests.RequestException, ValueError) as exc:
        raise ErrorProveedor() from exc
    if not isinstance(data, dict):
        raise ErrorProveedor()
    return data


def contexto(usuario, pedido_id, *, iniciar=False):
    require_buyer(usuario)
    pedido = Pedido.objects.filter(pk=pedido_id, comprador_id=usuario.pk).first()
    if pedido is None:
        raise NotFound('Pedido no encontrado.')
    quote = Cotizacion.objects.filter(pedido_id=pedido.pk, estado='aceptada').first()
    if quote is None:
        raise ValidationError('Primero acepta el precio final de todos los puestos.')
    if pedido.metodo_pago != 'yape':
        raise ValidationError('Este pedido no se paga en línea.')
    if iniciar:
        if pedido.estado not in ('en_preparacion', 'listo_para_recojo'):
            raise ValidationError('Este pedido ya no se puede pagar en línea.')
        if Pago.objects.filter(pedido_id=pedido.pk, estado__in=['aprobado', 'procesando']).exists():
            raise ValidationError('El pedido ya tiene un pago interno aprobado o en proceso.')
        if quote.aceptado_en is None or timezone.now() - quote.aceptado_en > timezone.timedelta(hours=24):
            raise ValidationError('El precio final venció (24 horas). Pide a tus caseros que lo confirmen de nuevo.')
    total = quote_total(quote)
    if total <= 0:
        raise ValidationError('El precio final debe ser positivo.')
    origen = f'{pedido.codigo}:{quote.pk}:{usuario.pk}:{total}:{settings.MERCADOPAGO_TEST_USER_ID}'
    digest = hmac.new(settings.SECRET_KEY.encode(), origen.encode(), hashlib.sha256).hexdigest()
    reference = 'mmp_test_' + digest[:48]  # ASCII, menos de 64 caracteres.
    # Conservar referencias ya emitidas aunque se rote la clave de Django.
    previo = Pago.objects.filter(pedido_id=pedido.pk, cotizacion_id=quote.pk,
        monto=total, proveedor_transaccion_id__startswith=PREFIJO_PAGO,
        idempotencia__startswith='mmp_test_').order_by('-id').first()
    if previo and re.fullmatch(r'mmp_test_[a-f0-9]{48}', previo.idempotencia):
        reference = previo.idempotencia
    return pedido, total, reference


def validar_order(data, reference, total):
    try:
        amount = Decimal(str(data['total_amount']))
    except (KeyError, InvalidOperation, ValueError):
        raise ErrorProveedor('Mercado Pago devolvió un importe inválido.')
    if (not TEST_ID.fullmatch(str(data.get('id', '')))
            or data.get('type') != 'online'
            or data.get('processing_mode') not in ('manual', 'automatic')
            or data.get('currency') != 'PEN'
            or str(data.get('user_id')) != settings.MERCADOPAGO_TEST_USER_ID
            or data.get('external_reference') != reference
            or not amount.is_finite() or amount != total):
        raise ErrorProveedor('No pudimos confirmar el pago. Verifica el estado antes de volver a pagar.')
    # Algunas respuestas incluyen estas señales; cualquier contradicción bloquea.
    if data.get('live_mode') is True or data.get('country_code', 'PER') != 'PER':
        raise ErrorProveedor('No pudimos confirmar el pago. Verifica el estado antes de volver a pagar.')


def buscar_order(reference, total):
    # El intento más reciente se conserva en BD; no depende del navegador.
    vinculado = Pago.objects.filter(idempotencia=reference,
        proveedor_transaccion_id__startswith=PREFIJO_PAGO).first()
    if vinculado:
        order_id = vinculado.proveedor_transaccion_id[len(PREFIJO_PAGO):]
        if TEST_ID.fullmatch(order_id):
            actual = solicitud('GET', order_id=order_id)
            validar_order(actual, reference, total)
            return actual
    ahora = timezone.now()
    data = solicitud('GET', params={
        'begin_date': (ahora - timezone.timedelta(days=29)).isoformat(),
        'end_date': ahora.isoformat(), 'external_reference': reference, 'limit': 2,
    })
    orders = data.get('data')
    if not isinstance(orders, list):
        raise ErrorProveedor()
    if not orders:
        return None
    if len(orders) != 1:
        raise ErrorProveedor('Hay más de un intento de pago. Pide ayuda en Soporte antes de volver a pagar.')
    row = orders[0]
    if not isinstance(row, dict):
        raise ErrorProveedor()
    if (not TEST_ID.fullmatch(str(row.get('id', '')))
            or row.get('external_reference') != reference):
        raise ErrorProveedor('No pudimos confirmar el pago. Verifica el estado antes de volver a pagar.')
    # El resultado de búsqueda puede omitir checkout_url y otros detalles.
    actual = solicitud('GET', order_id=row['id'])
    validar_order(actual, reference, total)
    return actual


def resultado(data, total):
    estado, detalle = (data or {}).get('status', 'sin_iniciar'), (data or {}).get('status_detail', '')
    aprobado = estado == 'processed' and detalle == 'accredited'
    if aprobado:
        try:
            pagado = Decimal(str(data['total_paid_amount']))
        except (KeyError, InvalidOperation, ValueError):
            raise ErrorProveedor('Falta confirmar el importe acreditado.')
        if not pagado.is_finite() or pagado != total:
            raise ErrorProveedor('El importe acreditado no coincide con la cotización.')
    return {'estado': estado, 'detalle': detalle, 'aprobado_en_proveedor': aprobado,
            'monto_centavos': cents(total), 'moneda': 'PEN', 'entorno': 'prueba',
            'registro_interno': False, 'reparto_habilitado': False, 'aviso': AVISO}


def consultar_estado(usuario, pedido_id):
    exigir_configuracion()
    pedido, total, reference = contexto(usuario, pedido_id)
    data = buscar_order(reference, total)
    return respuesta_pedido(data, total, pedido)


def respuesta_pedido(data, total, pedido):
    respuesta = resultado(data, total)
    pago = None if not data else Pago.objects.filter(
        pedido_id=pedido.pk, proveedor_transaccion_id=PREFIJO_PAGO + data['id'],
        monto=total, moneda='PEN').first()
    aprobado = bool(pago and pago.estado == 'aprobado' and respuesta['aprobado_en_proveedor'])
    respuesta.update(pedido_id=pedido.pk, pago_id=pago.pk if pago else None,
        registro_interno=pago is not None, pago_interno_aprobado=aprobado,
        reparto_habilitado=aprobado and pedido.estado != 'cancelado')
    respuesta['formulario_integrado'] = bool(data and data.get('processing_mode') == 'automatic')
    return respuesta


def registrar_order(usuario, pedido_id, data):
    """Red fuera de la transacción; bloqueo por pedido e idempotencia en la BD.

    Los nombres yape/culqi_sandbox son compatibilidad con los CHECK existentes.
    El proveedor verdadero se identifica siempre con mp_test_ORDTST..., nunca
    se llama a Culqi ni al simulador de Yape para confirmar Mercado Pago.
    """
    try:
        with transaction.atomic():
            pedido = Pedido.objects.select_for_update().get(pk=pedido_id, comprador_id=usuario.pk)
            quote = Cotizacion.objects.select_for_update().filter(pedido_id=pedido.pk, estado='aceptada').first()
            if quote is None:
                raise ValidationError('La cotización ya no está aceptada.')
            _, total, reference = contexto(usuario, pedido.pk)
            validar_order(data, reference, total)
            verificado = resultado(data, total)  # También exige importe íntegro acreditado.
            if pedido.estado == 'cancelado':
                raise ValidationError('El pedido fue cancelado; el pago requiere revisión manual.')
            proveedor_id = PREFIJO_PAGO + data['id']
            pago = Pago.objects.filter(proveedor_transaccion_id=proveedor_id).first()
            if pago is None:
                # Recuperación tras perder la respuesta de la creación: solo
                # puede enlazarse la reserva exacta, nunca otra order existente.
                pago = Pago.objects.filter(pedido_id=pedido.pk, idempotencia=reference,
                    proveedor_transaccion_id='mp_test_pending_' + reference[9:],
                    estado='procesando').first()
                if pago:
                    pago.proveedor_transaccion_id = proveedor_id
                    pago.save(update_fields=['proveedor_transaccion_id'])
            if pago and (pago.pedido_id != pedido.pk or pago.cotizacion_id != quote.pk
                         or pago.monto != total or pago.idempotencia != reference):
                raise ValidationError('La operación ya está vinculada a otro pago o cotización.')
            otros = Pago.objects.filter(pedido_id=pedido.pk, estado__in=['aprobado', 'procesando'])
            if pago:
                otros = otros.exclude(pk=pago.pk)
            if otros.exists():
                raise ValidationError('Ya hay otro pago aprobado o en proceso. Revisa el estado antes de continuar.')
            estado = 'pendiente'
            if verificado['aprobado_en_proveedor']:
                estado = 'aprobado'
            elif data.get('status') == 'failed':
                estado = 'rechazado'
            elif data.get('status') in ('canceled', 'expired', 'charged_back'):
                estado = 'anulado'
            elif data.get('status') == 'refunded' or data.get('status_detail') == 'partially_refunded':
                estado = 'reembolsado'
            if pago is None:
                if pedido.estado not in ('en_preparacion', 'listo_para_recojo'):
                    raise ValidationError('El pedido ya no permite registrar un nuevo pago.')
                pago = Pago.objects.create(pedido_id=pedido.pk, cotizacion_id=quote.pk,
                    metodo='yape', canal='culqi_sandbox', estado=estado, monto=total,
                    moneda='PEN', idempotencia=reference, proveedor_transaccion_id=proveedor_id,
                    confirmado_en=timezone.now() if estado != 'pendiente' else None)
            elif pago.estado != estado and not (pago.estado == 'aprobado' and estado == 'pendiente'):
                pago.estado = estado
                pago.confirmado_en = timezone.now() if estado != 'pendiente' else None
                pago.save(update_fields=['estado', 'confirmado_en'])
            return respuesta_pedido(data, total, pedido)
    except IntegrityError as exc:
        raise ValidationError('Este pago ya está registrado. Actualiza para ver su estado.') from exc


def confirmar_pago(usuario, pedido_id):
    exigir_configuracion()
    pedido, total, reference = contexto(usuario, pedido_id)
    data = buscar_order(reference, total)
    if data is None:
        # Una solicitud puede haber llegado al proveedor aunque su respuesta se
        # haya perdido. Conservar el bloqueo hasta recuperar esa operación.
        if Pago.objects.filter(pedido_id=pedido.pk, estado='procesando').exists():
            return {**respuesta_pedido(None, total, pedido), 'estado': 'processing',
                    'registro_interno': True, 'pago_interno_aprobado': False}
        return respuesta_pedido(None, total, pedido)
    return registrar_order(usuario, pedido.pk, data)


def validar_url_checkout(url, order_id):
    try:
        parsed = urlsplit(url)
        valido = (parsed.scheme == 'https' and parsed.hostname in ('www.mercadopago.com.pe', 'mercadopago.com.pe')
                  and parsed.port in (None, 443) and not parsed.username and not parsed.password
                  and parsed.path == '/checkout/v1/redirect'
                  and parse_qs(parsed.query).get('order_id') == [order_id])
    except (ValueError, TypeError):
        valido = False
    if not valido:
        raise ErrorProveedor('No pudimos abrir la página de pago. Inténtalo de nuevo.')
    return url


def crear_checkout(usuario, pedido_id):
    exigir_configuracion()
    pedido, total, reference = contexto(usuario, pedido_id, iniciar=True)
    data = buscar_order(reference, total)
    if data is None:
        body = {'type': 'online', 'processing_mode': 'manual', 'total_amount': str(total),
                'external_reference': reference,
                'items': [{'title': 'Pedido de prueba MiMercado+', 'quantity': 1, 'unit_price': str(total)}]}
        # No transferir nombres, teléfonos, direcciones o correos del comprador.
        # El usuario introduce sus datos de prueba directamente en el checkout.
        retorno = settings.MERCADOPAGO_RETURN_URL
        if retorno:
            parsed = urlsplit(retorno)
            if parsed.scheme != 'https' or not parsed.netloc or parsed.username or parsed.password:
                raise ServicioNoDisponible('El pago en línea no está disponible por ahora. Inténtalo más tarde.')
            body['config'] = {'online': {'success_url': retorno, 'failure_url': retorno, 'pending_url': retorno}}
        data = solicitud('POST', body=body, clave=str(uuid5(NAMESPACE_URL, reference)))
        validar_order(data, reference, total)
    # Un checkout terminal no se vuelve a abrir ni se reemplaza silenciosamente.
    checkout_url = (validar_url_checkout(data.get('checkout_url'), data['id'])
                    if data.get('status') in ('created', 'processing', 'action_required') else None)
    result = registrar_order(usuario, pedido.pk, data)
    result['checkout_url'] = checkout_url
    return result


def validar_firma_webhook(request):
    secret = settings.MERCADOPAGO_WEBHOOK_SECRET
    if not secret:
        raise ServicioNoDisponible('El webhook de prueba no está configurado.')
    order_id = request.query_params.get('data.id', '')
    request_id = request.headers.get('x-request-id', '')
    try:
        parts = dict(item.strip().split('=', 1) for item in request.headers.get('x-signature', '').split(','))
        ts, firma = parts['ts'], parts['v1']
        if not ts.isdigit() or not re.fullmatch(r'[a-fA-F0-9]{64}', firma):
            raise ValueError()
    except (KeyError, ValueError):
        raise PermissionDenied('Firma de notificación inválida.')
    if not TEST_ID.fullmatch(order_id) or not request_id or len(request_id) > 200:
        raise PermissionDenied('Notificación de prueba inválida.')
    manifest = f'id:{order_id.lower()};request-id:{request_id};ts:{ts};'
    expected = hmac.new(secret.encode(), manifest.encode(), hashlib.sha256).hexdigest()
    if not hmac.compare_digest(expected, firma.lower()):
        raise PermissionDenied('Firma de notificación inválida.')
    # El body no determina ni el estado ni el recurso que se consulta.
    if (not isinstance(request.data, dict) or request.data.get('type') != 'order'
            or request.data.get('live_mode') is not False
            or not isinstance(request.data.get('data'), dict)
            or request.data['data'].get('id') != order_id):
        raise ValidationError('La notificación no corresponde a una order de prueba.')
    return order_id


def recibir_webhook(request):
    exigir_configuracion()
    order_id = validar_firma_webhook(request)
    data = solicitud('GET', order_id=order_id)
    reference = data.get('external_reference', '')
    if not isinstance(reference, str) or not re.fullmatch(r'mmp_test_[a-f0-9]{48}', reference):
        raise ValidationError('La order no corresponde a esta integración.')
    # Solo conciliar orders previamente vinculadas al crear el checkout.
    try:
        total = Decimal(str(data['total_amount']))
    except (KeyError, InvalidOperation, ValueError):
        raise ErrorProveedor()
    validar_order(data, reference, total)
    pago = Pago.objects.filter(proveedor_transaccion_id__in=[PREFIJO_PAGO + order_id,
                              'mp_test_pending_' + reference[9:]],
                              idempotencia=reference).select_related('pedido__comprador').first()
    if pago is None:
        return {'recibido': True, 'registro_interno': False, 'reparto_habilitado': False,
                'aviso': 'Order anterior al enlace interno. Confirma desde la cuenta compradora.'}
    respuesta = registrar_order(pago.pedido.comprador, pago.pedido_id, data)
    return {'recibido': True, **respuesta}
