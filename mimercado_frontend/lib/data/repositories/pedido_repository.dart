import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/cotizacion.dart';
import '../models/direccion.dart';
import '../models/pedido.dart';
import '../models/producto.dart';
import '../models/puesto.dart';
import '../models/repartidor.dart';

/// Error de negocio con un mensaje listo para mostrar al usuario.
class PedidoException implements Exception {
  const PedidoException(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Un producto que el cliente pide (sale de un ItemCanasta).
class SolicitudItem {
  const SolicitudItem({
    this.productoId,
    required this.nombre,
    required this.unidad,
    required this.cantidad,
    required this.precioUnitario,
  });

  final int? productoId;
  final String nombre;
  final UnidadMedida unidad;
  final double cantidad;
  final double precioUnitario; // precio estimado del catálogo
}

/// Lo que el cliente pide a UN puesto (sale de un GrupoPuesto de la canasta).
class SolicitudPuesto {
  const SolicitudPuesto({
    required this.puesto,
    required this.items,
    this.listaMandado,
  });

  final Puesto puesto;
  final List<SolicitudItem> items;
  final String? listaMandado;
}

abstract class PedidoRepository {
  /// Sube en cada cambio. Las pantallas lo escuchan para refrescarse.
  ValueListenable<int> get cambios;

  // ---- Cliente (los usa Michael) ----

  /// Crea el pedido. Todos los puestos deben ser del mismo mercado.
  Future<Pedido> crearPedido({
    required String clienteNombre,
    required String clienteCelular,
    required List<SolicitudPuesto> puestos,
    required Direccion direccion,
    required MetodoPago metodo,
    DateTime? programadoPara,
  });

  /// El pedido en curso más reciente del cliente (null si no tiene).
  Future<Pedido?> pedidoActivoCliente(String celular);

  /// Historial del cliente, del más nuevo al más antiguo.
  Future<List<Pedido>> pedidosCliente(String celular);

  Future<void> aceptarCotizacion(int pedidoId);

  Future<void> calificar(
    int pedidoId,
    Map<int, int> estrellasPorPuesto,
    int estrellasRepartidor,
  );

  // ---- Casero (los usa Purisaca) ----

  /// Pedidos donde participa el puesto, del más nuevo al más antiguo.
  /// Para ver solo su parte: `pedido.parteDePuesto(puestoId)`.
  Future<List<Pedido>> pedidosDePuesto(int puestoId);

  Future<void> aceptarSubpedido(int pedidoPuestoId);

  Future<void> rechazarSubpedido(int pedidoPuestoId, String motivo);

  Future<void> marcarDisponibilidad(int detalleId, Disponibilidad d);

  Future<void> enviarPrecioFinal(
    int pedidoPuestoId,
    List<CotizacionDetalle> detalles, {
    String? nota,
  });

  Future<void> marcarListo(int pedidoPuestoId);

  Future<void> entregarARepartidor(int pedidoPuestoId);

  // ---- Repartidor (los agrega Michael al final, en M8) ----

  /// Pedidos de su mercado con precio aceptado y sin repartidor todavía.
  Future<List<Pedido>> pedidosParaRepartidor(int mercadoId);

  /// La entrega que el repartidor tiene en curso (null si está libre).
  Future<Pedido?> entregaEnCurso(String celularRepartidor);

  /// Entregas que terminó hoy (para el resumen de R1).
  Future<List<Pedido>> entregasDeHoy(String celularRepartidor);

  /// El repartidor toma el pedido. Solo una entrega a la vez.
  Future<void> aceptarEntrega(int pedidoId, String celularRepartidor);

  /// Recoge la bolsa de un puesto (misma lógica que entregarARepartidor).
  Future<void> marcarRecogido(int pedidoPuestoId);

  /// Sale a entregar. false si falta recoger en algún puesto no rechazado.
  Future<bool> salirAEntregar(int pedidoId);

  /// "Avisar: llegué" (el cliente lo ve en su pedido).
  Future<void> avisarLlegada(int pedidoId);

  /// Valida el código de 4 dígitos y marca el pedido como entregado.
  Future<bool> validarCodigoEntrega(int pedidoId, String codigo);

  /// Repartidor asignado al pedido (null si aún no hay).
  Future<Repartidor?> repartidorDe(int pedidoId);
}

/// Simula al backend. Los datos viven en memoria y se pierden al reiniciar.
///
/// Solo el puesto 1 (Doña Rosa) tiene casero que entra a la app; los demás
/// puestos se simulan: pesan apenas llega el pedido y quedan listos cuando el
/// cliente acepta el precio final.
class PedidoRepositoryMock implements PedidoRepository {
  PedidoRepositoryMock._() {
    _sembrar();
  }
  static final PedidoRepositoryMock instancia = PedidoRepositoryMock._();

  static const double costoEnvio = 5.00;
  static const Set<int> _puestosConCasero = {1};

  final ValueNotifier<int> _cambios = ValueNotifier<int>(0);
  final Map<int, Pedido> _pedidos = {};
  final Map<int, Map<String, Object>> _calificaciones = {};
  final Random _azar = Random();

  @override
  ValueListenable<int> get cambios => _cambios;

  // ----------------------------------------------------------------- Cliente

  @override
  Future<Pedido> crearPedido({
    required String clienteNombre,
    required String clienteCelular,
    required List<SolicitudPuesto> puestos,
    required Direccion direccion,
    required MetodoPago metodo,
    DateTime? programadoPara,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final conProductos = puestos.where((p) => p.items.isNotEmpty).toList();
    if (conProductos.isEmpty) {
      throw const PedidoException('Tu canasta está vacía. Agrega productos.');
    }
    final mercadoId = conProductos.first.puesto.mercadoId;
    if (conProductos.any((p) => p.puesto.mercadoId != mercadoId)) {
      throw const PedidoException(
        'Todos los productos deben ser del mismo mercado.',
      );
    }

    // El pedido de demostración #345-A se reemplaza por el real si nadie lo tocó,
    // así el guion de la demo conserva el código 345-A y la clave 4821.
    final demo = _pedidos[345];
    final usarDemo = demo != null &&
        demo.clienteCelular == clienteCelular &&
        demo.estado.activo &&
        demo.puestos
            .where((p) => _puestosConCasero.contains(p.puesto.id))
            .every((p) => p.estado == EstadoPedidoPuesto.pendiente);

    final id = usarDemo ? 345 : _pedidos.keys.fold(0, max) + 1;
    var pedido = _construir(
      id: id,
      letra: 'A',
      clienteNombre: clienteNombre,
      clienteCelular: clienteCelular,
      mercadoId: mercadoId,
      metodo: metodo,
      direccion: direccion,
      solicitudes: conProductos,
      codigoEntrega:
          usarDemo ? '4821' : (1000 + _azar.nextInt(9000)).toString(),
      creadoEn: DateTime.now(),
      programadoPara: programadoPara,
    );
    pedido = _simularCaseros(pedido);
    _pedidos[id] = pedido;
    _notificar();
    return pedido;
  }

  @override
  Future<Pedido?> pedidoActivoCliente(String celular) async {
    await Future.delayed(const Duration(milliseconds: 300));
    for (final p in _ordenados()) {
      if (p.clienteCelular == celular && p.estado.activo) return p;
    }
    return null;
  }

  @override
  Future<List<Pedido>> pedidosCliente(String celular) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _ordenados().where((p) => p.clienteCelular == celular).toList();
  }

  @override
  Future<void> aceptarCotizacion(int pedidoId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final p = _pedido(pedidoId);
    final c = p.cotizacion;
    if (p.estado != EstadoPedido.esperandoConfirmacion ||
        c == null ||
        c.estado != EstadoCotizacion.enviada) {
      throw const PedidoException(
        'Todavía faltan caseros por pesar. Te avisamos cuando esté listo.',
      );
    }
    var nuevo = p.copyWith(
      estado: EstadoPedido.enPreparacion,
      cotizacion: c.copyWith(estado: EstadoCotizacion.aceptada),
      puestos: [
        for (final pp in p.puestos)
          if (pp.estado.descartado)
            pp
          else
            pp.copyWith(
              estado: _puestosConCasero.contains(pp.puesto.id)
                  ? EstadoPedidoPuesto.enPreparacion
                  : EstadoPedidoPuesto.listo,
            ),
      ],
    );
    nuevo = _conEvento(
      nuevo,
      '${p.clienteNombre} aceptó el precio final '
      '(S/ ${c.totalCliente.toStringAsFixed(2)})',
    );
    _guardar(_revisarListos(nuevo));
  }

  @override
  Future<void> calificar(
    int pedidoId,
    Map<int, int> estrellasPorPuesto,
    int estrellasRepartidor,
  ) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final p = _pedido(pedidoId);
    if (p.estado != EstadoPedido.entregado) {
      throw const PedidoException('Podrás calificar cuando recibas tu pedido.');
    }
    _calificaciones[pedidoId] = {
      'puestos': Map<int, int>.from(estrellasPorPuesto),
      'repartidor': estrellasRepartidor,
    };
    _guardar(_conEvento(p, 'Calificaste tu pedido. ¡Gracias!'));
  }

  // ------------------------------------------------------------------ Casero

  @override
  Future<List<Pedido>> pedidosDePuesto(int puestoId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _ordenados().where((p) => p.parteDePuesto(puestoId) != null).toList();
  }

  @override
  Future<void> aceptarSubpedido(int pedidoPuestoId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final (p, pp) = _buscarParte(pedidoPuestoId);
    _exigir(pp, {EstadoPedidoPuesto.pendiente},
        'Este pedido ya fue atendido.');
    var nuevo = _cambiarParte(
        p, pp.copyWith(estado: EstadoPedidoPuesto.aceptado));
    if (nuevo.estado == EstadoPedido.pendiente) {
      nuevo = nuevo.copyWith(estado: EstadoPedido.enPreparacion);
    }
    _guardar(_conEvento(nuevo, '${pp.puesto.nombre} aceptó tu pedido'));
  }

  @override
  Future<void> rechazarSubpedido(int pedidoPuestoId, String motivo) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final (p, pp) = _buscarParte(pedidoPuestoId);
    _exigir(
      pp,
      {
        EstadoPedidoPuesto.pendiente,
        EstadoPedidoPuesto.aceptado,
        EstadoPedidoPuesto.pesando,
      },
      'Ya no puedes rechazar este pedido.',
    );
    var nuevo = _cambiarParte(
      p,
      pp.copyWith(estado: EstadoPedidoPuesto.rechazado, motivoRechazo: motivo),
    );
    // Si ya había cotización, se quita la parte de este puesto.
    final c = nuevo.cotizacion;
    if (c != null) {
      nuevo = nuevo.copyWith(
        cotizacion: c.copyWith(
          puestos: c.puestos
              .where((cp) => cp.pedidoPuestoId != pedidoPuestoId)
              .toList(),
        ),
      );
    }
    nuevo = _conEvento(nuevo, '${pp.puesto.nombre} no pudo atender: $motivo');
    if (nuevo.puestosActivos.isEmpty) {
      nuevo = _conEvento(
        nuevo.copyWith(estado: EstadoPedido.cancelado),
        'Pedido cancelado: ningún puesto pudo atenderlo',
      );
    }
    _guardar(_revisarCotizacion(nuevo));
  }

