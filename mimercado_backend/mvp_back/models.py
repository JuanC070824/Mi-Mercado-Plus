"""Mapeo revisado del SQL v1. managed=False: las 28 tablas existentes no se recrean.
Las FK simples facilitan consultas; PostgreSQL conserva las FK compuestas del SQL.
No se ejecutó inspectdb contra Aiven: no se han proporcionado credenciales.
"""
from decimal import Decimal
from django.db import models
from django.db.models.functions import Round
from django.utils import timezone


class Rol(models.Model):
    codigo = models.CharField(max_length=20, primary_key=True)
    nombre = models.CharField(max_length=60)

    class Meta:
        managed = False
        db_table = '"mimercadoplus"."roles"'

class Usuario(models.Model):
    id = models.BigAutoField(primary_key=True)
    nombres = models.CharField(max_length=100)
    apellido_paterno = models.CharField(max_length=80, null=True, blank=True)
    apellido_materno = models.CharField(max_length=80, null=True, blank=True)
    celular = models.CharField(max_length=20, unique=True, null=True, blank=True)
    correo = models.CharField(max_length=254, null=True, blank=True)
    password_hash = models.TextField()
    estado = models.CharField(max_length=15, default='activo')
    fecha_nacimiento = models.DateField(null=True, blank=True)
    letra_grande = models.BooleanField(default=False)
    sonido = models.BooleanField(default=True)
    vibracion = models.BooleanField(default=True)
    creado_en = models.DateTimeField(default=timezone.now)

    @property
    def is_authenticated(self):
        return True

    @property
    def is_anonymous(self):
        return False

    class Meta:
        managed = False
        db_table = '"mimercadoplus"."usuarios"'

class UsuarioRol(models.Model):
    pk = models.CompositePrimaryKey("usuario_id", "rol_codigo")
    usuario_id = models.BigIntegerField()
    rol_codigo = models.CharField(max_length=20)

    class Meta:
        managed = False
        db_table = '"mimercadoplus"."usuario_roles"'

class Mercado(models.Model):
    id = models.BigAutoField(primary_key=True)
    nombre = models.CharField(max_length=150)
    direccion = models.TextField()
    distrito = models.CharField(max_length=100, null=True, blank=True)
    provincia = models.CharField(max_length=100, null=True, blank=True)
    departamento = models.CharField(max_length=100, null=True, blank=True)
    latitud = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    longitud = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    estado = models.CharField(max_length=15, default='activo')
    creado_en = models.DateTimeField(default=timezone.now)

    class Meta:
        managed = False
        db_table = '"mimercadoplus"."mercados"'

