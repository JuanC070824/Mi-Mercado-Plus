import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimercado_frontend/data/models/pedido.dart';
import 'package:mimercado_frontend/data/repositories/pedido_repository.dart';
import 'package:mimercado_frontend/features/pedido/widgets/etapas_pedido.dart';

Future<void> _mostrar(
  WidgetTester tester,
  Pedido pedido, {
  required bool enLinea,
  bool pagado = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: EtapasPedido(
          pedido: pedido,
          pagoEnLinea: enLinea,
          pagado: pagado,
        ),
      ),
    ),
  );
}

void main() {
  late Pedido pedido;
  setUpAll(() async {
    // Pedido de la demo #345-A: los caseros aún no dan el precio final.
    pedido = (await PedidoRepositoryMock.instancia.pedidosCliente(
      '987654321',
    )).firstWhere((p) => p.id == 345);
  });

  testWidgets('marca lo hecho, el paso de ahora y lo que falta', (
    tester,
  ) async {
    await _mostrar(tester, pedido, enLinea: true);
    expect(find.text('Pedido enviado'), findsOneWidget);
    expect(find.text('Pagas tu pedido'), findsOneWidget);
    expect(find.text('ESTÁS AQUÍ'), findsOneWidget);
    // El paso actual es el precio: el lector de pantalla lo anuncia.
    expect(
      find.bySemanticsLabel(
        'Paso 2 de 5: Caseros pesan y dan el precio, ahora',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Paso 1 de 5: Pedido enviado, listo'),
      findsOneWidget,
    );
  });

  testWidgets('sin pago en línea no muestra el paso de pagar', (tester) async {
    await _mostrar(tester, pedido, enLinea: false);
    expect(find.text('Pagas tu pedido'), findsNothing);
    expect(
      find.bySemanticsLabel('Paso 4 de 4: Entregado, falta'),
      findsOneWidget,
    );
  });
}
