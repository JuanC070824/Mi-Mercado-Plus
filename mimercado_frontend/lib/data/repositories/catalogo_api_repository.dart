import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../models/mercado.dart';
import '../models/producto.dart';
import '../models/puesto.dart';
import 'catalogo_repository.dart';

class CatalogoApiRepository implements CatalogoRepository {
  CatalogoApiRepository({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl;

  static final CatalogoApiRepository instancia = CatalogoApiRepository();
  final http.Client _client;
  final String? _baseUrl;

  Future<dynamic> _get(String ruta) async {
    try {
      final response = await _client
          .get(ApiConfig.uri(ruta, baseUrlOverride: _baseUrl))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw const CatalogoException('No pudimos cargar el catálogo.');
      }
      return jsonDecode(response.body);
    } on CatalogoException {
      rethrow;
    } on TimeoutException {
      throw const CatalogoException(
        'La carga tardó demasiado. Inténtalo nuevamente.',
      );
    } catch (_) {
      throw const CatalogoException(
        'No pudimos conectarnos para cargar el catálogo.',
      );
    }
  }

  @override
  Future<List<MercadoCercano>> mercados({
    double? latitud,
    double? longitud,
  }) async {
    final decoded = await _get('/api/mercados/');
    if (decoded is! List) {
      throw const CatalogoException('Lista de mercados inválida.');
    }
    final resultado = <MercadoCercano>[];
    for (final value in decoded) {
      if (value is! Map<String, dynamic>) continue;
      final mercado = Mercado(
        id: (value['id'] as num).toInt(),
        nombre: value['nombre'].toString(),
        direccion: value['direccion'].toString(),
        distrito: _texto(value['distrito']),
        latitud: _decimal(value['latitud']),
        longitud: _decimal(value['longitud']),
      );
      final distancia =
          latitud != null &&
              longitud != null &&
              mercado.latitud != null &&
              mercado.longitud != null
          ? _distanciaKm(latitud, longitud, mercado.latitud!, mercado.longitud!)
          : null;
      resultado.add(MercadoCercano(mercado, distancia));
    }
    resultado.sort(
      (a, b) => (a.distanciaKm ?? double.infinity).compareTo(
        b.distanciaKm ?? double.infinity,
      ),
    );
    return resultado;
  }

  @override
  Future<List<Puesto>> masQueridos({int? mercadoId, int limite = 5}) async {
    final todos = await _puestos(mercadoId: mercadoId);
    todos.sort((a, b) => b.calificacion.compareTo(a.calificacion));
    return todos.take(limite).toList();
  }

  @override
  Future<List<Puesto>> buscar({
    required int mercadoId,
    CategoriaPuesto? categoria,
    String texto = '',
  }) async {
    final q = texto.trim().toLowerCase();
    return (await _puestos(mercadoId: mercadoId))
        .where(
          (p) =>
              (categoria == null || p.categoria == categoria) &&
              (q.isEmpty ||
                  p.nombre.toLowerCase().contains(q) ||
                  p.casero.toLowerCase().contains(q)),
        )
        .toList();
  }

  @override
  Future<Puesto?> puesto(int id) async {
    for (final p in await _puestos()) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<List<Puesto>> _puestos({int? mercadoId}) async {
    final ruta = mercadoId == null
        ? '/api/puestos/'
        : '/api/puestos/?mercado_id=$mercadoId';
    final decoded = await _get(ruta);
    if (decoded is! List) {
      throw const CatalogoException('Lista de puestos inválida.');
    }
    return [
      for (final value in decoded)
        if (value is Map<String, dynamic>) _puesto(value),
    ];
  }

  @override
  Future<List<Producto>> productosDePuesto(int puestoId) async {
    final decoded = await _get('/api/productos/?puesto_id=$puestoId');
    if (decoded is! List) {
      throw const CatalogoException('Lista de productos inválida.');
    }
    return [
      for (final value in decoded)
        if (value is Map<String, dynamic>) productoDesdeJson(value),
    ];
  }

  @override
  Future<void> actualizarProducto(Producto producto) =>
      throw const CatalogoException(
        'Usa el catálogo del vendedor para editar productos.',
      );
  @override
  Future<Puesto> cambiarAbierto(int puestoId, bool abierto) =>
      throw const CatalogoException('Usa Mi puesto para cambiar su estado.');

  static Producto productoDesdeJson(Map<String, dynamic> value) => Producto(
    id: (value['id'] as num).toInt(),
    puestoId: (value['puesto_id'] as num).toInt(),
    nombre: value['nombre'].toString(),
    unidad: unidadDesdeCodigo(value['unidad']?.toString()),
    precioUnitario:
        ((value['precio_unitario_centavos'] as num?) ?? 0).toDouble() / 100,
    disponible: value['disponible'] == true,
    imagen: _texto(value['foto_url']),
  );

  static UnidadMedida unidadDesdeCodigo(String? codigo) => switch (codigo) {
    'unidad' => UnidadMedida.unidad,
    'atado' => UnidadMedida.atado,
    'litro' => UnidadMedida.litro,
    _ => UnidadMedida.kg,
  };

  static Puesto _puesto(Map<String, dynamic> value) => Puesto(
    id: (value['id'] as num).toInt(),
    mercadoId: (value['mercado_id'] as num).toInt(),
    nombre: value['nombre'].toString(),
    casero: value['casero']?.toString() ?? 'Casero',
    categoria: _categoria(value['categoria']?.toString()),
    calificacion: ((value['calificacion'] as num?) ?? 0).toDouble(),
    resenas: ((value['resenas'] as num?) ?? 0).toInt(),
    abierto: value['abierto'] == true,
  );

  static CategoriaPuesto _categoria(String? nombre) {
    final n = (nombre ?? '').toLowerCase();
    if (n.contains('carne') || n.contains('ave')) return CategoriaPuesto.carnes;
    if (n.contains('pesc')) return CategoriaPuesto.pescados;
    if (n.contains('abarrot')) return CategoriaPuesto.abarrotes;
    return CategoriaPuesto.verduras;
  }

  static String? _texto(dynamic value) {
    final t = value?.toString().trim();
    return t == null || t.isEmpty ? null : t;
  }

  static double? _decimal(dynamic value) =>
      value == null ? null : double.tryParse(value.toString());
  static double _distanciaKm(double a, double b, double c, double d) {
    const r = 6371.0;
    double rad(double g) => g * pi / 180;
    final x =
        pow(sin(rad(c - a) / 2), 2) +
        cos(rad(a)) * cos(rad(c)) * pow(sin(rad(d - b) / 2), 2);
    return 2 * r * asin(sqrt(x));
  }
}
