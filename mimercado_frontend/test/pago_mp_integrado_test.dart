import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimercado_frontend/data/repositories/mercadopago_api_repository.dart';
import 'package:mimercado_frontend/data/repositories/pedidos_api_repository.dart';
import 'package:mimercado_frontend/data/repositories/pedido_repository.dart';
import 'package:mimercado_frontend/features/pedido/widgets/pago_mp_integrado.dart';
import 'package:mimercado_frontend/features/pedido/widgets/formulario_mp.dart';
import 'helpers/reparto_fixture.dart';

class _Repo extends MercadoPagoApiRepository {
  bool clave = true, errorRed = false, pendiente = false;
  int pagos = 0;
  Map<String, dynamic> resultado = {
    'estado': 'sin_iniciar',
    'pago_interno_aprobado': false,
  };
  @override
  Future<Map<String, dynamic>> configuracion() async => {
    'configurado': true,
    'entorno': 'prueba',
    'integrado_configurado': clave,
    'public_key': 'APP_USR-publica-ficticia',
  };
  @override
  Future<Map<String, dynamic>> confirmar(int id) async => resultado;
  @override
  Future<Map<String, dynamic>> pagarIntegrado(
    int id,
    Map<String, dynamic> datos,
  ) async {
    pagos++;
    if (errorRed) {
      resultado = {'estado': 'processing', 'pago_interno_aprobado': false};
      throw const PedidoException('No se pudo verificar la respuesta.');
    }
    resultado = {
      'estado': pendiente ? 'processing' : 'processed',
      'pago_interno_aprobado': !pendiente,
    };
    return resultado;
  }
}

Future<void> abrir(
  WidgetTester tester,
  _Repo repo, {
  VoidCallback? alConfirmar,
}) async {
  final pedido = PedidosApiRepository().leer(
    pedidoRepartoJson(estado: 'en_preparacion'),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PagoMpIntegrado(
            pedido: pedido,
            repository: repo,
            alConfirmarPago: alConfirmar,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'muestra el formulario en el pedido y confirma sin abrir enlaces',
    (tester) async {
      final repo = _Repo();
      int avisos = 0;
      await abrir(tester, repo, alConfirmar: () => avisos++);
      expect(find.byType(FormularioMp), findsOneWidget);
      expect(find.text('Copiar enlace de pago'), findsNothing);
      final form = tester.widget<FormularioMp>(find.byType(FormularioMp));
      final result = await form.alPagar({'token': 'ficticio'});
      await tester.pumpAndSettle();
      expect(result['approved'], isTrue);
      expect(repo.pagos, 1);
      expect(avisos, 1);
      expect(find.byType(FormularioMp), findsNothing);
      await form.alPagar({'token': 'otro_ficticio'});
      expect(repo.pagos, 1);
    },
  );

  testWidgets(
    'una respuesta incierta retira el formulario y evita otro cobro',
    (tester) async {
      final repo = _Repo()..errorRed = true;
      await abrir(tester, repo);
      final form = tester.widget<FormularioMp>(find.byType(FormularioMp));
      final result = await form.alPagar({'token': 'ficticio'});
      await tester.pumpAndSettle();
      expect(result['retry'], isFalse);
      expect(find.byType(FormularioMp), findsNothing);
      expect(find.textContaining('No vuelvas a pagar'), findsOneWidget);
      await form.alPagar({'token': 'otro_ficticio'});
      expect(repo.pagos, 1);
    },
  );

  testWidgets('sin Public Key explica qué falta y no genera un checkout', (
    tester,
  ) async {
    final repo = _Repo()..clave = false;
    await abrir(tester, repo);
    expect(find.byType(FormularioMp), findsNothing);
    expect(
      find.textContaining('El pago en línea no está disponible'),
      findsOneWidget,
    );
    expect(repo.pagos, 0);
  });
}
