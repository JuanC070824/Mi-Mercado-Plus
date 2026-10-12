import 'cotizacion.dart';
import 'producto.dart';
import 'puesto.dart';

/// Estado del pedido completo (lo que ve el cliente arriba).
enum EstadoPedido {
  pendiente('Esperando a los caseros', 'pendiente'),
  enPreparacion('En preparación', 'en_preparacion'),
  esperandoConfirmacion('Confirma el precio final', 'esperando_confirmacion'),
  listoParaRecojo('Listo para recoger', 'listo_para_recojo'),
  enRecojo('Recogiendo en el mercado', 'en_recojo'),
  enCamino('En camino', 'en_camino'),
  entregado('Entregado', 'entregado'),
  cancelado('Cancelado', 'cancelado');

  const EstadoPedido(this.etiqueta, this.codigoBd);
  final String etiqueta;
  final String codigoBd;

  bool get activo => this != entregado && this != cancelado;
}

/// Estado de la parte del pedido que le toca a UN puesto.
enum EstadoPedidoPuesto {
  pendiente('Nuevo pedido', 'pendiente'),
  aceptado('Aceptado', 'aceptado'),
  pesando('Pesando…', 'pesando'),
  pesado('Ya pesó', 'pesado'),
  enPreparacion('Empaquetando', 'en_preparacion'),
  listo('Listo para recoger', 'listo'),
  recogido('Recogido', 'recogido'),
  rechazado('Rechazado', 'rechazado'),
  cancelado('Cancelado', 'cancelado');

  const EstadoPedidoPuesto(this.etiqueta, this.codigoBd);
  final String etiqueta;
  final String codigoBd;

  /// Rechazado o cancelado: ya no cuenta para el pedido.
  bool get descartado => this == rechazado || this == cancelado;
}

enum Disponibilidad {
  pendiente('Por revisar', 'pendiente'),
  disponible('Lo tengo', 'disponible'),
  sinStock('Sin stock', 'sin_stock'),
  reemplazo('Ofrezco otro', 'reemplazo');

  const Disponibilidad(this.etiqueta, this.codigoBd);
  final String etiqueta;
  final String codigoBd;
}

enum MetodoPago {
  efectivo('Efectivo', 'efectivo'),
  yape('Yape', 'yape'),
  plin('Plin', 'plin');

  const MetodoPago(this.etiqueta, this.codigoBd);
  final String etiqueta;
  final String codigoBd;
}

enum MotivoRechazo {
  faltaStock('No tengo los productos'),
  cerrando('Estoy por cerrar'),
  muchosPedidos('Tengo muchos pedidos');

  const MotivoRechazo(this.etiqueta);
  final String etiqueta;
}

class PedidoDetalle {
  const PedidoDetalle({
    required this.id,
    this.productoId,
    required this.nombre,
    required this.unidad,
    required this.cantidadSolicitada,
    required this.precioEstimadoUnitario,
    this.disponibilidad = Disponibilidad.pendiente,
  });

  final int id;
  final int? productoId;
  final String nombre;
  final UnidadMedida unidad;
  final double cantidadSolicitada;
  final double precioEstimadoUnitario;
  final Disponibilidad disponibilidad;

  double get subtotalEstimado =>
      redondear2(cantidadSolicitada * precioEstimadoUnitario);

  PedidoDetalle copyWith({Disponibilidad? disponibilidad}) => PedidoDetalle(
        id: id,
        productoId: productoId,
        nombre: nombre,
        unidad: unidad,
        cantidadSolicitada: cantidadSolicitada,
        precioEstimadoUnitario: precioEstimadoUnitario,
        disponibilidad: disponibilidad ?? this.disponibilidad,
      );
}

class PedidoPuesto {
  const PedidoPuesto({
    required this.id,
    required this.puesto,
    required this.codigoBolsa,
    required this.estado,
    required this.detalles,
    this.listaMandado,
    this.motivoRechazo,
    required this.parada,
  });

