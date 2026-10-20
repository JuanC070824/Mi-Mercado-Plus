import requests
from django.conf import settings
from django.core import signing


class DniNoEncontrado(Exception):
    pass


class DniServicioNoDisponible(Exception):
    pass


def _titulo(valor):
    return ' '.join(palabra.capitalize() for palabra in valor.strip().split())


def consultar_dni(dni):
    if not settings.JSONPE_KEY:
        raise DniServicioNoDisponible('La consulta de DNI no está configurada.')
    try:
        response = requests.post(
            settings.JSONPE_DNI_URL,
            json={'dni': dni},
            headers={
                'Authorization': f'Bearer {settings.JSONPE_KEY}',
                'Content-Type': 'application/json',
            },
            timeout=settings.JSONPE_TIMEOUT_SECONDS,
        )
    except requests.RequestException as exc:
        raise DniServicioNoDisponible('No pudimos consultar el DNI en este momento.') from exc

    if response.status_code == 404:
        raise DniNoEncontrado('No encontramos este DNI.')
    if response.status_code >= 400:
        raise DniServicioNoDisponible('El servicio de DNI no está disponible en este momento.')
    try:
        payload = response.json()
        data = payload.get('data') if isinstance(payload, dict) else None
    except ValueError as exc:
        raise DniServicioNoDisponible('El servicio de DNI devolvió una respuesta inválida.') from exc
    if not isinstance(data, dict):
        if isinstance(payload, dict) and payload.get('success') is False:
            raise DniNoEncontrado('No encontramos este DNI.')
        raise DniServicioNoDisponible('El servicio de DNI devolvió una respuesta incompleta.')

    nombres = str(data.get('nombres') or '').strip()
    paterno = str(data.get('apellido_paterno') or '').strip()
    materno = str(data.get('apellido_materno') or '').strip()
    if not nombres or not paterno:
        raise DniNoEncontrado('No encontramos datos completos para este DNI.')
    return {
        'dni': dni,
        'nombres': _titulo(nombres),
        'apellido_paterno': _titulo(paterno),
        'apellido_materno': _titulo(materno),
    }


def firmar_consulta(datos):
    return signing.dumps(datos, salt='mimercado.dni', compress=True)


def leer_consulta(token, dni):
    try:
        datos = signing.loads(
            token,
            salt='mimercado.dni',
            max_age=settings.JSONPE_REGISTRATION_TOKEN_TTL_SECONDS,
        )
    except signing.SignatureExpired as exc:
        raise ValueError('La consulta del DNI venció. Vuelve a consultarlo.') from exc
    except signing.BadSignature as exc:
        raise ValueError('La validación del DNI no es válida. Vuelve a consultarlo.') from exc
    if not isinstance(datos, dict) or datos.get('dni') != dni:
        raise ValueError('El DNI no coincide con la consulta realizada.')
    return datos
