import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimercado_frontend/core/router/app_router.dart';
import 'package:mimercado_frontend/data/repositories/catalogo_repository.dart';

import 'ayuda_pruebas.dart';

Future<void> _entrarRosa(WidgetTester tester, String ruta) async {
  await entrarComo(tester, perfil: 'Comerciante', celular: '912345678');
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
  while (find.text('Verlo después').evaluate().isNotEmpty) {
    await tocar(tester, find.text('Verlo después'));
  }
  appRouter.go(ruta);
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('V6: pestañas Nuevos / En curso / Entregados', (tester) async {
    await _entrarRosa(tester, '/casero/pedidos');
    expect(find.text('Nuevos (1)'), findsOneWidget); // #345-A
    expect(find.text('En curso (1)'), findsOneWidget); // #344-B
    await tocar(tester, find.text('En curso (1)'));
    expect(find.textContaining('#344-B'), findsOneWidget);
    await tocar(tester, find.textContaining('Entregados'));
    expect(find.textContaining('#343-A'), findsOneWidget);
  });

  testWidgets('V7: Rosa agota el tomate y cambia el precio del limón', (tester) async {
    await _entrarRosa(tester, '/casero/catalogo');
    await tocar(tester, find.bySemanticsLabel('Tomate: Disponible'));
    expect(find.bySemanticsLabel('Tomate: Agotado'), findsOneWidget);

    await tocar(tester, find.bySemanticsLabel('Cambiar precio de Limón'));
    await tester.enterText(find.byType(TextField).last, '7.50');
    await tocar(tester, find.text('Guardar'));
    expect(find.text('S/ 7.50 / kg'), findsOneWidget);

    final productos = await tester.runAsync(() => CatalogoRepositoryMock().productosDePuesto(1));
    final porNombre = {for (final p in productos!) p.nombre: p};
    expect(porNombre['Tomate']!.disponible, isFalse); // el cliente lo ve agotado
    expect(porNombre['Limón']!.precioUnitario, 7.50);
  });
}