  @override
  Future<void> marcarDisponibilidad(int detalleId, Disponibilidad d) async {
    await Future.delayed(const Duration(milliseconds: 200));
    for (final p in _pedidos.values) {
      for (final pp in p.puestos) {
        for (final det in pp.detalles) {
          if (det.id != detalleId) continue;
          _exigir(
            pp,
            {EstadoPedidoPuesto.aceptado, EstadoPedidoPuesto.pesando},
            'Primero acepta el pedido para revisar los productos.',
          );
          var nuevo = _cambiarParte(
            p,
            pp.copyWith(
              estado: EstadoPedidoPuesto.pesando,
              detalles: [
                for (final x in pp.detalles)
                  x.id == detalleId ? x.copyWith(disponibilidad: d) : x,
              ],
            ),
          );
          if (pp.estado == EstadoPedidoPuesto.aceptado) {
            nuevo = _conEvento(nuevo, '${pp.puesto.nombre} está pesando…');
          }
          _guardar(nuevo);
          return;
        }
      }
    }
    throw const PedidoException('No encontramos ese producto en el pedido.');
  }

  @override
  Future<void> enviarPrecioFinal(
    int pedidoPuestoId,
    List<CotizacionDetalle> detalles, {
    String? nota,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final (p, pp) = _buscarParte(pedidoPuestoId);
    _exigir(
      pp,
      {EstadoPedidoPuesto.aceptado, EstadoPedidoPuesto.pesando},
      'Este pedido ya tiene precio final.',
    );
    final nuevo = _conPrecioDePuesto(
      _cambiarParte(p, pp.copyWith(estado: EstadoPedidoPuesto.pesado)),
      CotizacionPuesto(
        pedidoPuestoId: pedidoPuestoId,
        detalles: detalles,
        nota: (nota == null || nota.trim().isEmpty) ? null : nota.trim(),
      ),
    );
    _guardar(_revisarCotizacion(
        _conEvento(nuevo, '${pp.puesto.nombre} ya pesó tu pedido')));
  }

  @override
  Future<void> marcarListo(int pedidoPuestoId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final (p, pp) = _buscarParte(pedidoPuestoId);
    _exigir(pp, {EstadoPedidoPuesto.enPreparacion},
        'Espera a que el cliente acepte el precio final.');
    final nuevo = _conEvento(
      _cambiarParte(p, pp.copyWith(estado: EstadoPedidoPuesto.listo)),
      '${pp.puesto.nombre} empaquetó tu pedido',
    );
    _guardar(_revisarListos(nuevo));
  }

  @override
  Future<void> entregarARepartidor(int pedidoPuestoId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _recoger(pedidoPuestoId);
  }

  // ---------------------------------------------------------------- Internos

  /// Única forma de pasar una bolsa a "recogido". La usan el casero
  /// (entregarARepartidor) y el repartidor (marcarRecogido, M8).
  /// Si la bolsa ya estaba recogida no hace nada, así no importa quién toque primero.
  void _recoger(int pedidoPuestoId) {
    final (p, pp) = _buscarParte(pedidoPuestoId);
    if (pp.estado == EstadoPedidoPuesto.recogido) return;
    _exigir(pp, {EstadoPedidoPuesto.listo},
        'Primero marca el pedido como listo.');
    var nuevo = _cambiarParte(p, pp.copyWith(estado: EstadoPedidoPuesto.recogido));
    if (nuevo.estado == EstadoPedido.listoParaRecojo) {
      nuevo = nuevo.copyWith(estado: EstadoPedido.enRecojo);
    }
    _guardar(_conEvento(
      nuevo,
      'El repartidor recogió la bolsa ${pp.codigoBolsa} de ${pp.puesto.nombre}',
    ));
  }

  void _notificar() => _cambios.value++;

  void _guardar(Pedido p) {
    _pedidos[p.id] = p;
    _notificar();
  }

  List<Pedido> _ordenados() =>
      _pedidos.values.toList()..sort((a, b) => b.creadoEn.compareTo(a.creadoEn));

  Pedido _pedido(int id) {
    final p = _pedidos[id];
    if (p == null) throw const PedidoException('No encontramos ese pedido.');
    return p;
  }

  (Pedido, PedidoPuesto) _buscarParte(int pedidoPuestoId) {
    for (final p in _pedidos.values) {
      final pp = p.puestoPorId(pedidoPuestoId);
      if (pp != null) return (p, pp);
    }
    throw const PedidoException('No encontramos ese pedido.');
  }

  void _exigir(
    PedidoPuesto pp,
    Set<EstadoPedidoPuesto> permitidos,
    String mensaje,
  ) {
    if (!permitidos.contains(pp.estado)) throw PedidoException(mensaje);
  }

  Pedido _cambiarParte(Pedido p, PedidoPuesto nueva) => p.copyWith(
        puestos: [for (final x in p.puestos) x.id == nueva.id ? nueva : x],
      );

  Pedido _conEvento(Pedido p, String texto, [DateTime? hora]) => p.copyWith(
        historial: [
          ...p.historial,
          EventoEstado(hora: hora ?? DateTime.now(), texto: texto),
        ],
      );

  /// Agrega (o reemplaza) el precio final de un puesto en la cotización.
  Pedido _conPrecioDePuesto(Pedido p, CotizacionPuesto cp) {
    final c = p.cotizacion ??
        Cotizacion(
          version: 1,
          estado: EstadoCotizacion.borrador,
          costoEnvio: p.costoEnvio,
          puestos: const [],
        );
    return p.copyWith(
      cotizacion: c.copyWith(puestos: [
        ...c.puestos.where((x) => x.pedidoPuestoId != cp.pedidoPuestoId),
        cp,
      ]),
    );
  }

  /// Cuando todos los puestos activos pesaron, el cliente recibe el precio final.
  Pedido _revisarCotizacion(Pedido p) {
    final c = p.cotizacion;
    if (c == null ||
        c.estado != EstadoCotizacion.borrador ||
        !p.estado.activo ||
        p.puestosActivos.isEmpty ||
        p.puestosActivos.any((pp) => pp.estado != EstadoPedidoPuesto.pesado)) {
      return p;
    }
    return _conEvento(
      p.copyWith(
        estado: EstadoPedido.esperandoConfirmacion,
        cotizacion: c.copyWith(estado: EstadoCotizacion.enviada),
      ),
      'Precio final listo: S/ ${c.totalCliente.toStringAsFixed(2)}',
    );
  }

  /// Cuando todos los puestos activos empaquetaron, el pedido espera al repartidor.
  Pedido _revisarListos(Pedido p) {
    if (p.estado != EstadoPedido.enPreparacion ||
        p.puestosActivos.any((pp) =>
            pp.estado != EstadoPedidoPuesto.listo &&
            pp.estado != EstadoPedidoPuesto.recogido)) {
      return p;
    }
    return _conEvento(
      p.copyWith(estado: EstadoPedido.listoParaRecojo),
      'Tu pedido está listo para recoger',
    );
  }

  /// Los puestos sin casero en la demo aceptan y pesan al instante,
  /// con la misma cantidad y precio que pidió el cliente.
  Pedido _simularCaseros(Pedido p) {
    var nuevo = p;
    for (final pp in p.puestos) {
      if (_puestosConCasero.contains(pp.puesto.id)) continue;
      final detalles = [
        for (final d in pp.detalles)
          d.copyWith(disponibilidad: Disponibilidad.disponible),
      ];
      nuevo = _cambiarParte(
        nuevo,
        pp.copyWith(estado: EstadoPedidoPuesto.pesado, detalles: detalles),
      );
      nuevo = _conPrecioDePuesto(nuevo, _precioIgualAlEstimado(pp));
      nuevo = _conEvento(nuevo, '${pp.puesto.nombre} ya pesó tu pedido');
    }
    if (nuevo.estado == EstadoPedido.pendiente &&
        nuevo.puestos.any((pp) => pp.estado != EstadoPedidoPuesto.pendiente)) {
      nuevo = nuevo.copyWith(estado: EstadoPedido.enPreparacion);
    }
    return _revisarCotizacion(nuevo);
  }

  CotizacionPuesto _precioIgualAlEstimado(PedidoPuesto pp) => CotizacionPuesto(
        pedidoPuestoId: pp.id,
        detalles: [
          for (final d in pp.detalles)
            CotizacionDetalle(
              pedidoDetalleId: d.id,
              nombreFinal: d.nombre,
              cantidadReal: d.cantidadSolicitada,
              precioUnitario: d.precioEstimadoUnitario,
            ),
        ],
      );

  /// IDs derivados del pedido: puesto 345 → 3451, 3452; detalle → 34501, 34502…
  Pedido _construir({
    required int id,
    required String letra,
    required String clienteNombre,
    required String clienteCelular,
    required int mercadoId,
    required MetodoPago metodo,
    required Direccion direccion,
    required List<SolicitudPuesto> solicitudes,
    required String codigoEntrega,
    required DateTime creadoEn,
    DateTime? programadoPara,
  }) {
    final corto = '$id-$letra';
    var n = 0;
    final puestos = <PedidoPuesto>[];
    for (var i = 0; i < solicitudes.length; i++) {
      final s = solicitudes[i];
      puestos.add(PedidoPuesto(
        id: id * 10 + i + 1,
        puesto: s.puesto,
        codigoBolsa: '$corto-${i + 1}',
        estado: EstadoPedidoPuesto.pendiente,
        parada: i + 1,
        listaMandado: (s.listaMandado == null || s.listaMandado!.trim().isEmpty)
            ? null
            : s.listaMandado!.trim(),
        detalles: [
          for (final it in s.items)
            PedidoDetalle(
              id: id * 100 + ++n,
              productoId: it.productoId,
              nombre: it.nombre,
              unidad: it.unidad,
              cantidadSolicitada: it.cantidad,
              precioEstimadoUnitario: it.precioUnitario,
            ),
        ],
      ));
    }
    return Pedido(
      id: id,
      codigo: 'PED-${id.toString().padLeft(6, '0')}',
      codigoCorto: corto,
      clienteNombre: clienteNombre,
      clienteCelular: clienteCelular,
      mercadoId: mercadoId,
      estado: EstadoPedido.pendiente,
      metodoPago: metodo,
      direccion: direccion.direccion,
      referencia: direccion.referencia,
      puestos: puestos,
      costoEnvio: costoEnvio,
      codigoEntrega: codigoEntrega,
      creadoEn: creadoEn,
      programadoPara: programadoPara,
      historial: [EventoEstado(hora: creadoEn, texto: 'Pedido enviado')],
    );
  }

  // ----------------------------------------------------------- Datos semilla

  // Copia de CatalogoRepositoryMock (mismos IDs).
  static const _rosa = Puesto(id: 1, mercadoId: 1, nombre: 'Doña Rosa Verdulería', casero: 'Rosa Quispe', categoria: CategoriaPuesto.verduras, calificacion: 4.9, resenas: 5);
  static const _mariscos = Puesto(id: 2, mercadoId: 1, nombre: 'Mariscos Enrique', casero: 'Samuel Enrique', categoria: CategoriaPuesto.pescados, calificacion: 4.6, resenas: 9);
  static const _carniceria = Puesto(id: 3, mercadoId: 1, nombre: 'Carnicería Huancayo', casero: 'Julio Vega', categoria: CategoriaPuesto.carnes, calificacion: 3.9, resenas: 5);
  static const _carmen = Puesto(id: 5, mercadoId: 1, nombre: 'Abarrotes Doña Carmen', casero: 'Carmen Flores', categoria: CategoriaPuesto.abarrotes, calificacion: 4.8, resenas: 21);

  // Precios estimados. Deben coincidir con los productos de M1 (Michael).
  static const _tomate = ('Tomate', UnidadMedida.kg, 4.00);
  static const _papa = ('Papa amarilla', UnidadMedida.kg, 3.50);
  static const _limon = ('Limón', UnidadMedida.kg, 8.00);
  static const _cebolla = ('Cebolla roja', UnidadMedida.kg, 3.00);
  static const _culantro = ('Culantro', UnidadMedida.atado, 1.00);
  static const _pollo = ('Pollo entero', UnidadMedida.kg, 10.00);
  static const _molida = ('Carne molida', UnidadMedida.kg, 22.00);
  static const _bistec = ('Bistec', UnidadMedida.kg, 28.00);
  static const _arroz = ('Arroz extra', UnidadMedida.kg, 4.20);
  static const _aceite = ('Aceite vegetal', UnidadMedida.litro, 9.50);
  static const _bonito = ('Bonito', UnidadMedida.kg, 14.00);

  static const _dirMaria = Direccion(
    direccion: 'Av. Las Flores 245, San Isidro',
    referencia: 'Cerca a la juguería',
  );

  static SolicitudPuesto _pide(
    Puesto puesto,
    List<((String, UnidadMedida, double), double)> items, [
    String? listaMandado,
  ]) =>
      SolicitudPuesto(
        puesto: puesto,
        listaMandado: listaMandado,
        items: [
          for (final (prod, cantidad) in items)
            SolicitudItem(
              nombre: prod.$1,
              unidad: prod.$2,
              precioUnitario: prod.$3,
              cantidad: cantidad,
            ),
        ],
      );

  void _sembrar() {
    final hoy = DateTime.now();
    DateTime hace(int dias, int hora, int minuto) =>
        DateTime(hoy.year, hoy.month, hoy.day - dias, hora, minuto);

    // #345-A — pedido de la demo (docs/05). Carnicería Huancayo ya pesó;
    // Doña Rosa lo tiene como "¡Nuevo pedido!". Estimado S/ 46.00.
    final demo = _construir(
      id: 345,
      letra: 'A',
      clienteNombre: 'María Esperanza',
      clienteCelular: '987654321',
      mercadoId: 1,
      metodo: MetodoPago.yape,
      direccion: _dirMaria,
      codigoEntrega: '4821',
      creadoEn: hoy.subtract(const Duration(minutes: 5)),
      solicitudes: [
        _pide(_rosa, [(_tomate, 1), (_papa, 2), (_limon, 0.5)],
            'Tomates no tan maduros, son para ensalada.'),
        _pide(_carniceria, [(_pollo, 1.5), (_molida, 0.5)],
            'El pollo en presas, sin piel por favor.'),
      ],
    );
    _pedidos[345] = _simularCaseros(demo);

    // #344-B a #336-A — historial para las listas (V6, C9 y resumen del día).
    _historico(344, 'B', 'Jorge Ramírez', '976543210', hace(0, 10, 20),
        EstadoPedido.enPreparacion, [
      _pide(_rosa, [(_cebolla, 1), (_culantro, 2)]),
      _pide(_carmen, [(_arroz, 5), (_aceite, 1)]),
    ]);
    _historico(343, 'A', 'Lucía Torres', '965432109', hace(0, 9, 10),
        EstadoPedido.entregado, [
      _pide(_rosa, [(_tomate, 2), (_papa, 3), (_limon, 1)]),
    ]);
    _historico(342, 'C', 'María Esperanza', '987654321', hace(1, 18, 5),
        EstadoPedido.entregado, [
      _pide(_rosa, [(_papa, 2), (_cebolla, 1)]),
      _pide(_carniceria, [(_bistec, 1)]),
    ]);
    _historico(341, 'A', 'Carmen Ríos', '954321098', hace(0, 8, 30),
        EstadoPedido.entregado, [
      _pide(_rosa, [(_limon, 1), (_culantro, 1)]),
    ]);
    _historico(340, 'B', 'María Esperanza', '987654321', hace(2, 12, 40),
        EstadoPedido.cancelado, [
      _pide(_mariscos, [(_bonito, 1)]),
    ], rechazados: {_mariscos.id: MotivoRechazo.cerrando});
    _historico(339, 'A', 'Pedro Salas', '943210987', hace(1, 11, 15),
        EstadoPedido.entregado, [
      _pide(_rosa, [(_tomate, 1.5), (_cebolla, 2)]),
    ]);
    _historico(338, 'A', 'María Esperanza', '987654321', hace(3, 10, 0),
        EstadoPedido.entregado, [
      _pide(_rosa, [(_tomate, 1), (_limon, 0.5)]),
      _pide(_carmen, [(_arroz, 2)]),
    ]);
    _historico(337, 'B', 'Ana Paredes', '932109876', hace(3, 16, 50),
        EstadoPedido.entregado, [
      _pide(_carniceria, [(_pollo, 2)]),
    ]);
    _historico(336, 'A', 'Luis Mendoza', '921098765', hace(4, 9, 45),
        EstadoPedido.entregado, [
      _pide(_rosa, [(_papa, 5)]),
      _pide(_carniceria, [(_molida, 1)]),
    ], rechazados: {_rosa.id: MotivoRechazo.faltaStock});
  }

  /// Pedido ya avanzado. El precio final es igual al estimado.
  void _historico(
    int id,
    String letra,
    String cliente,
    String celular,
    DateTime creadoEn,
    EstadoPedido estado,
    List<SolicitudPuesto> solicitudes, {
    Map<int, MotivoRechazo> rechazados = const {},
  }) {
    var p = _construir(
      id: id,
      letra: letra,
      clienteNombre: cliente,
      clienteCelular: celular,
      mercadoId: 1,
      metodo: id.isEven ? MetodoPago.yape : MetodoPago.efectivo,
      direccion: const Direccion(direccion: 'Jr. Los Pinos 120, Surquillo'),
      solicitudes: solicitudes,
      codigoEntrega: (1000 + id * 7 % 9000).toString(),
      creadoEn: creadoEn,
    );
    final estadoPuesto = switch (estado) {
      EstadoPedido.entregado => EstadoPedidoPuesto.recogido,
      EstadoPedido.cancelado => EstadoPedidoPuesto.cancelado,
      _ => EstadoPedidoPuesto.enPreparacion,
    };
    final cotizados = <CotizacionPuesto>[];
    p = p.copyWith(puestos: [
      for (final pp in p.puestos)
        if (rechazados.containsKey(pp.puesto.id))
          pp.copyWith(
            estado: EstadoPedidoPuesto.rechazado,
            motivoRechazo: rechazados[pp.puesto.id]!.etiqueta,
          )
        else ...[
          pp.copyWith(
            // Los puestos simulados ya empaquetaron; si no, el pedido se traba.
            estado: (estadoPuesto == EstadoPedidoPuesto.enPreparacion &&
                    !_puestosConCasero.contains(pp.puesto.id))
                ? EstadoPedidoPuesto.listo
                : estadoPuesto,
            detalles: [
              for (final d in pp.detalles)
                d.copyWith(disponibilidad: Disponibilidad.disponible),
            ],
          ),
        ],
    ]);
    for (final pp in p.puestosActivos) {
      cotizados.add(_precioIgualAlEstimado(pp));
    }
    if (cotizados.isNotEmpty) {
      p = p.copyWith(
        cotizacion: Cotizacion(
          version: 1,
          estado: EstadoCotizacion.aceptada,
          costoEnvio: p.costoEnvio,
          puestos: cotizados,
        ),
      );
    }
    final fin = creadoEn.add(const Duration(minutes: 50));
    p = p.copyWith(estado: estado);
    p = switch (estado) {
      EstadoPedido.entregado => _conEvento(p, 'Pedido entregado', fin),
      EstadoPedido.cancelado => _conEvento(p, 'Pedido cancelado', fin),
      _ => _conEvento(p, 'Precio final aceptado',
          creadoEn.add(const Duration(minutes: 15))),
    };
    _pedidos[id] = p;
  }

  // -------------------------------------------------------------- Repartidor

  static const _repartidores = {
    '923456789': Repartidor(
      nombre: 'Ernesto Guevara',
      celular: '923456789',
      mercadoId: 1,
      movilidad: Movilidad.mototaxi,
      placa: 'MT-4521',
      calificacion: 4.8,
    ),
  };

  /// Pedido → celular del repartidor que lo lleva.
  final Map<int, String> _repartidorDe = {};

  /// Pedido → hora en que se entregó (para "entregas de hoy").
  final Map<int, DateTime> _entregadoEn = {};

  bool _listoParaRepartidor(Pedido p) =>
      p.estado.activo &&
      p.cotizacion?.estado == EstadoCotizacion.aceptada &&
      !_repartidorDe.containsKey(p.id);

  @override
  Future<List<Pedido>> pedidosParaRepartidor(int mercadoId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _ordenados()
        .where((p) => p.mercadoId == mercadoId && _listoParaRepartidor(p))
        .toList();
  }

  @override
  Future<Pedido?> entregaEnCurso(String celularRepartidor) async {
    await Future.delayed(const Duration(milliseconds: 300));
    for (final p in _ordenados()) {
      if (_repartidorDe[p.id] == celularRepartidor && p.estado.activo) return p;
    }
    return null;
  }

  @override
  Future<List<Pedido>> entregasDeHoy(String celularRepartidor) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final hoy = DateTime.now();
    return [
      for (final e in _entregadoEn.entries)
        if (_repartidorDe[e.key] == celularRepartidor &&
            e.value.year == hoy.year &&
            e.value.month == hoy.month &&
            e.value.day == hoy.day)
          _pedidos[e.key]!,
    ];
  }

