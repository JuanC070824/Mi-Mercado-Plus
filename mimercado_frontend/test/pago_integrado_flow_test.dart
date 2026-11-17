import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimercado_frontend/core/config/api_config.dart';
import 'package:mimercado_frontend/data/models/pedido.dart';
import 'package:mimercado_frontend/data/models/repartidor.dart';
import 'package:mimercado_frontend/data/models/rol.dart';
import 'package:mimercado_frontend/data/models/usuario.dart';
import 'package:mimercado_frontend/data/repositories/mercadopago_api_repository.dart';
import 'package:mimercado_frontend/data/repositories/pedidos_api_repository.dart';
import 'package:mimercado_frontend/features/pedido/screens/mi_pedido_screen.dart';
import 'package:mimercado_frontend/features/pedido/widgets/pago_mercadopago_pruebas.dart';
import 'package:mimercado_frontend/features/repartidor/views/repartidor_entrega_view.dart';
import 'helpers/reparto_fixture.dart';

class _Pedidos extends PedidosApiRepository {
  final datos = pedidoRepartoJson(estado: 'en_preparacion')
    ..['pago_aprobado'] = false;
  @override
  Future<Pedido?> pedidoActivoCliente(String celular) async => leer(datos);
  @override
  Future<Repartidor?> repartidorDe(int id) async => null;
}

class _Pagos extends MercadoPagoApiRepository {
  _Pagos(this.pedidos);
  final _Pedidos pedidos;
  bool aprobado = false;
  @override
  Future<Map<String, dynamic>> configuracion() async => {
    'configurado': true,
    'entorno': 'prueba',
  };
  @override
  Future<Map<String, dynamic>> confirmar(int id) async {
    if (aprobado) {
      pedidos.datos['pago_aprobado'] = true;
      pedidos.datos['pago_proveedor'] = 'mercadopago_prueba';
    }
    return {
      'estado': aprobado ? 'processed' : 'sin_iniciar',
      'aprobado_en_proveedor': aprobado,
      'pago_interno_aprobado': aprobado,
    };
  }

  @override
  Future<Map<String, dynamic>> crearCheckout(int id) async => {
    'estado': 'created',
    'aprobado_en_proveedor': false,
    'checkout_url':
        'https://www.mercadopago.com.pe/checkout/v1/redirect?order_id=ORDTST01KS5AJ6HTK2HRQ3XJ3C2JCKP9',
  };
}

void main() {
  testWidgets(
    'el pago online ocupa un paso antes del seguimiento y desaparece al aprobarse',
    (tester) async {
      final pedidos = _Pedidos();
      final pagos = _Pagos(pedidos);
      await tester.pumpWidget(
        MaterialApp(
          home: MiPedidoScreen(
            usuario: const Usuario(
              nombres: 'María',
              celular: '900000001',
              rol: Rol.cliente,
            ),
            repository: pedidos,
            pagosRepository: pagos,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Paso 3 · Paga tu pedido'), findsOneWidget);
      expect(find.text('Tu repartidor'), findsNothing);
      expect(find.text('Pagar S/ 13.00'), findsOneWidget);
      pagos.aprobado = true;
      final verificar = find.text('Ya pagué, verificar');
      await tester.ensureVisible(verificar);
      await tester.tap(verificar);
      await tester.pumpAndSettle();
      expect(find.text('Paso 3 · Paga tu pedido'), findsNothing);
      expect(find.text('Tu repartidor'), findsOneWidget);
      expect(find.text('Pago confirmado con Mercado Pago'), findsOneWidget);
    },
    skip: !ApiConfig.configurada || !PagoMercadoPagoPruebas.habilitado,
  );

  testWidgets(
    'Plin al recibir exige marcar el cobro antes de confirmar entrega',
    (tester) async {
      final datos = pedidoRepartoJson(estado: 'en_camino', metodo: 'plin');
      final pedido = PedidosApiRepository().leer(datos);
      final codigo = TextEditingController(text: '1234');
      var cobrado = false;
      var confirmaciones = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, cambiar) => RepartidorEntregaView(
                  pedido: pedido,
                  datos: datos,
                  ocupado: false,
                  llegue: true,
                  efectivo: cobrado,
                  codigo: codigo,
                  alCambiarEfectivo: (v) => cambiar(() => cobrado = v),
                  alLlegar: () {},
                  alVolverALlegada: () {},
                  alConfirmar: () => confirmaciones++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final boton = find.widgetWithText(FilledButton, 'Confirmar entrega');
      expect(tester.widget<FilledButton>(boton).onPressed, isNull);
      await tester.tap(find.text('Recibí S/ 13.00 por Plin'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(boton).onPressed, isNotNull);
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      expect(confirmaciones, 1);
      await tester.pumpWidget(const SizedBox());
      codigo.dispose();
    },
  );
}
