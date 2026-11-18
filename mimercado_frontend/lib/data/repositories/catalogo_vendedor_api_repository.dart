import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/state/sesion_state.dart';
import '../models/producto.dart';
import 'catalogo_api_repository.dart';
import 'catalogo_repository.dart';

class CatalogoVendedorApiRepository {
  CatalogoVendedorApiRepository({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl;
  static final instancia = CatalogoVendedorApiRepository();
  final http.Client _client;
  final String? _baseUrl;

  Future<List<Producto>> cargar() async {
    final data = await _enviar('GET', '/api/vendedor/productos/');
    final lista = data['productos'];
    if (lista is! List) {
      throw const CatalogoException(
        'El servidor devolvió un catálogo inválido.',
      );
    }
    return [
      for (final item in lista)
        if (item is Map<String, dynamic>)
          CatalogoApiRepository.productoDesdeJson(item),
    ];
  }

  Future<Producto> crear(Producto producto) async {
    final data = await _enviar(
      'POST',
      '/api/vendedor/productos/',
      body: _body(producto),
      exitosos: const {201},
    );
    return CatalogoApiRepository.productoDesdeJson(data);
  }

  Future<Producto> actualizar(Producto producto) async {
    final data = await _enviar(
      'PATCH',
      '/api/vendedor/productos/${producto.id}/',
      body: _body(producto),
    );
    return CatalogoApiRepository.productoDesdeJson(data);
  }

  Map<String, dynamic> _body(Producto p) => {
    'nombre': p.nombre,
    'unidad_codigo': switch (p.unidad) {
      UnidadMedida.unidad => 'unidad',
      UnidadMedida.atado => 'atado',
      UnidadMedida.litro => 'litro',
      _ => 'kg',
    },
    'precio_unitario': p.precioUnitario.toStringAsFixed(2),
    'disponible': p.disponible,
    'icono': p.imagen ?? 'icono:otro',
  };

  Future<Map<String, dynamic>> _enviar(
    String metodo,
    String ruta, {
    Map<String, dynamic>? body,
    Set<int> exitosos = const {200},
  }) async {
    final token = SesionState.token;
    if (token == null) {
      throw const CatalogoException(
        'Tu sesión venció. Vuelve a iniciar sesión.',
      );
    }
    try {
      final request =
          http.Request(metodo, ApiConfig.uri(ruta, baseUrlOverride: _baseUrl))
            ..headers.addAll({
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            });
      if (body != null) request.body = jsonEncode(body);
      final response = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 15)),
      );
      final decoded = jsonDecode(response.body);
      final data = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
      if (!exitosos.contains(response.statusCode)) {
        throw CatalogoException(_mensaje(data));
      }
      return data;
    } on CatalogoException {
      rethrow;
    } on TimeoutException {
      throw const CatalogoException(
        'El servidor tardó demasiado en responder.',
      );
    } catch (_) {
      throw const CatalogoException('No pudimos conectarnos con MiMercado+.');
    }
  }

  String _mensaje(Map<String, dynamic> data) {
    final detail = data['detail'];
    if (detail != null) return detail.toString();
    for (final value in data.values) {
      if (value is List && value.isNotEmpty) return value.first.toString();
      if (value is String) return value;
    }
    return 'No pudimos guardar el producto.';
  }
}
