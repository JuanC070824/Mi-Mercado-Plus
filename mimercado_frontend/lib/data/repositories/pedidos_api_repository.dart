import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/config/api_config.dart';
import '../../core/state/sesion_state.dart';
import '../models/pedido.dart';
import '../models/cotizacion.dart';
import '../models/direccion.dart';
import '../models/repartidor.dart';
import 'pedido_repository.dart';
import 'pedidos_vendedor_api_repository.dart';

/// Comparte pedidos reales entre comprador, vendedor y repartidor.
class PedidosApiRepository implements PedidoRepository {
  PedidosApiRepository({http.Client? client, this.baseUrl})
    : _client = client ?? http.Client();
  static final instancia = PedidosApiRepository();
  final http.Client _client;
  final String? baseUrl;
  final _cambios = ValueNotifier<int>(0);
  final _datos = <int, Map<String, dynamic>>{};
  final _intentos = <int, String>{};
  final _parser = PedidosVendedorApiRepository();
  Map<String, dynamic> datosDe(int id) => _datos[id] ?? const {};
  @override
  ValueListenable<int> get cambios => _cambios;
  void limpiar() {
    _datos.clear();
    _intentos.clear();
  }

  Pedido leer(Map<String, dynamic> data) {
    final p = _parser.pedidoDesdeJson(data);
    _datos[p.id] = data;
    return p;
  }

