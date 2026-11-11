import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/state/sesion_state.dart';

class AdministracionException implements Exception {
  const AdministracionException(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

/// Solicitud de un repartidor para trabajar en un mercado.
class SolicitudRepartidor {
  const SolicitudRepartidor({
    required this.id,
    required this.nombre,
    required this.celular,
    required this.mercado,
    required this.movilidad,
    this.placa,
    required this.autorizado,
    required this.entregaEnCurso,
  });
  final int id;
  final String nombre;
  final String celular;
  final String mercado;
  final String movilidad;
  final String? placa;
  final bool autorizado;
  final bool entregaEnCurso;

  factory SolicitudRepartidor.desdeJson(Map<String, dynamic> j) =>
      SolicitudRepartidor(
        id: (j['id'] as num).toInt(),
        nombre: j['nombre'].toString(),
        celular: j['celular']?.toString() ?? '',
        mercado: (j['mercado'] as Map?)?['nombre']?.toString() ?? '',
        movilidad: j['movilidad']?.toString() ?? '',
        placa: j['placa']?.toString(),
        autorizado: j['autorizado'] == true,
        entregaEnCurso: j['entrega_en_curso'] == true,
      );
}

class MercadoAdmin {
  const MercadoAdmin({
    required this.id,
    required this.nombre,
    required this.direccion,
    this.distrito,
    required this.estado,
    required this.puestos,
  });
  final int id;
  final String nombre;
  final String direccion;
  final String? distrito;
  final String estado;
  final int puestos;
  bool get activo => estado == 'activo';

  factory MercadoAdmin.desdeJson(Map<String, dynamic> j) => MercadoAdmin(
    id: (j['id'] as num).toInt(),
    nombre: j['nombre'].toString(),
    direccion: j['direccion']?.toString() ?? '',
    distrito: j['distrito']?.toString(),
    estado: j['estado']?.toString() ?? 'activo',
    puestos: ((j['puestos'] as num?) ?? 0).toInt(),
  );
}

/// RF-05 y RF-18 desde la app: solo responde a cuentas con rol administrador.
class AdministracionApiRepository {
  AdministracionApiRepository({http.Client? client, this.baseUrl})
    : _client = client ?? http.Client();
  static final instancia = AdministracionApiRepository();
  final http.Client _client;
  final String? baseUrl;

  Future<List<SolicitudRepartidor>> solicitudes() async => [
    for (final j
        in await _enviar('GET', '/api/administracion/repartidores/') as List)
      SolicitudRepartidor.desdeJson(Map<String, dynamic>.from(j)),
  ];

  Future<void> autorizar(int solicitudId, {required bool autorizar}) => _enviar(
    'POST',
    '/api/administracion/repartidores/$solicitudId/'
        '${autorizar ? 'autorizar' : 'quitar'}/',
    body: const {},
  );

  Future<List<MercadoAdmin>> mercados() async => [
    for (final j
        in await _enviar('GET', '/api/administracion/mercados/') as List)
      MercadoAdmin.desdeJson(Map<String, dynamic>.from(j)),
  ];

  Future<void> crearMercado({
    required String nombre,
    required String direccion,
    String distrito = '',
  }) => _enviar(
    'POST',
    '/api/administracion/mercados/',
    body: {'nombre': nombre, 'direccion': direccion, 'distrito': distrito},
  );

  Future<void> editarMercado(int id, Map<String, dynamic> cambios) =>
      _enviar('PATCH', '/api/administracion/mercados/$id/', body: cambios);

  Future<dynamic> _enviar(
    String metodo,
    String ruta, {
    Map<String, dynamic>? body,
  }) async {
    final token = SesionState.token;
    if (token == null) {
      throw const AdministracionException(
        'Tu sesión venció. Vuelve a ingresar.',
      );
    }
    try {
      final req =
          http.Request(metodo, ApiConfig.uri(ruta, baseUrlOverride: baseUrl))
            ..headers.addAll({
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            });
      if (body != null) req.body = jsonEncode(body);
      final res = await http.Response.fromStream(
        await _client.send(req).timeout(const Duration(seconds: 20)),
      );
      final data = res.body.isEmpty ? null : jsonDecode(res.body);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw AdministracionException(_mensaje(data));
      }
      return data;
    } on AdministracionException {
      rethrow;
    } on TimeoutException {
      throw const AdministracionException('El servidor tardó demasiado.');
    } catch (_) {
      throw const AdministracionException(
        'No pudimos conectarnos con MiMercado+.',
      );
    }
  }

  static String _mensaje(dynamic data) {
    if (data is Map) {
      if (data['detail'] != null) return data['detail'].toString();
      for (final v in data.values) {
        if (v is List && v.isNotEmpty) return v.first.toString();
      }
    }
    if (data is List && data.isNotEmpty) return data.first.toString();
    return 'No pudimos guardar el cambio. Revisa los datos.';
  }
}
