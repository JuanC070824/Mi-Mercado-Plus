import 'pedidos_api_repository.dart';
import 'pedido_repository.dart';

import 'package:mimercado_frontend/core/i18n/idioma.dart';

/// Checkout de prueba y conciliación verificada con el reparto interno.
class MercadoPagoApiRepository {
  MercadoPagoApiRepository({PedidosApiRepository? transporte})
    : _transporte = transporte ?? PedidosApiRepository.instancia;

  final PedidosApiRepository _transporte;

  Future<Map<String, dynamic>> _solicitar(
    String metodo,
    String ruta, {
    Map<String, dynamic>? body,
  }) async {
    final data = await _transporte.solicitar(metodo, ruta, body: body);
    if (data is! Map<String, dynamic>) {
      throw PedidoException(tr('No pudimos leer la respuesta de pago.'));
    }
    return data;
  }

  Future<Map<String, dynamic>> configuracion() =>
      _solicitar('GET', '/api/pagos/mercadopago/configuracion/');

  Future<Map<String, dynamic>> crearCheckout(int pedidoId) => _solicitar(
    'POST',
    '/api/pagos/mercadopago/checkout/',
    body: {'pedido_id': pedidoId},
  );

  Future<Map<String, dynamic>> estado(int pedidoId) =>
      _solicitar('GET', '/api/pagos/mercadopago/pedidos/$pedidoId/estado/');

  Future<Map<String, dynamic>> pagarIntegrado(
    int pedidoId,
    Map<String, dynamic> datos,
  ) => _solicitar(
    'POST',
    '/api/pagos/mercadopago/integrado/',
    body: {...datos, 'pedido_id': pedidoId},
  );

  Future<Map<String, dynamic>> confirmar(int pedidoId) => _solicitar(
    'POST',
    '/api/pagos/mercadopago/confirmar/',
    body: {'pedido_id': pedidoId},
  );

  Future<Map<String, dynamic>> cancelarIntento(int pedidoId) => _solicitar(
    'POST',
    '/api/pagos/mercadopago/cancelar-intento/',
    body: {'pedido_id': pedidoId},
  );

  static Uri validarCheckout(dynamic valor) {
    final uri = valor is String ? Uri.tryParse(valor) : null;
    final orderId = uri?.queryParametersAll['order_id'];
    if (uri == null ||
        uri.scheme != 'https' ||
        !const {
          'www.mercadopago.com.pe',
          'mercadopago.com.pe',
        }.contains(uri.host) ||
        (uri.hasPort && uri.port != 443) ||
        uri.userInfo.isNotEmpty ||
        uri.path != '/checkout/v1/redirect' ||
        orderId == null ||
        orderId.length != 1 ||
        !RegExp(r'^ORDTST[A-Z0-9]{10,80}$').hasMatch(orderId.single)) {
      throw PedidoException(
        tr('No recibimos un enlace válido de Mercado Pago de prueba.'),
      );
    }
    return uri;
  }
}
