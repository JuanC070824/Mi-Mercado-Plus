import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../models/mercado.dart';
import 'catalogo_repository.dart';

/// Usa mercados reales del backend. El resto del catálogo continuará en su
/// repositorio actual hasta implementar el flujo de puestos y productos.
class CatalogoApiRepository extends CatalogoRepositoryMock {
  CatalogoApiRepository({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl;

  static final CatalogoApiRepository instancia = CatalogoApiRepository();

  final http.Client _client;
  final String? _baseUrl;

  @override
  Future<List<MercadoCercano>> mercados({
    double? latitud,
    double? longitud,
  }) async {
    try {
      final response = await _client
          .get(ApiConfig.uri('/api/mercados/', baseUrlOverride: _baseUrl))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw const CatalogoException(
          'No pudimos cargar los mercados. Inténtalo nuevamente.',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw const CatalogoException(
          'El servidor devolvió una lista de mercados inválida.',
        );
      }

      final mercados = decoded.map(_mercadoDesdeJson).toList();
      final conUbicacion = latitud != null && longitud != null;
      final resultado = [
        for (final mercado in mercados)
          MercadoCercano(
            mercado,
            conUbicacion &&
                    mercado.latitud != null &&
                    mercado.longitud != null
                ? _distanciaKm(
                    latitud,
                    longitud,
                    mercado.latitud!,
                    mercado.longitud!,
                  )
                : null,
          ),
      ];

      if (conUbicacion) {
        resultado.sort((a, b) {
          final distanciaA = a.distanciaKm;
          final distanciaB = b.distanciaKm;
          if (distanciaA == null) return distanciaB == null ? 0 : 1;
          if (distanciaB == null) return -1;
          return distanciaA.compareTo(distanciaB);
        });
      }
      return resultado;
    } on CatalogoException {
      rethrow;
    } on TimeoutException {
      throw const CatalogoException(
        'La carga de mercados tardó demasiado. Inténtalo nuevamente.',
      );
    } on FormatException {
      throw const CatalogoException(
        'El servidor devolvió una lista de mercados inválida.',
      );
    } catch (_) {
      throw const CatalogoException(
        'No pudimos conectarnos para cargar los mercados.',
      );
    }
  }

  static Mercado _mercadoDesdeJson(dynamic value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Mercado inválido');
    }
    final id = (value['id'] as num?)?.toInt();
    final nombre = value['nombre']?.toString().trim() ?? '';
    final direccion = value['direccion']?.toString().trim() ?? '';
    if (id == null || nombre.isEmpty || direccion.isEmpty) {
      throw const FormatException('Mercado incompleto');
    }
    return Mercado(
      id: id,
      nombre: nombre,
      direccion: direccion,
      distrito: _textoOpcional(value['distrito']),
      latitud: _decimalOpcional(value['latitud']),
      longitud: _decimalOpcional(value['longitud']),
    );
  }

  static String? _textoOpcional(dynamic value) {
    final texto = value?.toString().trim();
    return texto == null || texto.isEmpty ? null : texto;
  }

  static double? _decimalOpcional(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static double _distanciaKm(
    double latitudA,
    double longitudA,
    double latitudB,
    double longitudB,
  ) {
    const radioTierra = 6371.0;
    double radianes(double grados) => grados * pi / 180;
    final diferenciaLatitud = radianes(latitudB - latitudA);
    final diferenciaLongitud = radianes(longitudB - longitudA);
    final calculo = pow(sin(diferenciaLatitud / 2), 2) +
        cos(radianes(latitudA)) *
            cos(radianes(latitudB)) *
            pow(sin(diferenciaLongitud / 2), 2);
    return 2 * radioTierra * asin(sqrt(calculo));
  }
}
