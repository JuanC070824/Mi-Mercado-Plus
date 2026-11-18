from django.conf import settings
from django.core import signing
from django.utils.crypto import salted_hmac, constant_time_compare
from rest_framework.authentication import BaseAuthentication, get_authorization_header
from rest_framework.exceptions import AuthenticationFailed
from .models import Usuario

SALT = 'mimercadoplus.bearer.v1'

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
            user = Usuario.objects.get(pk=payload['uid'], estado='activo')
            if not constant_time_compare(payload.get('pt', ''), password_tag(user)):
                raise AuthenticationFailed('Token revocado.')
        except (signing.BadSignature, ValueError, UnicodeError, KeyError, TypeError, Usuario.DoesNotExist):
            raise AuthenticationFailed('Token inválido o vencido.')
        return user, None

    def authenticate_header(self, request):
        return 'Bearer'
