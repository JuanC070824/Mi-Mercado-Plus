import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/state/sesion_state.dart';

class PuestoVendedorException implements Exception {
  const PuestoVendedorException(this.mensaje);
  final String mensaje;
}

class MercadoParaPuesto {
  const MercadoParaPuesto({
    required this.id,
    required this.nombre,
    required this.direccion,
    this.distrito,
  });

  final int id;
  final String nombre;
  final String direccion;
  final String? distrito;
}

class CategoriaParaPuesto {
  const CategoriaParaPuesto({required this.id, required this.nombre});
  final int id;
  final String nombre;
}

class PuestoDelVendedor {
  const PuestoDelVendedor({
    required this.id,
    required this.nombre,
    required this.mercado,
    required this.categoria,
    required this.abierto,
    this.numero,
    this.referencia,
    this.fotoUrl,
    this.contactoBilletera,
    this.horarios = const [],
  });

  final int id;
  final String nombre;
  final MercadoParaPuesto mercado;
  final CategoriaParaPuesto categoria;
  final bool abierto;
  final String? numero;
  final String? referencia;
  final String? fotoUrl;
  final String? contactoBilletera;
  final List<String> horarios;
}

class DatosPuestoVendedor {
  const DatosPuestoVendedor({
    required this.mercados,
    required this.categorias,
    this.puesto,
  });
  final List<MercadoParaPuesto> mercados;
  final List<CategoriaParaPuesto> categorias;
  final PuestoDelVendedor? puesto;
}

class PuestoVendedorApiRepository {
  PuestoVendedorApiRepository({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl;

  static final instancia = PuestoVendedorApiRepository();
  static final ValueNotifier<int> cambios = ValueNotifier<int>(0);

  final http.Client _client;
  final String? _baseUrl;

  Future<DatosPuestoVendedor> cargar() async {
    try {
      final respuestas = await Future.wait([
        _get('/api/mercados/', autenticada: false),
        _get('/api/categorias/', autenticada: false),
        _get('/api/vendedor/puesto/'),
      ]);
      for (final respuesta in respuestas) {
        if (respuesta.statusCode != 200) {
          throw PuestoVendedorException(_mensaje(respuesta));
        }
      }
      final mercadosJson = jsonDecode(respuestas[0].body);
      final categoriasJson = jsonDecode(respuestas[1].body);
      final puestoJson = _mapa(jsonDecode(respuestas[2].body));
      if (mercadosJson is! List || categoriasJson is! List) {
        throw const FormatException('Catálogos inválidos');
      }
      return DatosPuestoVendedor(
        mercados: mercadosJson.map((item) => _mercado(_mapa(item))).toList(),
        categorias: categoriasJson
            .map((item) => _categoria(_mapa(item)))
            .toList(),
        puesto: puestoJson['tiene_puesto'] == true
            ? _puesto(_mapa(puestoJson['puesto']))
            : null,
      );
    } on PuestoVendedorException {
      rethrow;
    } on TimeoutException {
      throw const PuestoVendedorException(
        'La carga tardó demasiado. Inténtalo nuevamente.',
      );
    } on FormatException {
      throw const PuestoVendedorException(
        'El servidor devolvió datos inválidos.',
      );
    } catch (_) {
      throw const PuestoVendedorException(
        'No pudimos conectarnos con MiMercado+.',
      );
    }
  }

  Future<PuestoDelVendedor> guardar({
    required int? puestoId,
    required int mercadoId,
    required int categoriaId,
    required String nombre,
    required String numero,
    required String referencia,
  }) async {
    final response = await _request(
      puestoId == null ? 'POST' : 'PATCH',
      '/api/vendedor/puesto/',
      body: {
        'mercado_id': mercadoId,
        'categoria_id': categoriaId,
        'nombre': nombre,
        'numero': numero,
        'referencia': referencia,
      },
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw PuestoVendedorException(_mensaje(response));
    }
    try {
      final puesto = _puesto(_mapa(jsonDecode(response.body)));
      cambios.value++;
      return puesto;
    } on FormatException {
      throw const PuestoVendedorException(
        'El servidor devolvió datos inválidos.',
      );
    }
  }

  Future<http.Response> _get(String ruta, {bool autenticada = true}) =>
      _request('GET', ruta, autenticada: autenticada);

  Future<http.Response> _request(
    String metodo,
    String ruta, {
    bool autenticada = true,
    Map<String, dynamic>? body,
  }) async {
    final request = http.Request(
      metodo,
      ApiConfig.uri(ruta, baseUrlOverride: _baseUrl),
    );
    request.headers['Content-Type'] = 'application/json';
    if (autenticada) {
      final token = SesionState.token;
      if (token == null) {
        throw const PuestoVendedorException(
          'Tu sesión venció. Vuelve a iniciar sesión.',
        );
      }
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (body != null) request.body = jsonEncode(body);
    try {
      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 15));
      return await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const PuestoVendedorException(
        'La conexión tardó demasiado. Inténtalo nuevamente.',
      );
    } on PuestoVendedorException {
      rethrow;
    } catch (_) {
      throw const PuestoVendedorException(
        'No pudimos conectarnos con MiMercado+.',
      );
    }
  }

  static PuestoDelVendedor _puesto(
    Map<String, dynamic> data,
  ) => PuestoDelVendedor(
    id: _entero(data['id']),
    nombre: _texto(data['nombre']),
    numero: _opcional(data['numero']),
    referencia: _opcional(data['referencia']),
    fotoUrl: _opcional(data['foto_url']),
    contactoBilletera: _opcional(data['contacto_billetera']),
    horarios: [
      for (final h in data['horarios'] as List? ?? const [])
        '${const ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'][((h['dia'] as num).toInt() - 1).clamp(0, 6)]}: ${h['apertura']}–${h['cierre']}',
    ],
    abierto: data['abierto'] == true,
    mercado: _mercado(_mapa(data['mercado'])),
    categoria: _categoria(_mapa(data['categoria'])),
  );

  static MercadoParaPuesto _mercado(Map<String, dynamic> data) =>
      MercadoParaPuesto(
        id: _entero(data['id']),
        nombre: _texto(data['nombre']),
        direccion: _texto(data['direccion']),
        distrito: _opcional(data['distrito']),
      );

  static CategoriaParaPuesto _categoria(Map<String, dynamic> data) =>
      CategoriaParaPuesto(
        id: _entero(data['id']),
        nombre: _texto(data['nombre']),
      );

  static Map<String, dynamic> _mapa(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    throw const FormatException('Se esperaba un objeto');
  }

  static int _entero(dynamic value) {
    if (value is num) return value.toInt();
    throw const FormatException('Se esperaba un número');
  }

  static String _texto(dynamic value) {
    final texto = value?.toString().trim() ?? '';
    if (texto.isEmpty) throw const FormatException('Se esperaba texto');
    return texto;
  }

  static String? _opcional(dynamic value) {
    final texto = value?.toString().trim();
    return texto == null || texto.isEmpty ? null : texto;
  }

  static String _mensaje(http.Response response) {
    try {
      final data = _mapa(jsonDecode(response.body));
      final detail = data['detail'];
      if (detail is String) return detail;
      for (final value in data.values) {
        if (value is List && value.isNotEmpty) return value.first.toString();
        if (value is String && value.isNotEmpty) return value;
      }
    } catch (_) {}
    return 'No pudimos guardar tu puesto. Revisa los datos e inténtalo nuevamente.';
  }
}
