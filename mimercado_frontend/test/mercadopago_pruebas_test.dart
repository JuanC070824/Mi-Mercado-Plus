import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mimercado_frontend/core/state/sesion_state.dart';
import 'package:mimercado_frontend/data/repositories/mercadopago_api_repository.dart';
import 'package:mimercado_frontend/data/repositories/pedido_repository.dart';
import 'package:mimercado_frontend/data/repositories/pedidos_api_repository.dart';
import 'package:mimercado_frontend/features/pedido/widgets/pago_mercadopago_pruebas.dart';
import 'helpers/reparto_fixture.dart';

const _url =
    'https://www.mercadopago.com.pe/checkout/v1/redirect?order_id=ORDTST01KS5AJ6HTK2HRQ3XJ3C2JCKP9';

class _Repo extends MercadoPagoApiRepository {
  bool configurado = true, aprobar = false;
  int creaciones = 0;
  @override
  Future<Map<String, dynamic>> configuracion() async => {
    'configurado': configurado,
    'entorno': 'prueba',
  };
  @override
  Future<Map<String, dynamic>> confirmar(int id) async => {
    'estado': aprobar ? 'processed' : 'sin_iniciar',
    'aprobado_en_proveedor': aprobar,
    'pago_interno_aprobado': aprobar,
    'reparto_habilitado': aprobar,
  };
  @override
  Future<Map<String, dynamic>> crearCheckout(int id) async {
    creaciones++;
    return {
      'estado': 'created',
      'checkout_url': _url,
      'aprobado_en_proveedor': false,
    };
  }
}

Future<void> _mostrar(
  WidgetTester tester,
  _Repo repo,
  Future<bool> Function(Uri) abrir,
) async {
  final datos = pedidoRepartoJson(estado: 'en_preparacion')
    ..['pago_aprobado'] = false;
  final pedido = PedidosApiRepository().leer(datos);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PagoMercadoPagoPruebas(
            pedido: pedido,
            repository: repo,
            abrirCheckout: abrir,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(SesionState.cerrar);

  test('solo envía el pedido y usa autenticación de MiMercado+', () async {
    SesionState.iniciar(token: 'sesion-ficticia', expiresIn: 3600);
    final transporte = PedidosApiRepository(
      baseUrl: 'http://localhost:8000',
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/pagos/mercadopago/checkout/');
        expect(request.headers['Authorization'], 'Bearer sesion-ficticia');
        expect(jsonDecode(request.body), {'pedido_id': 25});
        return http.Response(jsonEncode({'checkout_url': _url}), 200);
      }),
    );
    expect(
      (await MercadoPagoApiRepository(
        transporte: transporte,
      ).crearCheckout(25))['checkout_url'],
      _url,
    );
  });

  test('bloquea enlaces ajenos, alterados y orders de producción', () {
    expect(MercadoPagoApiRepository.validarCheckout(_url).scheme, 'https');
    for (final url in [
      _url.replaceFirst('https:', 'http:'),
      _url.replaceFirst('com.pe', 'com.pe.evil.test'),
      _url.replaceFirst('www.', 'usuario@www.'),
      '$_url&order_id=otro',
      _url.replaceFirst('ORDTST', 'ORDPROD'),
    ]) {
      expect(
        () => MercadoPagoApiRepository.validarCheckout(url),
        throwsA(isA<PedidoException>()),
      );
    }
  });

  testWidgets('prepara una vez, abre por clic y confirma el registro interno', (
    tester,
  ) async {
    final repo = _Repo();
    var aperturas = 0;
    await _mostrar(tester, repo, (uri) async {
      expect(uri.toString(), _url);
      aperturas++;
      return true;
    });
    expect(repo.creaciones, 1);
    expect(aperturas, 0);
    await tester.tap(find.text('Pagar S/ 13.00'));
    await tester.pumpAndSettle();
    expect(aperturas, 1);
    expect(repo.creaciones, 1);
    repo.aprobar = true;
    await tester.tap(find.text('Ya pagué, verificar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pago confirmado.'), findsOneWidget);
    expect(
      find.textContaining('Continuamos con la preparación y el reparto'),
      findsOneWidget,
    );
    expect(find.text('Pagar S/ 13.00'), findsNothing);
  });

  testWidgets('configuración incompleta no permite crear checkout', (
    tester,
  ) async {
    final repo = _Repo()..configurado = false;
    await _mostrar(tester, repo, (_) async => true);
    expect(find.text('Continuar al pago'), findsNothing);
    expect(find.textContaining('no está disponible'), findsOneWidget);
    expect(repo.creaciones, 0);
  });
}