class Categoria(models.Model):
    id = models.BigAutoField(primary_key=True)
    nombre = models.CharField(max_length=100, unique=True)
    padre = models.ForeignKey('Categoria', on_delete=models.DO_NOTHING, db_column="padre_id", related_name="+", null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"mimercadoplus"."categorias"'

class UnidadMedida(models.Model):
    codigo = models.CharField(max_length=15, primary_key=True)
    nombre = models.CharField(max_length=50)
    permite_fraccion = models.BooleanField()

    class Meta:
        managed = False
        db_table = '"mimercadoplus"."unidades_medida"'

class Puesto(models.Model):
    id = models.BigAutoField(primary_key=True)
    mercado = models.ForeignKey('Mercado', on_delete=models.DO_NOTHING, db_column="mercado_id", related_name="+")
    vendedor = models.ForeignKey('Usuario', on_delete=models.DO_NOTHING, db_column="vendedor_id", related_name="+")
    rol_vendedor = models.CharField(max_length=20, default='vendedor')
    categoria = models.ForeignKey('Categoria', on_delete=models.DO_NOTHING, db_column="categoria_id", related_name="+")
    nombre = models.CharField(max_length=150)
    numero = models.CharField(max_length=30, null=True, blank=True)
    descripcion = models.TextField(null=True, blank=True)
    foto_url = models.TextField(null=True, blank=True)
    contacto_billetera = models.CharField(max_length=20, null=True, blank=True)
    qr_billetera_url = models.TextField(null=True, blank=True)
    abierto = models.BooleanField(default=False)
    estado = models.CharField(max_length=15, default='activo')
    creado_en = models.DateTimeField(default=timezone.now)

    class Meta:
        managed = False
        db_table = '"mimercadoplus"."puestos"'

class HorarioPuesto(models.Model):
    id = models.BigAutoField(primary_key=True)
    puesto = models.ForeignKey('Puesto', on_delete=models.DO_NOTHING, db_column="puesto_id", related_name="+")
    dia_semana = models.SmallIntegerField()
    apertura = models.TimeField()
    cierre = models.TimeField()

    class Meta:
        managed = False
        db_table = '"mimercadoplus"."horarios_puesto"'

class Producto(models.Model):
    id = models.BigAutoField(primary_key=True)
    puesto = models.ForeignKey('Puesto', on_delete=models.DO_NOTHING, db_column="puesto_id", related_name="+")
    categoria = models.ForeignKey('Categoria', on_delete=models.DO_NOTHING, db_column="categoria_id", related_name="+", null=True, blank=True)
    nombre = models.CharField(max_length=150)
    descripcion = models.TextField(null=True, blank=True)
    foto_url = models.TextField(null=True, blank=True)
    unidad_codigo = models.CharField(max_length=15)
    precio_unitario = models.DecimalField(max_digits=12, decimal_places=2)
    disponible = models.BooleanField(default=True)
    stock = models.DecimalField(max_digits=12, decimal_places=3, null=True, blank=True)
    activo = models.BooleanField(default=True)
    creado_en = models.DateTimeField(default=timezone.now)

    class Meta:
        managed = False
        db_table = '"mimercadoplus"."productos"'

class RepartidorMercado(models.Model):
    id = models.BigAutoField(primary_key=True)
    repartidor = models.ForeignKey('Usuario', on_delete=models.DO_NOTHING, db_column="repartidor_id", related_name="+")
    rol_repartidor = models.CharField(max_length=20, default='repartidor')
    mercado = models.ForeignKey('Mercado', on_delete=models.DO_NOTHING, db_column="mercado_id", related_name="+")
    movilidad = models.CharField(max_length=30)
    placa = models.CharField(max_length=20, null=True, blank=True)
    descripcion_movilidad = models.CharField(max_length=150, null=True, blank=True)
    autorizado = models.BooleanField(default=False)
    disponible = models.BooleanField(default=False)
    inicio_en = models.DateTimeField(default=timezone.now)
    fin_en = models.DateTimeField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"mimercadoplus"."repartidor_mercados"'

class Direccion(models.Model):
    id = models.BigAutoField(primary_key=True)
    comprador = models.ForeignKey('Usuario', on_delete=models.DO_NOTHING, db_column="comprador_id", related_name="+")
    rol_comprador = models.CharField(max_length=20, default='comprador')
    etiqueta = models.CharField(max_length=50, default='Casa')
    direccion = models.TextField()
    referencia = models.TextField(null=True, blank=True)
    latitud = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    longitud = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    principal = models.BooleanField(default=False)
    activa = models.BooleanField(default=True)

    class Meta:
        managed = False
        db_table = '"mimercadoplus"."direcciones"'

class Carrito(models.Model):
    id = models.BigAutoField(primary_key=True)
    comprador = models.ForeignKey('Usuario', on_delete=models.DO_NOTHING, db_column="comprador_id", related_name="+")
    rol_comprador = models.CharField(max_length=20, default='comprador')
    mercado = models.ForeignKey('Mercado', on_delete=models.DO_NOTHING, db_column="mercado_id", related_name="+")
    estado = models.CharField(max_length=15, default='abierto')
    creado_en = models.DateTimeField(default=timezone.now)

    class Meta:
        managed = False
        db_table = '"mimercadoplus"."carritos"'

class CarritoPuesto(models.Model):
    id = models.BigAutoField(primary_key=True)
    carrito = models.ForeignKey('Carrito', on_delete=models.DO_NOTHING, db_column="carrito_id", related_name="+")
    mercado = models.ForeignKey('Mercado', on_delete=models.DO_NOTHING, db_column="mercado_id", related_name="+")
    puesto = models.ForeignKey('Puesto', on_delete=models.DO_NOTHING, db_column="puesto_id", related_name="+")
    lista_mandado = models.TextField(null=True, blank=True)
    nota = models.TextField(null=True, blank=True)
    audio_url = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"mimercadoplus"."carrito_puestos"'

class CarritoItem(models.Model):
    id = models.BigAutoField(primary_key=True)
    carrito_puesto = models.ForeignKey('CarritoPuesto', on_delete=models.DO_NOTHING, db_column="carrito_puesto_id", related_name="+")
    puesto = models.ForeignKey('Puesto', on_delete=models.DO_NOTHING, db_column="puesto_id", related_name="+")
    producto = models.ForeignKey('Producto', on_delete=models.DO_NOTHING, db_column="producto_id", related_name="+")
    cantidad = models.DecimalField(max_digits=12, decimal_places=3)

    class Meta:
        managed = False
        db_table = '"mimercadoplus"."carrito_items"'

class Pedido(models.Model):
    id = models.BigAutoField(primary_key=True)
    codigo = models.CharField(max_length=40, unique=True)
    comprador = models.ForeignKey('Usuario', on_delete=models.DO_NOTHING, db_column="comprador_id", related_name="+")
    rol_comprador = models.CharField(max_length=20, default='comprador')
    mercado = models.ForeignKey('Mercado', on_delete=models.DO_NOTHING, db_column="mercado_id", related_name="+")
    estado = models.CharField(max_length=30, default='pendiente')
    metodo_pago = models.CharField(max_length=15)
    direccion_entrega = models.TextField()
    referencia_entrega = models.TextField(null=True, blank=True)
    destinatario = models.CharField(max_length=180)
    celular_contacto = models.CharField(max_length=20)
    latitud = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    longitud = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    programado_para = models.DateTimeField(null=True, blank=True)
    creado_en = models.DateTimeField(default=timezone.now)
    motivo_cancelacion = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"mimercadoplus"."pedidos"'

class PedidoPuesto(models.Model):
    id = models.BigAutoField(primary_key=True)
    pedido = models.ForeignKey('Pedido', on_delete=models.DO_NOTHING, db_column="pedido_id", related_name="+")
    mercado = models.ForeignKey('Mercado', on_delete=models.DO_NOTHING, db_column="mercado_id", related_name="+")
    puesto = models.ForeignKey('Puesto', on_delete=models.DO_NOTHING, db_column="puesto_id", related_name="+")
    codigo_bolsa = models.CharField(max_length=50, unique=True)
    estado = models.CharField(max_length=25, default='pendiente')
    lista_mandado = models.TextField(null=True, blank=True)
    nota = models.TextField(null=True, blank=True)
    audio_url = models.TextField(null=True, blank=True)
    motivo_rechazo = models.TextField(null=True, blank=True)
    aceptado_en = models.DateTimeField(null=True, blank=True)
    listo_en = models.DateTimeField(null=True, blank=True)
    responder_antes = models.DateTimeField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"mimercadoplus"."pedido_puestos"'

class PedidoDetalle(models.Model):
    id = models.BigAutoField(primary_key=True)
    pedido_puesto = models.ForeignKey('PedidoPuesto', on_delete=models.DO_NOTHING, db_column="pedido_puesto_id", related_name="+")
    puesto = models.ForeignKey('Puesto', on_delete=models.DO_NOTHING, db_column="puesto_id", related_name="+")
    producto = models.ForeignKey('Producto', on_delete=models.DO_NOTHING, db_column="producto_id", related_name="+", null=True, blank=True)
    nombre_solicitado = models.CharField(max_length=150)
    unidad_codigo = models.CharField(max_length=15)
    cantidad_solicitada = models.DecimalField(max_digits=12, decimal_places=3)
    precio_estimado_unitario = models.DecimalField(max_digits=12, decimal_places=2)
    disponibilidad = models.CharField(max_length=20, default='pendiente')

    class Meta:
        managed = False
        db_table = '"mimercadoplus"."pedido_detalles"'

class Cotizacion(models.Model):
    id = models.BigAutoField(primary_key=True)
    pedido = models.ForeignKey('Pedido', on_delete=models.DO_NOTHING, db_column="pedido_id", related_name="+")
    version = models.IntegerField()
    estado = models.CharField(max_length=15, default='borrador')
    costo_envio = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal("0"))
    ganancia_repartidor = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal("0"))
    creado_en = models.DateTimeField(default=timezone.now)
    aceptado_en = models.DateTimeField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"mimercadoplus"."cotizaciones"'

