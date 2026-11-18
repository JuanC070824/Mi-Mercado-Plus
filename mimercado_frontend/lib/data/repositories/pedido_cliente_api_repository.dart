import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/state/sesion_state.dart';
import '../models/canasta.dart';
import '../models/direccion.dart';
import '../models/pedido.dart';
import 'pedido_repository.dart';

class PedidoClienteApiRepository {
  PedidoClienteApiRepository({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl;
  static final instancia = PedidoClienteApiRepository();
  final http.Client _client;
  final String? _baseUrl;

  Future<Pedido> crear({
    required Canasta canasta,
    required Direccion direccion,
    required MetodoPago metodo,
    required String clienteNombre,
    required String celular,
  }) async {
    if (direccion.id == null) {
      throw const PedidoException(
        'Guarda una dirección de entrega antes de pedir.',
      );
    }
    final token = SesionState.token;
    if (token == null) throw const PedidoException('Tu sesión venció.');
    try {
      final res = await _client
          .post(
            ApiConfig.uri('/api/pedidos/', baseUrlOverride: _baseUrl),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'direccion_id': direccion.id,
              'metodo_pago': metodo.codigoBd,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode >= 500) {
        throw const PedidoException(
          'El servidor no pudo crear el pedido. Tu canasta se conserva. Inténtalo nuevamente.',
        );
      }
      final decoded = jsonDecode(res.body);
      final data = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
      if (res.statusCode != 201) {
        throw PedidoException(
          data['detail']?.toString() ?? 'No pudimos enviar el pedido.',
        );
      }
      final id = (data['id'] as num).toInt();
      return Pedido(
        id: id,
        codigo: data['codigo'].toString(),
        codigoCorto: id.toString(),
        clienteNombre: clienteNombre,
        clienteCelular: celular,
        mercadoId: canasta.mercadoId!,
        estado: EstadoPedido.pendiente,
        metodoPago: metodo,
        direccion: direccion.direccion,
        referencia: direccion.referencia,
        puestos: const [],
        costoEnvio: Canasta.costoEnvio,
        historial: const [],
        codigoEntrega: '',
        creadoEn: DateTime.now(),
      );
    } on PedidoException {
      rethrow;
    } on TimeoutException {
      throw const PedidoException(
        'El servidor tardó demasiado en crear el pedido.',
      );
    } on FormatException {
      throw const PedidoException(
        'El servidor devolvió una respuesta inválida al crear el pedido.',
      );
    } catch (_) {
      throw const PedidoException('No pudimos conectarnos con MiMercado+.');
    }
  }
}
