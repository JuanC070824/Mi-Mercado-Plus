from django.conf import settings
from django.core import signing
from django.utils.crypto import salted_hmac, constant_time_compare
from rest_framework.authentication import BaseAuthentication, get_authorization_header
from rest_framework.exceptions import AuthenticationFailed
from django.db.models import Exists, OuterRef
from .models import Usuario, UsuarioRol

SALT = 'mimercadoplus.bearer.v1'
ROLES = ('comprador', 'vendedor', 'repartidor', 'administrador')


def tiene_rol(user, rol):
    """¿El usuario tiene el rol? Si vino del token, sus roles ya se leyeron
    junto con él (una consulta menos en cada petición)."""
    roles = getattr(user, '_roles', None)
    if roles is not None and rol in ROLES:
        return rol in roles
    return UsuarioRol.objects.filter(usuario_id=user.pk, rol_codigo=rol).exists()

def password_tag(user):
    return salted_hmac(SALT, user.password_hash).hexdigest()

def issue_token(user):
    return signing.dumps({'uid': user.pk, 'pt': password_tag(user)}, salt=SALT)

class BearerAuthentication(BaseAuthentication):
    def authenticate(self, request):
        header = get_authorization_header(request).split()
        if not header:
            return None
        if len(header) != 2 or header[0].lower() != b'bearer':
            raise AuthenticationFailed('Usa Authorization: Bearer <token>.')
        try:
            payload = signing.loads(header[1].decode('ascii'), salt=SALT,
                                    max_age=settings.AUTH_TOKEN_TTL_SECONDS)
            # El usuario y sus roles en una sola consulta.
            user = Usuario.objects.annotate(**{
                f'_es_{rol}': Exists(UsuarioRol.objects.filter(usuario_id=OuterRef('pk'), rol_codigo=rol))
                for rol in ROLES}).get(pk=payload['uid'], estado='activo')
            user._roles = {rol for rol in ROLES if getattr(user, f'_es_{rol}')}
            if not constant_time_compare(payload.get('pt', ''), password_tag(user)):
                raise AuthenticationFailed('Token revocado.')
        except (signing.BadSignature, ValueError, UnicodeError, KeyError, TypeError, Usuario.DoesNotExist):
            raise AuthenticationFailed('Token inválido o vencido.')
        return user, None

    def authenticate_header(self, request):
        return 'Bearer'
