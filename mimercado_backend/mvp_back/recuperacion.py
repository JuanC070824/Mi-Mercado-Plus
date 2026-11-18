"""Recuperación de cuenta (RF-04) sin tablas nuevas.

El código de 6 dígitos se calcula con la contraseña actual: deja de servir apenas se cambia
(un solo uso) y vence entre 10 y 20 minutos después de pedirlo.
"""
import hashlib
import hmac
import time
from django.conf import settings

VENTANA_SEGUNDOS=600

def _codigo(user,ventana):
    digest=hmac.new(settings.SECRET_KEY.encode(),f'recuperar:{user.pk}:{user.password_hash}:{ventana}'.encode(),hashlib.sha256).digest()
    return str(int.from_bytes(digest[:8],'big')%1_000_000).zfill(6)

def _ventana_actual():
    return int(time.time()//VENTANA_SEGUNDOS)

def generar_codigo(user):
    return _codigo(user,_ventana_actual())

def codigo_valido(user,codigo):
    ahora=_ventana_actual()
    return any(hmac.compare_digest(_codigo(user,v),codigo) for v in (ahora,ahora-1))

def _normalizar(texto):
    return ' '.join((texto or '').split()).casefold()

def es_titular(user,identidad):
    """El DNI consultado corresponde a la persona que se registró con esa cuenta."""
    return (_normalizar(user.nombres)==_normalizar(identidad.get('nombres'))
            and _normalizar(user.apellido_paterno)==_normalizar(identidad.get('apellido_paterno')))