  final int id;
  final Puesto puesto;
  final String codigoBolsa; // ej. 345-A-1
  final EstadoPedidoPuesto estado;
  final List<PedidoDetalle> detalles;
  final String? listaMandado;
  final String? motivoRechazo;
  final int parada; // orden de recojo del repartidor (1, 2, …)

  double get subtotalEstimado =>
      redondear2(detalles.fold(0.0, (s, d) => s + d.subtotalEstimado));

  PedidoPuesto copyWith({
    EstadoPedidoPuesto? estado,
    List<PedidoDetalle>? detalles,
    String? motivoRechazo,
  }) =>
      PedidoPuesto(
        id: id,
        puesto: puesto,
        codigoBolsa: codigoBolsa,
        estado: estado ?? this.estado,
        detalles: detalles ?? this.detalles,
        listaMandado: listaMandado,
        motivoRechazo: motivoRechazo ?? this.motivoRechazo,
        parada: parada,
      );
}

class EventoEstado {
  const EventoEstado({required this.hora, required this.texto});

  final DateTime hora;
  final String texto;
}

class Pedido {
  const Pedido({
    required this.id,
    required this.codigo,
    required this.codigoCorto,
    required this.clienteNombre,
    required this.clienteCelular,
    required this.mercadoId,
    required this.estado,
    required this.metodoPago,
    required this.direccion,
    this.referencia,
    required this.puestos,
    required this.costoEnvio,
    required this.historial,
    required this.codigoEntrega,
    this.cotizacion,
    required this.creadoEn,
    this.programadoPara,
  });

  final int id;
  final String codigo; // ej. PED-000345
  final String codigoCorto; // ej. 345-A
  final String clienteNombre;
  final String clienteCelular;
  final int mercadoId;
  final EstadoPedido estado;
  final MetodoPago metodoPago;
  final String direccion;
  final String? referencia;
  final List<PedidoPuesto> puestos;
  final double costoEnvio;
  final List<EventoEstado> historial;
  final String codigoEntrega; // 4 dígitos que el cliente le dicta al repartidor
  final Cotizacion? cotizacion;
  final DateTime creadoEn;
  final DateTime? programadoPara; // null = lo antes posible

  /// Puestos que siguen en el pedido (sin rechazados ni cancelados).
  List<PedidoPuesto> get puestosActivos =>
      puestos.where((p) => !p.estado.descartado).toList();

  double get totalProductosEstimado =>
      redondear2(puestosActivos.fold(0.0, (s, p) => s + p.subtotalEstimado));
  double get totalEstimado => redondear2(totalProductosEstimado + costoEnvio);

  PedidoPuesto? puestoPorId(int pedidoPuestoId) {
    for (final p in puestos) {
      if (p.id == pedidoPuestoId) return p;
    }
    return null;
  }

  /// La parte del pedido que le toca a un puesto (para las pantallas del casero).
  PedidoPuesto? parteDePuesto(int puestoId) {
    for (final p in puestos) {
      if (p.puesto.id == puestoId) return p;
    }
    return null;
  }

  Pedido copyWith({
    EstadoPedido? estado,
    List<PedidoPuesto>? puestos,
    List<EventoEstado>? historial,
    Cotizacion? cotizacion,
  }) =>
      Pedido(
        id: id,
        codigo: codigo,
        codigoCorto: codigoCorto,
        clienteNombre: clienteNombre,
        clienteCelular: clienteCelular,
        mercadoId: mercadoId,
        estado: estado ?? this.estado,
        metodoPago: metodoPago,
        direccion: direccion,
        referencia: referencia,
        puestos: puestos ?? this.puestos,
        costoEnvio: costoEnvio,
        historial: historial ?? this.historial,
        codigoEntrega: codigoEntrega,
        cotizacion: cotizacion ?? this.cotizacion,
        creadoEn: creadoEn,
        programadoPara: programadoPara,
      );
}