  @override
  Future<void> aceptarEntrega(int pedidoId, String celularRepartidor) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final r = _repartidores[celularRepartidor];
    if (r == null) throw const PedidoException('No estás autorizado en este mercado.');
    final p = _pedido(pedidoId);
    if (p.mercadoId != r.mercadoId) {
      throw const PedidoException('Este pedido es de otro mercado.');
    }
    if (_pedidos.entries.any((e) =>
        _repartidorDe[e.key] == celularRepartidor && e.value.estado.activo)) {
      throw const PedidoException('Primero termina la entrega que tienes en curso.');
    }
    if (!_listoParaRepartidor(p)) {
      throw const PedidoException('Otro repartidor ya tomó este pedido.');
    }
    _repartidorDe[pedidoId] = celularRepartidor;
    _guardar(_conEvento(p,
        '${r.nombre.split(' ').first} (${r.movilidadTexto}) va a recoger tu pedido'));
  }

  @override
  Future<void> marcarRecogido(int pedidoPuestoId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final (_, pp) = _buscarParte(pedidoPuestoId);
    if (pp.estado != EstadoPedidoPuesto.listo &&
        pp.estado != EstadoPedidoPuesto.recogido) {
      throw PedidoException(
          '${pp.puesto.nombre} aún está preparando la bolsa. Espera un momento.');
    }
    _recoger(pedidoPuestoId);
  }

  @override
  Future<bool> salirAEntregar(int pedidoId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final p = _pedido(pedidoId);
    if (p.estado == EstadoPedido.enCamino) return true;
    final faltan = p.puestosActivos.any((pp) => pp.estado != EstadoPedidoPuesto.recogido);
    if (faltan || p.cotizacion?.estado != EstadoCotizacion.aceptada) return false;
    _guardar(_conEvento(p.copyWith(estado: EstadoPedido.enCamino), 'Tu pedido va en camino'));
    return true;
  }

  @override
  Future<void> avisarLlegada(int pedidoId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _guardar(_conEvento(_pedido(pedidoId), 'El repartidor llegó a tu puerta'));
  }

  @override
  Future<bool> validarCodigoEntrega(int pedidoId, String codigo) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final p = _pedido(pedidoId);
    if (p.estado != EstadoPedido.enCamino) {
      throw const PedidoException('Primero sal a entregar el pedido.');
    }
    if (codigo.trim() != p.codigoEntrega) return false;
    _entregadoEn[pedidoId] = DateTime.now();
    _guardar(_conEvento(
      p.copyWith(estado: EstadoPedido.entregado),
      'Pedido entregado (código ${p.codigoEntrega} validado)',
    ));
    return true;
  }

  @override
  Future<Repartidor?> repartidorDe(int pedidoId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final cel = _repartidorDe[pedidoId];
    return cel == null ? null : _repartidores[cel];
  }

  /// Datos del repartidor por su celular (para R1).
  static Repartidor? repartidorPorCelular(String celular) => _repartidores[celular];
}