class CotizacionPuesto(models.Model):
    id = models.BigAutoField(primary_key=True)
    cotizacion = models.ForeignKey('Cotizacion', on_delete=models.DO_NOTHING, db_column="cotizacion_id", related_name="+")
    pedido = models.ForeignKey('Pedido', on_delete=models.DO_NOTHING, db_column="pedido_id", related_name="+")
    pedido_puesto = models.ForeignKey('PedidoPuesto', on_delete=models.DO_NOTHING, db_column="pedido_puesto_id", related_name="+")
    tasa_comision = models.DecimalField(max_digits=6, decimal_places=5, default=Decimal("0.05000"))

    class Meta:
        managed = False
        db_table = '"mimercadoplus"."cotizacion_puestos"'

class CotizacionDetalle(models.Model):
    id = models.BigAutoField(primary_key=True)
    cotizacion_puesto = models.ForeignKey('CotizacionPuesto', on_delete=models.DO_NOTHING, db_column="cotizacion_puesto_id", related_name="+")
    pedido_puesto = models.ForeignKey('PedidoPuesto', on_delete=models.DO_NOTHING, db_column="pedido_puesto_id", related_name="+")
    pedido_detalle = models.ForeignKey('PedidoDetalle', on_delete=models.DO_NOTHING, db_column="pedido_detalle_id", related_name="+")
    nombre_final = models.CharField(max_length=150)
    producto_final = models.ForeignKey('Producto', on_delete=models.DO_NOTHING, db_column="producto_final_id", related_name="+", null=True, blank=True)
    puesto = models.ForeignKey('Puesto', on_delete=models.DO_NOTHING, db_column="puesto_id", related_name="+")
    unidad_codigo = models.CharField(max_length=15)
    cantidad_real = models.DecimalField(max_digits=12, decimal_places=3)
    precio_unitario = models.DecimalField(max_digits=12, decimal_places=2)
    subtotal = models.GeneratedField(expression=Round(models.F("cantidad_real") * models.F("precio_unitario"), 2), output_field=models.DecimalField(max_digits=14, decimal_places=2), db_persist=True)

    class Meta:
        managed = False
        db_table = '"mimercadoplus"."cotizacion_detalles"'

