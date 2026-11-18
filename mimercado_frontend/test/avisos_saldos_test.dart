import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimercado_frontend/core/widgets/aviso_pago_pedido.dart';
import 'package:mimercado_frontend/features/repartidor/views/repartidor_ganancias_view.dart';
import 'package:mimercado_frontend/features/pedido/widgets/pago_mercadopago_pruebas.dart';

void main() {
  test('Mercado Pago está habilitado por defecto', () {
    expect(PagoMercadoPagoPruebas.habilitado, isTrue);
  });

  testWidgets(
    'solo muestra un pago confirmado y explica la ganancia pendiente',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvisoPagoPedido(
              datos: {'pago_confirmado': true, 'pago_metodo': 'Mercado Pago'},
              ganancia: 350,
            ),
          ),
        ),
      );
      expect(find.text('Pago confirmado · Mercado Pago'), findsOneWidget);
      expect(find.textContaining('S/ 3.50'), findsOneWidget);
      expect(find.textContaining('al completar la entrega'), findsOneWidget);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvisoPagoPedido(datos: {'pago_confirmado': false}),
          ),
        ),
      );
      expect(find.textContaining('Pago confirmado'), findsNothing);
    },
  );

  testWidgets('distingue la ganancia de hoy del acumulado', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RepartidorGananciasView(
              inicio: {
                'entregas_hoy': 1,
                'ganancia_hoy_centavos': 350,
                'ganancia_acumulada_centavos': 1050,
              },
            ),
          ),
        ),
      ),
    );
    expect(find.text('Ganaste S/ 3.50'), findsOneWidget);
    expect(find.text('S/ 10.50'), findsOneWidget);
    expect(find.text('Ganancias acumuladas'), findsOneWidget);
  });
}
