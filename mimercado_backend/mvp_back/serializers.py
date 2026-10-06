import re
from decimal import Decimal
from rest_framework import serializers
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError

class PhoneField(serializers.CharField):
    def to_internal_value(self, data):
        value = super().to_internal_value(data)
        value = re.sub(r'[\s()-]', '', value)
        if value.startswith('+51'):
            value = value[3:]
        if not re.fullmatch(r'9[0-9]{8}', value):
            raise serializers.ValidationError('Usa un celular peruano de 9 dígitos que comience por 9.')
        return value

class RegistroSerializer(serializers.Serializer):
    nombres = serializers.CharField(max_length=100)
    apellido_paterno = serializers.CharField(max_length=80, required=False, allow_blank=True)
    apellido_materno = serializers.CharField(max_length=80, required=False, allow_blank=True)
    celular = PhoneField()
    correo = serializers.EmailField(max_length=254, required=False, allow_blank=True)
    password = serializers.CharField(write_only=True, trim_whitespace=False, max_length=128)

    def validate_password(self, value):
        try:
            validate_password(value)
        except DjangoValidationError as exc:
            raise serializers.ValidationError(exc.messages)
        return value

class LoginSerializer(serializers.Serializer):
    celular = PhoneField()
    password = serializers.CharField(write_only=True, trim_whitespace=False, max_length=128)

class ItemSerializer(serializers.Serializer):
    producto_id = serializers.IntegerField(min_value=1)
    cantidad = serializers.DecimalField(max_digits=12, decimal_places=3, min_value=Decimal('0.001'))

class CantidadSerializer(serializers.Serializer):
    cantidad = serializers.DecimalField(max_digits=12, decimal_places=3, min_value=Decimal('0.001'))

class PedidoSerializer(serializers.Serializer):
    direccion_id = serializers.IntegerField(min_value=1)
    metodo_pago = serializers.ChoiceField(choices=['yape', 'efectivo', 'plin'])

class PagoSerializer(serializers.Serializer):
    pedido_id = serializers.IntegerField(min_value=1)
    celular = PhoneField()
    codigo = serializers.RegexField(r'^[0-9]{6}$', write_only=True)
    idempotencia = serializers.RegexField(r'^[A-Za-z0-9_-]{8,80}$')
    correo = serializers.EmailField(max_length=254, required=False)

class DireccionSerializer(serializers.Serializer):
    etiqueta = serializers.CharField(max_length=50, default='Casa')
    direccion = serializers.CharField()
    referencia = serializers.CharField(required=False, allow_blank=True)
    principal = serializers.BooleanField(default=False)
