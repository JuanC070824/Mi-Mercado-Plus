import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/state/sesion_state.dart';
import '../models/mercado.dart';
import '../models/producto.dart';
import '../models/puesto.dart';
import 'catalogo_repository.dart';

/// Un producto que el cliente pide seguido ("Lo que siempre pides").
class ProductoFrecuente {
  const ProductoFrecuente({
    required this.producto,
    required this.puesto,
    required this.veces,
  });
  final Producto producto;
  final Puesto puesto;
  final int veces;
}

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
    // RF-20: con sesión, primero los caseros donde más compra el cliente.
    final recomendados = await _recomendados(mercadoId);
    if (recomendados != null) return recomendados.take(limite).toList();
    final todos = await _puestos(mercadoId: mercadoId);
    todos.sort((a, b) => b.calificacion.compareTo(a.calificacion));
    return todos.take(limite).toList();
  }

  /// null si no hay sesión de cliente o el servidor no responde: se usa el orden general.
  Future<List<Puesto>?> _recomendados(int? mercadoId) async {
    final puestos = (await _recomendaciones(mercadoId))?['puestos'];
    if (puestos is! List) return null;
    return [
      for (final value in puestos)
        if (value is Map<String, dynamic>) _puesto(value),
    ];
  }

  /// RF-20: productos que el cliente más repite, con su puesto para agregarlos.
  Future<List<ProductoFrecuente>> loQueSiemprePides({int? mercadoId}) async {
    final productos = (await _recomendaciones(mercadoId))?['productos'];
    if (productos is! List) return const [];
    return [
      for (final value in productos)
        if (value is Map<String, dynamic> &&
            value['puesto'] is Map<String, dynamic>)
          ProductoFrecuente(
            producto: productoDesdeJson(value),
            puesto: _puesto(value['puesto'] as Map<String, dynamic>),
            veces: ((value['veces'] as num?) ?? 0).toInt(),
          ),
    ];
  }

  // El inicio pide caseros y productos casi a la vez: una sola llamada sirve
  // para ambos durante unos segundos.
  ({int? mercadoId, String? token, DateTime en, Future<Map?> datos})? _ultima;

  Future<Map?> _recomendaciones(int? mercadoId) {
    final token = SesionState.token;
    if (token == null) return Future.value(null);
    final u = _ultima;
    if (u != null &&
        u.mercadoId == mercadoId &&
        u.token == token &&
        DateTime.now().difference(u.en) < const Duration(seconds: 5)) {
      return u.datos;
    }
    final datos = _pedirRecomendaciones(mercadoId, token);
    _ultima = (
      mercadoId: mercadoId,
      token: token,
      en: DateTime.now(),
      datos: datos,
    );
    return datos;
  }

  Future<Map?> _pedirRecomendaciones(int? mercadoId, String token) async {
    try {
      final ruta = mercadoId == null
          ? '/api/comprador/recomendaciones/'
          : '/api/comprador/recomendaciones/?mercado_id=$mercadoId';
      final response = await _client
          .get(
            ApiConfig.uri(ruta, baseUrlOverride: _baseUrl),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      return data is Map ? data : null;
    } catch (_) {
      return null;
    }
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
