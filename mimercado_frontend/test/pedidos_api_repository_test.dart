import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mimercado_frontend/core/state/sesion_state.dart';
import 'package:mimercado_frontend/data/repositories/pedidos_api_repository.dart';
import 'package:mimercado_frontend/data/repositories/pedido_repository.dart';
import 'helpers/reparto_fixture.dart';

void main() {
  setUp(() => SesionState.iniciar(token: 'sesion-prueba', expiresIn: 3600));
  tearDown(SesionState.cerrar);
  test(
    'precio usa la cotización real y el pago no acepta un monto del cliente',
    () async {
      final recibidas = <http.Request>[];
      final repo = PedidosApiRepository(
        baseUrl: 'http://localhost',
        client: MockClient((r) async {
          recibidas.add(r);
          expect(r.headers['Authorization'], 'Bearer sesion-prueba');
          return http.Response(
            jsonEncode(r.url.path.endsWith('yape/') ? {'success': true} : {}),
            200,
          );
        }),
      );
      repo.leer(pedidoRepartoJson());
      await repo.aceptarCotizacion(25);
      await repo.pagarYape(25, '900000001', '123456');
      expect(
        recibidas.first.url.path,
        '/api/pedidos/25/cotizaciones/99/aceptar/',
      );
      final pago = jsonDecode(recibidas.last.body) as Map;
      expect(pago['pedido_id'], 25);
      expect(pago.containsKey('amount'), isFalse);
      expect(pago.containsKey('monto'), isFalse);
    },
  );
  test(
    'reintento de respuesta incierta conserva la clave y rechazo permite corregir',
    () async {
      final claves = <String>[];
      var intento = 0;
      final repo = PedidosApiRepository(
        baseUrl: 'http://localhost',
        client: MockClient((r) async {
          claves.add(jsonDecode(r.body)['idempotencia']);
          intento++;
          if (intento == 1) return http.Response('<html>Error</html>', 500);
          if (intento == 2) {
            return http.Response(
              jsonEncode({
                'estado': 'rechazado',
                'detail': 'Código incorrecto',
              }),
              402,
            );
          }
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );
      await expectLater(
        repo.pagarYape(25, '900000001', '000000'),
        throwsA(isA<PedidoException>()),
      );
      await expectLater(
        repo.pagarYape(25, '900000001', '000000'),
        throwsA(isA<PedidoException>()),
      );
      await repo.pagarYape(25, '900000001', '123456');
      expect(claves[0], claves[1]);
      expect(claves[2], isNot(claves[1]));
    },
  );
  test(
    'no usa datos mock si el servidor falla y no envía nada sin sesión',
    () async {
      var solicitudes = 0;
      final repo = PedidosApiRepository(
        baseUrl: 'http://localhost',
        client: MockClient((r) async {
          solicitudes++;
          return http.Response('Error', 500);
        }),
      );
      await expectLater(
        repo.inicioRepartidor(),
        throwsA(isA<PedidoException>()),
      );
      SesionState.cerrar();
      await expectLater(
        repo.inicioRepartidor(),
        throwsA(isA<PedidoException>()),
      );
      expect(solicitudes, 1);
    },
  );
  test('cambio de movilidad envía únicamente movilidad y sus datos', () async {
    final repo = PedidosApiRepository(
      baseUrl: 'http://localhost',
      client: MockClient((r) async {
        expect(r.method, 'PATCH');
        expect(r.url.path, '/api/repartidor/mercado/');
        expect(jsonDecode(r.body), {
          'movilidad': 'moto',
          'placa': 'ABC-123',
          'descripcion_movilidad': '',
        });
        return http.Response('{}', 200);
      }),
    );
    await repo.cambiarMovilidad('moto', 'ABC-123', '');
  });
}
