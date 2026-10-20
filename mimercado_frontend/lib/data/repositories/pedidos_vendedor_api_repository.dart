import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/state/sesion_state.dart';
import '../models/cotizacion.dart';
import '../models/pedido.dart';
import '../models/puesto.dart';
import 'catalogo_api_repository.dart';
import 'pedido_repository.dart';

class PedidosVendedorApiRepository {
  PedidosVendedorApiRepository({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl;
  static final instancia = PedidosVendedorApiRepository();
  final http.Client _client;
  final String? _baseUrl;
  final ValueNotifier<int> _cambios = ValueNotifier(0);
  ValueListenable<int> get cambios => _cambios;

  Future<List<Pedido>> pedidosDePuesto(int puestoId) async {
    final data = await _enviar('GET', '/api/vendedor/pedidos/');
    if (data is! List) {
      throw const PedidoException('El servidor devolvió pedidos inválidos.');
    }
    return [
      for (final raw in data)
        if (raw is Map<String, dynamic>) _pedido(raw),
    ];
  }

  Future<void> aceptarSubpedido(int id) => _accion(id, 'aceptar');
  Future<void> rechazarSubpedido(int id, String motivo) =>
      _accion(id, 'rechazar', motivo: motivo);
  Future<void> marcarListo(int id) => _accion(id, 'listo');
  Future<void> entregarARepartidor(int id) => _accion(id, 'entregar');
  Future<void> marcarDisponibilidad(int id, Disponibilidad d) async {
    await _enviar(
      'PATCH',
      '/api/vendedor/detalles/$id/',
      body: {'disponibilidad': d.codigoBd},
    );
    _notificar();
  }

  Future<void> enviarPrecioFinal(
    int id,
    List<CotizacionDetalle> detalles, {
    String? nota,
  }) async {
    await _enviar(
      'POST',
      '/api/vendedor/pedidos/$id/cotizacion/',
      body: {
        'nota': nota ?? '',
        'detalles': [
          for (final d in detalles)
            {
              'pedido_detalle_id': d.pedidoDetalleId,
              'nombre_final': d.nombreFinal,
              'cantidad_real': d.cantidadReal,
              'precio_unitario': d.precioUnitario,
            },
        ],
      },
    );
    _notificar();
  }

  Future<void> _accion(int id, String accion, {String? motivo}) async {
    await _enviar(
      'PATCH',
      '/api/vendedor/pedidos/$id/accion/',
      body: {'accion': accion, 'motivo': ?motivo},
    );
    _notificar();
  }

  void _notificar() => _cambios.value++;

  Pedido _pedido(Map<String, dynamic> j) {
    final partes = <PedidoPuesto>[];
    for (final raw in (j['puestos'] as List? ?? const [])) {
      if (raw is! Map<String, dynamic>) continue;
      final pj = raw['puesto'] as Map<String, dynamic>;
      final puesto = Puesto(
        id: (pj['id'] as num).toInt(),
        mercadoId: (pj['mercado_id'] as num).toInt(),
        nombre: pj['nombre'].toString(),
        casero: pj['casero']?.toString() ?? 'Casero',
        categoria: _categoria(pj['categoria']?.toString()),
        calificacion: ((pj['calificacion'] as num?) ?? 0).toDouble(),
        resenas: ((pj['resenas'] as num?) ?? 0).toInt(),
        abierto: pj['abierto'] == true,
      );
      final detalles = <PedidoDetalle>[
        for (final d in (raw['detalles'] as List? ?? const []))
          if (d is Map<String, dynamic>)
            PedidoDetalle(
              id: (d['id'] as num).toInt(),
              productoId: (d['producto_id'] as num?)?.toInt(),
              nombre: d['nombre'].toString(),
              unidad: CatalogoApiRepository.unidadDesdeCodigo(
                d['unidad']?.toString(),
              ),
              cantidadSolicitada: double.parse(d['cantidad'].toString()),
              precioEstimadoUnitario:
                  ((d['precio_estimado_centavos'] as num?) ?? 0).toDouble() /
                  100,
              disponibilidad: _disponibilidad(d['disponibilidad']?.toString()),
            ),
      ];
      partes.add(
        PedidoPuesto(
          id: (raw['id'] as num).toInt(),
          puesto: puesto,
          codigoBolsa: raw['codigo_bolsa'].toString(),
          estado: _estadoPuesto(raw['estado'].toString()),
          detalles: detalles,
          listaMandado: raw['lista_mandado']?.toString(),
          motivoRechazo: raw['motivo_rechazo']?.toString(),
          parada: ((raw['parada'] as num?) ?? 1).toInt(),
        ),
      );
    }
    return Pedido(
      id: (j['id'] as num).toInt(),
      codigo: j['codigo'].toString(),
      codigoCorto: j['codigo_corto'].toString(),
      clienteNombre: j['cliente_nombre'].toString(),
      clienteCelular: j['cliente_celular'].toString(),
      mercadoId: (j['mercado_id'] as num).toInt(),
      estado: _estadoPedido(j['estado'].toString()),
      metodoPago: _metodo(j['metodo_pago'].toString()),
      direccion: j['direccion'].toString(),
      referencia: j['referencia']?.toString(),
      puestos: partes,
      costoEnvio: ((j['costo_envio_centavos'] as num?) ?? 0).toDouble() / 100,
      historial: [
        for (final h in (j['historial'] as List? ?? const []))
          if (h is Map<String, dynamic>)
            EventoEstado(
              hora: DateTime.parse(h['hora'].toString()),
              texto: h['texto'].toString(),
            ),
      ],
      codigoEntrega: j['codigo_entrega']?.toString() ?? '',
      cotizacion: _cotizacion(j['cotizacion']),
      creadoEn: DateTime.parse(j['creado_en'].toString()),
      programadoPara: j['programado_para'] == null
          ? null
          : DateTime.tryParse(j['programado_para'].toString()),
    );
  }

  Cotizacion? _cotizacion(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final grupos = <CotizacionPuesto>[];
    for (final g in (raw['puestos'] as List? ?? const [])) {
      if (g is! Map<String, dynamic>) continue;
      final detalles = <CotizacionDetalle>[];
      for (final d in (g['detalles'] as List? ?? const [])) {
        if (d is! Map<String, dynamic>) continue;
        detalles.add(
          CotizacionDetalle(
            pedidoDetalleId: (d['pedido_detalle_id'] as num).toInt(),
            nombreFinal: d['nombre_final'].toString(),
            cantidadReal: double.parse(d['cantidad_real'].toString()),
            precioUnitario:
                ((d['precio_unitario_centavos'] as num?) ?? 0).toDouble() / 100,
          ),
        );
      }
      grupos.add(
        CotizacionPuesto(
          pedidoPuestoId: (g['pedido_puesto_id'] as num).toInt(),
          tasaComision: double.parse(g['tasa_comision'].toString()),
          detalles: detalles,
        ),
      );
    }
    return Cotizacion(
      version: (raw['version'] as num).toInt(),
      estado: EstadoCotizacion.values.firstWhere(
        (e) => e.codigoBd == raw['estado'],
        orElse: () => EstadoCotizacion.borrador,
      ),
      costoEnvio: ((raw['costo_envio_centavos'] as num?) ?? 0).toDouble() / 100,
      puestos: grupos,
    );
  }

  CategoriaPuesto _categoria(String? n) {
    final v = (n ?? '').toLowerCase();
    if (v.contains('carne')) return CategoriaPuesto.carnes;
    if (v.contains('pesc')) return CategoriaPuesto.pescados;
    if (v.contains('abarrot')) return CategoriaPuesto.abarrotes;
    return CategoriaPuesto.verduras;
  }

  Disponibilidad _disponibilidad(String? c) => Disponibilidad.values.firstWhere(
    (e) => e.codigoBd == c,
    orElse: () => Disponibilidad.pendiente,
  );
  EstadoPedidoPuesto _estadoPuesto(String c) =>
      EstadoPedidoPuesto.values.firstWhere(
        (e) => e.codigoBd == c,
        orElse: () => EstadoPedidoPuesto.pendiente,
      );
  EstadoPedido _estadoPedido(String c) => EstadoPedido.values.firstWhere(
    (e) => e.codigoBd == c,
    orElse: () => EstadoPedido.pendiente,
  );
  MetodoPago _metodo(String c) => MetodoPago.values.firstWhere(
    (e) => e.codigoBd == c,
    orElse: () => MetodoPago.efectivo,
  );

  Future<dynamic> _enviar(
    String metodo,
    String ruta, {
    Map<String, dynamic>? body,
  }) async {
    final token = SesionState.token;
    if (token == null) throw const PedidoException('Tu sesión venció.');
    try {
      final req =
          http.Request(metodo, ApiConfig.uri(ruta, baseUrlOverride: _baseUrl))
            ..headers.addAll({
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            });
      if (body != null) req.body = jsonEncode(body);
      final res = await http.Response.fromStream(
        await _client.send(req).timeout(const Duration(seconds: 20)),
      );
      final decoded = jsonDecode(res.body);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        final d = decoded is Map<String, dynamic>
            ? decoded
            : <String, dynamic>{};
        throw PedidoException(
          d['detail']?.toString() ??
              d.values.firstOrNull?.toString() ??
              'No pudimos actualizar el pedido.',
        );
      }
      return decoded;
    } on PedidoException {
      rethrow;
    } on TimeoutException {
      throw const PedidoException('El servidor tardó demasiado.');
    } catch (_) {
      throw const PedidoException('No pudimos conectarnos con MiMercado+.');
    }
  }
}