  Future<dynamic> solicitar(
    String metodo,
    String ruta, {
    Map<String, dynamic>? body,
  }) async {
    final token = SesionState.token;
    if (token == null) {
      throw const PedidoException('Tu sesión venció. Vuelve a ingresar.');
    }
    try {
      final request =
          http.Request(metodo, ApiConfig.uri(ruta, baseUrlOverride: baseUrl))
            ..headers.addAll({
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            });
      if (body != null) request.body = jsonEncode(body);
      final response = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 25)),
      );
      if (response.statusCode >= 500) {
        throw const PedidoException(
          'No pudimos confirmar la operación. Actualiza antes de volver a intentarlo.',
        );
      }
      final data = jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (ruta == '/api/pagos/yape/' &&
            (data is Map && data['estado'] == 'rechazado')) {
          _intentos.remove((body?['pedido_id'] as num?)?.toInt());
        }
        throw PedidoException(
          data is Map && data['detail'] is String
              ? data['detail'] as String
              : 'No pudimos guardar el cambio. Revisa los datos.',
        );
      }
      return data;
    } on PedidoException {
      rethrow;
    } on TimeoutException {
      throw const PedidoException(
        'La respuesta está tardando. Actualiza para comprobar si el cambio se guardó.',
      );
    } catch (_) {
      throw const PedidoException(
        'No pudimos conectarnos. Revisa tu conexión e inténtalo nuevamente.',
      );
    }
  }

  Future<void> _guardar(String ruta, Map<String, dynamic> body) async {
    await solicitar('POST', ruta, body: body);
    _cambios.value++;
  }

  Future<Map<String, dynamic>> inicioRepartidor() async {
    final j = Map<String, dynamic>.from(
      await solicitar('GET', '/api/repartidor/inicio/'),
    );
    for (final p in j['ofertas'] as List? ?? []) {
      leer(Map<String, dynamic>.from(p));
    }
    if (j['en_curso'] is Map) leer(Map<String, dynamic>.from(j['en_curso']));
    for (final p in j['historial_hoy'] as List? ?? []) {
      leer(Map<String, dynamic>.from(p));
    }
    return j;
  }

  Future<void> disponibilidad(bool valor) async {
    await solicitar(
      'PATCH',
      '/api/repartidor/inicio/',
      body: {'disponible': valor},
    );
    _cambios.value++;
  }

  Future<void> solicitarMercado(
    int id,
    String movilidad,
    String placa, {
    String descripcion = '',
  }) => _guardar('/api/repartidor/mercado/', {
    'mercado_id': id,
    'movilidad': movilidad,
    'placa': placa,
    'descripcion_movilidad': descripcion,
  });
  Future<void> cambiarMovilidad(
    String movilidad,
    String placa,
    String descripcion,
  ) async {
    await solicitar(
      'PATCH',
      '/api/repartidor/mercado/',
      body: {
        'movilidad': movilidad,
        'placa': placa,
        'descripcion_movilidad': descripcion,
      },
    );
    _cambios.value++;
  }

  Future<void> accionRepartidor(int id, String accion, {int? parte}) =>
      _guardar('/api/repartidor/pedidos/$id/accion/', {
        'accion': accion,
        'pedido_puesto_id': ?parte,
      });
  Future<void> entregar(int id, String codigo, {bool efectivo = false}) =>
      _guardar('/api/repartidor/pedidos/$id/entregar/', {
        'codigo': codigo,
        'efectivo_confirmado': efectivo,
      });
  Future<Map<String, dynamic>> configuracionPago() async =>
      Map<String, dynamic>.from(
        await solicitar('GET', '/api/pagos/configuracion/'),
      );
  Future<void> pagarYape(
    int id,
    String celular,
    String codigo, {
    String? correo,
  }) async {
    final random = Random.secure();
    final clave = _intentos.putIfAbsent(
      id,
      () =>
          'pago_${id}_${DateTime.now().microsecondsSinceEpoch}_${random.nextInt(1 << 30)}',
    );
    final respuesta = await solicitar(
      'POST',
      '/api/pagos/yape/',
      body: {
        'pedido_id': id,
        'celular': celular,
        'codigo': codigo,
        'idempotencia': clave,
        if (correo?.trim().isNotEmpty ?? false) 'correo': correo!.trim(),
      },
    );
    if (respuesta['success'] != true) {
      throw const PedidoException(
        'Estamos confirmando tu pago. Actualiza el pedido antes de volver a pagar.',
      );
    }
    _intentos.remove(id);
    _cambios.value++;
  }

  @override
  Future<List<Pedido>> pedidosCliente(String celular) async {
    final data = await solicitar('GET', '/api/comprador/pedidos/');
    return [for (final j in data as List) leer(Map<String, dynamic>.from(j))];
  }

  @override
  Future<Pedido?> pedidoActivoCliente(String celular) async =>
      (await pedidosCliente(celular)).where((p) => p.estado.activo).firstOrNull;
  @override
  Future<Pedido?> pedidoParaCalificar(String celular) async =>
      (await pedidosCliente(
        celular,
      )).where((p) => datosDe(p.id)['pendiente_calificar'] == true).firstOrNull;
  @override
  Future<void> aceptarCotizacion(int id) async {
    if (!_datos.containsKey(id)) await pedidosCliente('');
    final quote = _datos[id]?['cotizacion'];
    if (quote is! Map || quote['id'] is! num) {
      throw const PedidoException(
        'Actualiza el pedido para revisar el precio final.',
      );
    }
    await _guardar('/api/pedidos/$id/cotizaciones/${quote['id']}/aceptar/', {});
  }

  @override
  Future<void> calificar(
    int id,
    Map<int, int> estrellas,
    int repartidor,
  ) async {
    final p = leer(_datos[id]!);
    await _guardar('/api/comprador/pedidos/$id/calificar/', {
      'puestos': {
        for (final parte in p.puestosActivos)
          '${parte.id}': estrellas[parte.puesto.id],
      },
      'repartidor': repartidor,
    });
  }

  @override
  Future<Repartidor?> repartidorDe(int id) async {
    final r = _datos[id]?['repartidor'];
    if (r is! Map) return null;
    return Repartidor(
      nombre: r['nombre'].toString(),
      celular: r['celular'].toString(),
      mercadoId: (r['mercado_id'] as num).toInt(),
      movilidad: Movilidad.desdeCodigo(r['movilidad']?.toString()),
      placa: r['placa']?.toString(),
      calificacion: 0,
    );
  }

  @override
  Future<List<Pedido>> pedidosParaRepartidor(int mercadoId) async {
    final j = await inicioRepartidor();
    return [
      for (final p in j['ofertas'] as List? ?? [])
        leer(Map<String, dynamic>.from(p)),
    ];
  }

  @override
  Future<Pedido?> entregaEnCurso(String celular) async {
    final j = await inicioRepartidor();
    return j['en_curso'] is Map
        ? leer(Map<String, dynamic>.from(j['en_curso']))
        : null;
  }

  @override
  Future<List<Pedido>> entregasDeHoy(String celular) async {
    final j = await inicioRepartidor();
    return [
      for (final p in j['historial_hoy'] as List? ?? [])
        leer(Map<String, dynamic>.from(p)),
    ];
  }

  @override
  Future<void> aceptarEntrega(int id, String celular) =>
      _guardar('/api/repartidor/pedidos/$id/aceptar/', {});
  @override
  Future<void> marcarRecogido(int parte) async {
    final p = _datos.values.firstWhere(
      (p) => (p['puestos'] as List).any((x) => x['id'] == parte),
    );
    await accionRepartidor((p['id'] as num).toInt(), 'recoger', parte: parte);
  }

  @override
  Future<bool> salirAEntregar(int id) async {
    await accionRepartidor(id, 'salir');
    return true;
  }

  @override
  Future<void> avisarLlegada(int id) => accionRepartidor(id, 'llegue');
  @override
  Future<bool> validarCodigoEntrega(int id, String codigo) async {
    await entregar(id, codigo);
    return true;
  }

  @override
  Future<Pedido> crearPedido({
    required String clienteNombre,
    required String clienteCelular,
    required List<SolicitudPuesto> puestos,
    required Direccion direccion,
    required MetodoPago metodo,
    DateTime? programadoPara,
  }) async {
    if (direccion.id == null) {
      throw const PedidoException('Guarda tu dirección antes de pedir.');
    }
    final data = await solicitar(
      'POST',
      '/api/pedidos/',
      body: {'direccion_id': direccion.id, 'metodo_pago': metodo.codigoBd},
    );
    return (await pedidosCliente(
      clienteCelular,
    )).firstWhere((p) => p.id == data['id']);
  }

  PedidosVendedorApiRepository get _vendedor =>
      PedidosVendedorApiRepository.instancia;
  @override
  Future<List<Pedido>> pedidosDePuesto(int id) => _vendedor.pedidosDePuesto(id);
  @override
  Future<void> aceptarSubpedido(int id) => _vendedor.aceptarSubpedido(id);
  @override
  Future<void> rechazarSubpedido(int id, String motivo) =>
      _vendedor.rechazarSubpedido(id, motivo);
  @override
  Future<void> marcarDisponibilidad(int id, Disponibilidad d) =>
      _vendedor.marcarDisponibilidad(id, d);
  @override
  Future<void> enviarPrecioFinal(
    int id,
    List<CotizacionDetalle> detalles, {
    String? nota,
  }) => _vendedor.enviarPrecioFinal(id, detalles, nota: nota);
  @override
  Future<void> marcarListo(int id) => _vendedor.marcarListo(id);
  @override
  Future<void> entregarARepartidor(int id) => _vendedor.entregarARepartidor(id);
}

PedidoRepository get pedidosApp => ApiConfig.configurada
    ? PedidosApiRepository.instancia
    : PedidoRepositoryMock.instancia;
