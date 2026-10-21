import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimercado_frontend/core/router/app_router.dart';
import 'package:mimercado_frontend/data/repositories/canasta_repository.dart';
import 'package:mimercado_frontend/data/repositories/catalogo_repository.dart';
import 'package:mimercado_frontend/data/repositories/pago_repository.dart';
import 'package:mimercado_frontend/data/repositories/pedido_repository.dart';

import 'ayuda_pruebas.dart';

void main() {
  setUp(() => CanastaRepositoryMock.instancia.vaciar());

  testWidgets(
    'C2: María abre Doña Rosa, agrega tomate y la barra muestra el total',
    (tester) async {
      await entrarComo(tester, perfil: 'Cliente', celular: '987654321');
      await tocar(tester, find.text('Doña Rosa Verdulería'));

      expect(find.text('Tomate'), findsOneWidget);

      await tocar(tester, find.text('Agregar 0.5 kg').first);
      await tocar(tester, find.bySemanticsLabel('Agregar 0.5 kg de Tomate'));

      expect(find.text('1 kg'), findsOneWidget);
      expect(find.text('Subtotal S/ 4.00'), findsOneWidget);
      expect(find.text('Ver canasta'), findsOneWidget);
      expect(
        CanastaRepositoryMock.instancia.canasta.value.totalProductos,
        4.00,
      );

      // La Zanahoria está al final de la lista y no se puede comprar.
      await tester.scrollUntilVisible(
        find.text('Agotado por hoy'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Agotado por hoy'), findsOneWidget);
    },
  );

  testWidgets(
    'C3: canasta con 2 puestos, lista de mandado y vaciar con confirmación',
    (tester) async {
      await entrarComo(tester, perfil: 'Cliente', celular: '987654321');
      await tester.runAsync(_llenarCanastaDemo);
      appRouter.go('/canasta');
      await tester.pumpAndSettle();

      expect(find.text('Paso 1 de 3 · Canasta'), findsOneWidget);
      expect(
        find.text('Un solo repartidor recoge en tus 2 puestos'),
        findsOneWidget,
      );
      expect(find.text('Doña Rosa Verdulería'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Total estimado'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('S/ 46.00'), findsOneWidget);

      // C3b · lista de mandado (del puesto que esté en pantalla)
      await tester.scrollUntilVisible(
        find.text('Escribir lista de mandado').first,
        -300,
        scrollable: find.byType(Scrollable).last,
      );
      await tocar(tester, find.text('Escribir lista de mandado').first);
      await tester.enterText(
        find.byType(TextField).last,
        '3 ajíes bien frescos',
      );
      await tocar(tester, find.text('Guardar lista'));
      expect(find.text('Lista de mandado guardada.'), findsOneWidget);
      expect(
        CanastaRepositoryMock.instancia.canasta.value.grupos.map(
          (g) => g.listaMandado,
        ),
        contains('3 ajíes bien frescos'),
      );

      // Vaciar pide confirmación
      await tester.pump(const Duration(seconds: 5)); // se va el aviso de abajo
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Vaciar canasta'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tocar(tester, find.text('Vaciar canasta'));
      expect(find.text('¿Vaciar tu canasta?'), findsOneWidget);
      await tocar(tester, find.text('Sí, vaciar'));
      expect(find.text('Tu canasta está vacía'), findsOneWidget);
    },
  );

  test(
    'Yape simulado: 000000 se rechaza y un código de 6 números se aprueba',
    () async {
      final pagos = PagoRepositoryMock.instancia;
      final malo = await pagos.pagarConYape(
        celular: '987654321',
        codigo: '000000',
        monto: 46,
      );
      expect(malo.aprobado, isFalse);
      expect(malo.mensaje, contains('Genera uno nuevo en Yape'));
      expect(pagos.validarCodigoYape('123'), 'El código debe tener 6 números.');
      final bueno = await pagos.pagarConYape(
        celular: '987654321',
        codigo: '482913',
        monto: 46,
      );
      expect(bueno.aprobado, isTrue);
    },
  );

  testWidgets(
    'C4 → C4b → C4c: paga con Yape (primero falla) y el pedido sale',
    (tester) async {
      await entrarComo(tester, perfil: 'Cliente', celular: '987654321');
      await tester.runAsync(_llenarCanastaDemo);
      appRouter.go('/canasta/entrega');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1)); // carga la dirección
      await tester.pumpAndSettle();

      expect(find.text('Av. Las Flores 245, San Isidro'), findsOneWidget);
      await tocar(tester, find.text('Yape'));
      await tocar(tester, find.text('Continuar con Yape'));
      expect(find.text('Así se hace, en 3 pasos'), findsOneWidget);

      await escribir(tester, 'Código de aprobación (6 números)', '000000');
      await tocar(tester, find.text('Confirmar y pagar'), espera: 2000);
      expect(find.textContaining('Genera uno nuevo en Yape'), findsOneWidget);
      expect(CanastaRepositoryMock.instancia.canasta.value.vacia, isFalse);

      await escribir(tester, 'Código de aprobación (6 números)', '482913');
      await tocar(tester, find.text('Confirmar y pagar'), espera: 3000);
      expect(find.text('¡Pedido enviado!'), findsOneWidget);
      expect(
        find.textContaining('Tu pedido ya llegó a tus caseros'),
        findsOneWidget,
      );
      expect(find.textContaining('#345-A'), findsNothing);
      expect(CanastaRepositoryMock.instancia.canasta.value.vacia, isTrue);

      final p = await tester.runAsync(
        () => PedidoRepositoryMock.instancia.pedidoActivoCliente('987654321'),
      );
      expect(p!.totalEstimado, 46.00);
      expect(p.puestos.first.listaMandado, isNull);
    },
  );
}

/// El pedido de la demo: S/ 41.00 en productos + S/ 5.00 de envío.
Future<void> _llenarCanastaDemo() async {
  final cat = CatalogoRepositoryMock();
  final canasta = CanastaRepositoryMock.instancia;
  final rosa = (await cat.puesto(1))!;
  final carne = (await cat.puesto(3))!;
  final r = {for (final p in await cat.productosDePuesto(1)) p.nombre: p};
  final c = {for (final p in await cat.productosDePuesto(3)) p.nombre: p};
  await canasta.cambiarCantidad(rosa, r['Tomate']!, 1);
  await canasta.cambiarCantidad(rosa, r['Papa amarilla']!, 2);
  await canasta.cambiarCantidad(rosa, r['Limón']!, 0.5);
  await canasta.cambiarCantidad(carne, c['Pollo entero']!, 1.5);
  await canasta.cambiarCantidad(carne, c['Carne molida']!, 0.5);
}
