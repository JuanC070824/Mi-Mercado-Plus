import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mimercado_frontend/core/state/sesion_state.dart';
import 'package:mimercado_frontend/data/models/canasta.dart';
import 'package:mimercado_frontend/data/models/direccion.dart';
import 'package:mimercado_frontend/data/models/pedido.dart';
import 'package:mimercado_frontend/data/models/puesto.dart';
import 'package:mimercado_frontend/data/repositories/pago_repository.dart';
import 'package:mimercado_frontend/data/repositories/pedido_cliente_api_repository.dart';
import 'package:mimercado_frontend/data/repositories/pedido_repository.dart';

Future<Pedido> _crear(http.Client client) =>
    PedidoClienteApiRepository(
      client: client,
      baseUrl: 'https://example.test',
    ).crear(
      canasta: const Canasta(
        grupos: [
          GrupoPuesto(
            puesto: Puesto(
              id: 1,
              mercadoId: 2,
              nombre: 'Verduras',
              casero: 'Rosa',
              categoria: CategoriaPuesto.verduras,
              calificacion: 0,
              resenas: 0,
            ),
            items: [],
          ),
        ],
      ),
      direccion: const Direccion(id: 3, direccion: 'Dirección de prueba'),
      metodo: MetodoPago.yape,
      clienteNombre: 'María',
      celular: '900000001',
    );
void main() {
  setUp(() => SesionState.iniciar(token: 'prueba', expiresIn: 3600));
  tearDown(SesionState.cerrar);
  test(
    'error 500 HTML identifica fallo del servidor y conserva la canasta',
    () async {
      await expectLater(
        _crear(
          MockClient(
            (_) async =>
                http.Response('<html>Internal Server Error</html>', 500),
          ),
        ),
        throwsA(
          isA<PedidoException>().having(
            (e) => e.mensaje,
            'mensaje',
            contains(
              'El servidor no pudo crear el pedido. Tu canasta se conserva.',
            ),
          ),
        ),
      );
    },
  );
  test('respuesta inválida no se confunde con fallo de conexión', () async {
    await expectLater(
      _crear(MockClient((_) async => http.Response('no es JSON', 201))),
      throwsA(
        isA<PedidoException>().having(
          (e) => e.mensaje,
          'mensaje',
          contains('respuesta inválida'),
        ),
      ),
    );
  });
  test('mantiene el mensaje de validación del backend', () async {
    await expectLater(
      _crear(
        MockClient(
          (_) async => http.Response(
            jsonEncode({'detail': 'La canasta está vacía.'}),
            400,
          ),
        ),
      ),
      throwsA(
        isA<PedidoException>().having(
          (e) => e.mensaje,
          'mensaje',
          'La canasta está vacía.',
        ),
      ),
    );
  });
  test('fallo de red sí muestra error de conexión', () async {
    await expectLater(
      _crear(MockClient((_) async => throw http.ClientException('Sin red'))),
      throwsA(
        isA<PedidoException>().having(
          (e) => e.mensaje,
          'mensaje',
          'No pudimos conectarnos con MiMercado+.',
        ),
      ),
    );
  });
  test('crea el pedido con Yape y la dirección guardada', () async {
    final pedido = await _crear(
      MockClient((r) async {
        expect(r.method, 'POST');
        expect(r.url.path, '/api/pedidos/');
        expect(jsonDecode(r.body), {'direccion_id': 3, 'metodo_pago': 'yape'});
        return http.Response(
          jsonEncode({'id': 10, 'codigo': 'MM-10', 'estado': 'pendiente'}),
          201,
        );
      }),
    );
    expect(pedido.id, 10);
    expect(pedido.mercadoId, 2);
    expect(pedido.metodoPago, MetodoPago.yape);
  });
  test(
    'la simulación de la pantalla acepta 123456 y reserva 000000 para rechazos',
    () async {
      final repo = PagoRepositoryMock.instancia;
      expect(
        (await repo.pagarConYape(
          celular: '910023101',
          codigo: '123456',
          monto: 10,
        )).aprobado,
        isTrue,
      );
      expect(
        (await repo.pagarConYape(
          celular: '910023101',
          codigo: '000000',
          monto: 10,
        )).aprobado,
        isFalse,
      );
    },
  );
}
