import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/state/sesion_state.dart';
import '../models/canasta.dart';
import '../models/producto.dart';
import '../models/puesto.dart';
import 'canasta_repository.dart';
import 'catalogo_api_repository.dart';

class CanastaApiRepository implements CanastaRepository {
  CanastaApiRepository({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl;
  static final instancia = CanastaApiRepository();
  final http.Client _client;
  final String? _baseUrl;
  final ValueNotifier<Canasta> _canasta = ValueNotifier(const Canasta());
  final Map<int, int> _itemIds = {};
  bool _cargada = false;

  @override
  ValueListenable<Canasta> get canasta => _canasta;

  Future<Canasta> cargar() async {
    final data = await _enviar('GET', '/api/carrito/');
    _publicarDesdeJson(data);
    _cargada = true;
    return _canasta.value;
  }

  @override
  Future<Canasta> agregar(Puesto puesto, Producto producto) async {
    if (!_cargada) await cargar();
    return cambiarCantidad(
      puesto,
      producto,
      _canasta.value.cantidadDe(producto.id) + producto.unidad.paso,
    );
  }

  @override
  Future<Canasta> restar(Producto producto) async {
    if (!_cargada) await cargar();
    final grupo = _canasta.value.grupos.firstWhere(
      (g) => g.item(producto.id) != null,
    );
    return cambiarCantidad(
      grupo.puesto,
      producto,
      _canasta.value.cantidadDe(producto.id) - producto.unidad.paso,
    );
  }

  @override
  Future<Canasta> cambiarCantidad(
    Puesto puesto,
    Producto producto,
    double cantidad,
  ) async {
    if (!_cargada) await cargar();
    final nueva = cantidad <= 0
        ? 0.0
        : (cantidad / producto.unidad.paso).round() * producto.unidad.paso;
    Map<String, dynamic> data;
    if (nueva == 0) {
      final itemId = _itemIds[producto.id];
      if (itemId == null) return _canasta.value;
      data = await _enviar('DELETE', '/api/carrito/items/$itemId/');
    } else {
      data = await _enviar(
        'POST',
        '/api/carrito/items/',
        body: {'producto_id': producto.id, 'cantidad': nueva},
      );
    }
    _publicarDesdeJson(data);
    return _canasta.value;
  }

  @override
  Future<Canasta> quitar(int productoId) async {
    final itemId = _itemIds[productoId];
    if (itemId == null) return _canasta.value;
    _publicarDesdeJson(await _enviar('DELETE', '/api/carrito/items/$itemId/'));
    return _canasta.value;
  }

  @override
  Future<Canasta> guardarListaMandado(int puestoId, String texto) async {
    if (texto.trim().length > 300) {
      throw const CanastaException(
        'La lista de mandado puede tener hasta 300 letras.',
      );
    }
    final c = _canasta.value;
    final grupo = c.grupo(puestoId);
    if (grupo == null) {
      throw const CanastaException(
        'Primero agrega un producto de este puesto.',
      );
    }
    _canasta.value = Canasta(
      grupos: [
        for (final g in c.grupos)
          if (g.puesto.id == puestoId)
            GrupoPuesto(
              puesto: g.puesto,
              items: g.items,
              listaMandado: texto.trim().isEmpty ? null : texto.trim(),
            )
          else
            g,
      ],
    );
    return _canasta.value;
  }

  @override
  Future<Canasta> vaciar() async {
    for (final id in [..._itemIds.values]) {
      await _enviar('DELETE', '/api/carrito/items/$id/');
    }
    _itemIds.clear();
    _canasta.value = const Canasta();
    return _canasta.value;
  }

  void _publicarDesdeJson(Map<String, dynamic> data) {
    _itemIds.clear();
    final grupos = <GrupoPuesto>[];
    for (final raw in (data['puestos'] as List? ?? const [])) {
      if (raw is! Map<String, dynamic>) continue;
      final puesto = Puesto(
        id: (raw['puesto_id'] as num).toInt(),
        mercadoId: (raw['mercado_id'] as num).toInt(),
        nombre: raw['nombre'].toString(),
        casero: raw['casero']?.toString() ?? 'Casero',
        categoria: _categoria(raw['categoria']?.toString()),
        calificacion: 0,
        resenas: 0,
        abierto: raw['abierto'] == true,
      );
      final items = <ItemCanasta>[];
      for (final item in (raw['items'] as List? ?? const [])) {
        if (item is! Map<String, dynamic>) continue;
        final producto = Producto(
          id: (item['producto_id'] as num).toInt(),
          puestoId: puesto.id,
          nombre: item['nombre'].toString(),
          unidad: CatalogoApiRepository.unidadDesdeCodigo(
            item['unidad']?.toString(),
          ),
          precioUnitario:
              ((item['precio_unitario_centavos'] as num?) ?? 0).toDouble() /
              100,
          disponible: item['disponible'] != false,
          imagen: item['foto_url']?.toString(),
        );
        _itemIds[producto.id] = (item['id'] as num).toInt();
        items.add(
          ItemCanasta(
            producto: producto,
            cantidad: double.parse(item['cantidad'].toString()),
          ),
        );
      }
      grupos.add(
        GrupoPuesto(
          puesto: puesto,
          items: items,
          listaMandado: raw['lista_mandado']?.toString(),
        ),
      );
    }
    _canasta.value = Canasta(grupos: grupos);
  }

  CategoriaPuesto _categoria(String? n) {
    final v = (n ?? '').toLowerCase();
    if (v.contains('carne')) return CategoriaPuesto.carnes;
    if (v.contains('pesc')) return CategoriaPuesto.pescados;
    if (v.contains('abarrot')) return CategoriaPuesto.abarrotes;
    return CategoriaPuesto.verduras;
  }

  Future<Map<String, dynamic>> _enviar(
    String metodo,
    String ruta, {
    Map<String, dynamic>? body,
  }) async {
    final token = SesionState.token;
    if (token == null) throw const CanastaException('Tu sesión venció.');
    try {
      final req =
          http.Request(metodo, ApiConfig.uri(ruta, baseUrlOverride: _baseUrl))
            ..headers.addAll({
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            });
      if (body != null) req.body = jsonEncode(body);
      final res = await http.Response.fromStream(
        await _client.send(req).timeout(const Duration(seconds: 15)),
      );
      final decoded = jsonDecode(res.body);
      final data = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw CanastaException(
          data['detail']?.toString() ?? 'No pudimos actualizar tu canasta.',
        );
      }
      return data;
    } on CanastaException {
      rethrow;
    } on TimeoutException {
      throw const CanastaException('El servidor tardó demasiado.');
    } catch (_) {
      throw const CanastaException('No pudimos conectarnos con MiMercado+.');
    }
  }
}
