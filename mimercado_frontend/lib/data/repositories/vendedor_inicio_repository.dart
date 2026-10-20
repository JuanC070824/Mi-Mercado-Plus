import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/state/sesion_state.dart';

class VendedorInicioException implements Exception {
  const VendedorInicioException(this.mensaje);
  final String mensaje;
}

class VendedorInicio {
  const VendedorInicio({
    this.puesto,
    this.atencion,
    this.pedidos = const [],
    this.resumen,
  });

  const VendedorInicio.sinPuesto()
    : puesto = null,
      atencion = null,
      pedidos = const [],
      resumen = null;

  final PuestoVendedor? puesto;
  final AtencionVendedor? atencion;
  final List<PedidoActivoVendedor> pedidos;
  final ResumenVendedor? resumen;

  bool get tienePuesto => puesto != null;
}

class PuestoVendedor {
  const PuestoVendedor({
    required this.id,
    required this.nombre,
    required this.mercado,
    required this.categoria,
    required this.abierto,
    this.numero,
    this.descripcion,
    this.fotoUrl,
  });

  final int id;
  final String nombre;
  final String mercado;
  final String categoria;
  final bool abierto;
  final String? numero;
  final String? descripcion;
  final String? fotoUrl;

  PuestoVendedor conEstado(bool valor) => PuestoVendedor(
    id: id,
    nombre: nombre,
    mercado: mercado,
    categoria: categoria,
    abierto: valor,
    numero: numero,
    descripcion: descripcion,
    fotoUrl: fotoUrl,
  );
}

class AtencionVendedor {
  const AtencionVendedor({
    required this.nuevos,
    required this.preparando,
    required this.listos,
  });
  final int nuevos;
  final int preparando;
  final int listos;
}

class PedidoActivoVendedor {
  const PedidoActivoVendedor({
    required this.id,
    required this.cliente,
    required this.productos,
    required this.estado,
    required this.creadoEn,
    this.responderAntes,
  });

  final int id;
  final String cliente;
  final int productos;
  final String estado;
  final DateTime creadoEn;
  final DateTime? responderAntes;
}

class ResumenVendedor {
  const ResumenVendedor({
    required this.ventas,
    required this.comision,
    required this.recibes,
  });
  final int ventas;
  final int comision;
  final int recibes;
}

class VendedorInicioApiRepository {
  VendedorInicioApiRepository({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl;

  static final instancia = VendedorInicioApiRepository();
  final http.Client _client;
  final String? _baseUrl;

  Future<VendedorInicio> cargar() async {
    final response = await _solicitud('GET');
    final data = _mapa(response);
    if (response.statusCode != 200) {
      throw VendedorInicioException(_mensaje(data));
    }
    if (data['tiene_puesto'] != true) return const VendedorInicio.sinPuesto();

    final puesto = _mapaValor(data['puesto']);
    final mercado = _mapaValor(puesto['mercado']);
    final atencion = _mapaValor(data['atencion']);
    final resumen = _mapaValor(data['resumen']);
    final pedidosJson = data['pedidos_activos'];
    if (pedidosJson is! List) throw const FormatException('Pedidos inválidos');

    return VendedorInicio(
      puesto: PuestoVendedor(
        id: _entero(puesto['id']),
        nombre: _texto(puesto['nombre']),
        numero: _textoOpcional(puesto['numero']),
        descripcion: _textoOpcional(puesto['descripcion']),
        fotoUrl: _textoOpcional(puesto['foto_url']),
        abierto: puesto['abierto'] == true,
        mercado: _texto(mercado['nombre']),
        categoria: _texto(puesto['categoria']),
      ),
      atencion: AtencionVendedor(
        nuevos: _entero(atencion['nuevos']),
        preparando: _entero(atencion['preparando']),
        listos: _entero(atencion['listos']),
      ),
      pedidos: pedidosJson.map((valor) {
        final pedido = _mapaValor(valor);
        return PedidoActivoVendedor(
          id: _entero(pedido['id']),
          cliente: _texto(pedido['cliente_nombre']),
          productos: _entero(pedido['cantidad_productos']),
          estado: _texto(pedido['estado']),
          creadoEn: DateTime.parse(_texto(pedido['creado_en'])),
          responderAntes: _fechaOpcional(pedido['responder_antes']),
        );
      }).toList(),
      resumen: ResumenVendedor(
        ventas: _entero(resumen['ventas_centavos']),
        comision: _entero(resumen['comision_centavos']),
        recibes: _entero(resumen['recibes_centavos']),
      ),
    );
  }

  Future<bool> cambiarAbierto(bool abierto) async {
    final response = await _solicitud('PATCH', body: {'abierto': abierto});
    final data = _mapa(response);
    if (response.statusCode != 200) {
      throw VendedorInicioException(_mensaje(data));
    }
    return data['abierto'] == true;
  }

  Future<http.Response> _solicitud(
    String metodo, {
    Map<String, dynamic>? body,
  }) async {
    final token = SesionState.token;
    if (token == null) {
      throw const VendedorInicioException(
        'Tu sesión venció. Vuelve a iniciar sesión.',
      );
    }
    try {
      final request =
          http.Request(
              metodo,
              ApiConfig.uri('/api/vendedor/inicio/', baseUrlOverride: _baseUrl),
            )
            ..headers.addAll({
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            });
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 15));
      return await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const VendedorInicioException(
        'La carga tardó demasiado. Inténtalo nuevamente.',
      );
    } on VendedorInicioException {
      rethrow;
    } on StateError catch (error) {
      throw VendedorInicioException(error.message);
    } catch (_) {
      throw const VendedorInicioException(
        'No pudimos conectarnos con MiMercado+.',
      );
    }
  }

  static Map<String, dynamic> _mapa(http.Response response) {
    try {
      return _mapaValor(jsonDecode(response.body));
    } on FormatException {
      throw const VendedorInicioException(
        'El servidor devolvió datos inválidos.',
      );
    }
  }

  static Map<String, dynamic> _mapaValor(dynamic valor) {
    if (valor is Map<String, dynamic>) return valor;
    throw const FormatException('Se esperaba un objeto');
  }

  static int _entero(dynamic valor) {
    if (valor is num) return valor.toInt();
    throw const FormatException('Se esperaba un número');
  }

  static String _texto(dynamic valor) {
    final texto = valor?.toString().trim() ?? '';
    if (texto.isEmpty) throw const FormatException('Se esperaba texto');
    return texto;
  }

  static String? _textoOpcional(dynamic valor) {
    final texto = valor?.toString().trim();
    return texto == null || texto.isEmpty ? null : texto;
  }

  static DateTime? _fechaOpcional(dynamic valor) {
    final texto = _textoOpcional(valor);
    return texto == null ? null : DateTime.parse(texto);
  }

  static String _mensaje(Map<String, dynamic> data) =>
      data['detail']?.toString() ?? 'No pudimos cargar el inicio del vendedor.';
}
