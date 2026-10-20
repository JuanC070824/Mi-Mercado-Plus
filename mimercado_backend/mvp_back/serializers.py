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
    dni = serializers.RegexField(r'^[0-9]{8}$', write_only=True)
    dni_token = serializers.CharField(write_only=True, max_length=1000)
    celular = PhoneField()
    correo = serializers.EmailField(max_length=254, required=False, allow_blank=True)
    password = serializers.CharField(write_only=True, trim_whitespace=False, max_length=128)
    rol = serializers.ChoiceField(choices=['comprador', 'vendedor', 'repartidor'])
    fecha_nacimiento = serializers.DateField(required=False, allow_null=True)
    letra_grande = serializers.BooleanField(default=False)
    sonido = serializers.BooleanField(default=True)
    vibracion = serializers.BooleanField(default=True)
    direccion = serializers.DictField(required=False, allow_null=True, write_only=True)

    def validate_password(self, value):
        try:
            validate_password(value)
        except DjangoValidationError as exc:
            raise serializers.ValidationError(exc.messages)
        return value

class DniSerializer(serializers.Serializer):
    dni = serializers.RegexField(r'^[0-9]{8}$')

class LoginSerializer(serializers.Serializer):
    celular = PhoneField()
    password = serializers.CharField(write_only=True, trim_whitespace=False, max_length=128)
    rol = serializers.ChoiceField(
        choices=['comprador', 'vendedor', 'repartidor'],
        required=False,
    )

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

class EstadoPuestoSerializer(serializers.Serializer):
    abierto = serializers.BooleanField()

class PuestoVendedorSerializer(serializers.Serializer):
    mercado_id = serializers.IntegerField(min_value=1)
    categoria_id = serializers.IntegerField(min_value=1)
    nombre = serializers.CharField(max_length=150)
    numero = serializers.CharField(max_length=30, required=False, allow_blank=True)
    referencia = serializers.CharField(required=False, allow_blank=True, max_length=300)

class PerfilActualizarSerializer(serializers.Serializer):
    celular = PhoneField(required=False)
    correo = serializers.EmailField(max_length=254, required=False, allow_blank=True)
    password_actual = serializers.CharField(
        write_only=True,
        required=False,
        allow_blank=True,
        trim_whitespace=False,
        max_length=128,
    )
    sonido = serializers.BooleanField(required=False)
    vibracion = serializers.BooleanField(required=False)


ICONOS_PRODUCTO = [
    'icono:verdura', 'icono:fruta', 'icono:tuberculo', 'icono:abarrote',
    'icono:carne', 'icono:pescado', 'icono:lacteo', 'icono:otro',
]


class ProductoVendedorSerializer(serializers.Serializer):
    nombre = serializers.CharField(max_length=150)
    unidad_codigo = serializers.ChoiceField(
        choices=['kg', 'unidad', 'atado', 'litro'],
    )
    precio_unitario = serializers.DecimalField(
        max_digits=12,
        decimal_places=2,
        min_value=Decimal('0.10'),
        max_value=Decimal('99999.99'),
    )
    disponible = serializers.BooleanField(default=True)
    icono = serializers.ChoiceField(choices=ICONOS_PRODUCTO, default='icono:otro')


class DisponibilidadDetalleSerializer(serializers.Serializer):
    disponibilidad = serializers.ChoiceField(
        choices=['pendiente', 'disponible', 'sin_stock', 'reemplazo'],
    )


class AccionPedidoPuestoSerializer(serializers.Serializer):
    accion = serializers.ChoiceField(
        choices=['aceptar', 'rechazar', 'listo', 'entregar'],
    )
    motivo = serializers.CharField(required=False, allow_blank=True, max_length=300)

    def validate(self, attrs):
        if attrs['accion'] == 'rechazar' and not attrs.get('motivo', '').strip():
            raise serializers.ValidationError({'motivo': 'Indica por qué rechazas el pedido.'})
        return attrs


class CotizacionDetalleVendedorSerializer(serializers.Serializer):
    pedido_detalle_id = serializers.IntegerField(min_value=1)
    nombre_final = serializers.CharField(max_length=150)
    cantidad_real = serializers.DecimalField(
        max_digits=12, decimal_places=3, min_value=Decimal('0.001'),
    )
    precio_unitario = serializers.DecimalField(
        max_digits=12, decimal_places=2, min_value=Decimal('0.10'),
    )


class CotizacionVendedorSerializer(serializers.Serializer):
    detalles = CotizacionDetalleVendedorSerializer(many=True, allow_empty=False)
    nota = serializers.CharField(required=False, allow_blank=True, max_length=500)