class Pago(models.Model):
    id = models.BigAutoField(primary_key=True)
    pedido = models.ForeignKey('Pedido', on_delete=models.DO_NOTHING, db_column="pedido_id", related_name="+")
    cotizacion = models.ForeignKey('Cotizacion', on_delete=models.DO_NOTHING, db_column="cotizacion_id", related_name="+")
    metodo = models.CharField(max_length=15)
    canal = models.CharField(max_length=20)
    estado = models.CharField(max_length=15, default='pendiente')
    monto = models.DecimalField(max_digits=14, decimal_places=2)
    moneda = models.CharField(max_length=3, default='PEN')
    idempotencia = models.CharField(max_length=100, unique=True)
    proveedor_transaccion_id = models.CharField(max_length=150, unique=True, null=True, blank=True)
    comprobante_url = models.TextField(null=True, blank=True)
    creado_en = models.DateTimeField(default=timezone.now)
    confirmado_en = models.DateTimeField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"mimercadoplus"."pagos"'

class Entrega(models.Model):
    id = models.BigAutoField(primary_key=True)
    pedido = models.ForeignKey('Pedido', on_delete=models.DO_NOTHING, db_column="pedido_id", related_name="+")
    mercado = models.ForeignKey('Mercado', on_delete=models.DO_NOTHING, db_column="mercado_id", related_name="+")
    repartidor_mercado = models.ForeignKey('RepartidorMercado', on_delete=models.DO_NOTHING, db_column="repartidor_mercado_id", related_name="+")
    estado = models.CharField(max_length=20, default='asignada')
    asignada_en = models.DateTimeField(default=timezone.now)
    aceptada_en = models.DateTimeField(null=True, blank=True)
    salida_en = models.DateTimeField(null=True, blank=True)
    entregada_en = models.DateTimeField(null=True, blank=True)
    llegada_estimada = models.DateTimeField(null=True, blank=True)
    codigo_entrega_hash = models.TextField(null=True, blank=True)
    codigo_validado_en = models.DateTimeField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"mimercadoplus"."entregas"'

class EntregaParada(models.Model):
    id = models.BigAutoField(primary_key=True)
    entrega = models.ForeignKey('Entrega', on_delete=models.DO_NOTHING, db_column="entrega_id", related_name="+")
    pedido = models.ForeignKey('Pedido', on_delete=models.DO_NOTHING, db_column="pedido_id", related_name="+")
    pedido_puesto = models.ForeignKey('PedidoPuesto', on_delete=models.DO_NOTHING, db_column="pedido_puesto_id", related_name="+")
    orden = models.SmallIntegerField()
    recogido_en = models.DateTimeField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"mimercadoplus"."entrega_paradas"'

class HistorialEstado(models.Model):
    id = models.BigAutoField(primary_key=True)
    pedido = models.ForeignKey('Pedido', on_delete=models.DO_NOTHING, db_column="pedido_id", related_name="+")
    pedido_puesto = models.ForeignKey('PedidoPuesto', on_delete=models.DO_NOTHING, db_column="pedido_puesto_id", related_name="+", null=True, blank=True)
    estado = models.CharField(max_length=30)
    observacion = models.TextField(null=True, blank=True)
    actor = models.ForeignKey('Usuario', on_delete=models.DO_NOTHING, db_column="actor_id", related_name="+", null=True, blank=True)
    creado_en = models.DateTimeField(default=timezone.now)

    class Meta:
        managed = False
        db_table = '"mimercadoplus"."historial_estados"'

class Mensaje(models.Model):
    id = models.BigAutoField(primary_key=True)
    pedido = models.ForeignKey('Pedido', on_delete=models.DO_NOTHING, db_column="pedido_id", related_name="+")
    remitente = models.ForeignKey('Usuario', on_delete=models.DO_NOTHING, db_column="remitente_id", related_name="+")
    destinatario = models.ForeignKey('Usuario', on_delete=models.DO_NOTHING, db_column="destinatario_id", related_name="+")
    texto = models.TextField()
    enviado_en = models.DateTimeField(default=timezone.now)
    leido_en = models.DateTimeField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"mimercadoplus"."mensajes"'

class ResenaPuesto(models.Model):
    id = models.BigAutoField(primary_key=True)
    pedido_puesto = models.OneToOneField('PedidoPuesto', on_delete=models.DO_NOTHING, db_column="pedido_puesto_id", related_name="+")
    pedido = models.ForeignKey('Pedido', on_delete=models.DO_NOTHING, db_column="pedido_id", related_name="+")
    comprador = models.ForeignKey('Usuario', on_delete=models.DO_NOTHING, db_column="comprador_id", related_name="+")
    estrellas = models.SmallIntegerField()
    comentario = models.TextField(null=True, blank=True)
    creado_en = models.DateTimeField(default=timezone.now)

    class Meta:
        managed = False
        db_table = '"mimercadoplus"."resenas_puesto"'

class ResenaRepartidor(models.Model):
    id = models.BigAutoField(primary_key=True)
    entrega = models.OneToOneField('Entrega', on_delete=models.DO_NOTHING, db_column="entrega_id", related_name="+")
    pedido = models.ForeignKey('Pedido', on_delete=models.DO_NOTHING, db_column="pedido_id", related_name="+")
    comprador = models.ForeignKey('Usuario', on_delete=models.DO_NOTHING, db_column="comprador_id", related_name="+")
    estrellas = models.SmallIntegerField()
    comentario = models.TextField(null=True, blank=True)
    creado_en = models.DateTimeField(default=timezone.now)

    class Meta:
        managed = False
        db_table = '"mimercadoplus"."resenas_repartidor"'

class SolicitudSoporte(models.Model):
    id = models.BigAutoField(primary_key=True)
    usuario = models.ForeignKey('Usuario', on_delete=models.DO_NOTHING, db_column="usuario_id", related_name="+")
    pedido = models.ForeignKey('Pedido', on_delete=models.DO_NOTHING, db_column="pedido_id", related_name="+", null=True, blank=True)
    asunto = models.CharField(max_length=150)
    descripcion = models.TextField(null=True, blank=True)
    estado = models.CharField(max_length=15, default='abierta')
    responsable = models.ForeignKey('Usuario', on_delete=models.DO_NOTHING, db_column="responsable_id", related_name="+", null=True, blank=True)
    creado_en = models.DateTimeField(default=timezone.now)
    cerrado_en = models.DateTimeField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"mimercadoplus"."solicitudes_soporte"'
