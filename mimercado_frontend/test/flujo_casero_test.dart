import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimercado_frontend/data/models/direccion.dart';
import 'package:mimercado_frontend/data/models/pedido.dart';
import 'package:mimercado_frontend/data/models/producto.dart';
import 'package:mimercado_frontend/data/repositories/catalogo_repository.dart';
import 'package:mimercado_frontend/data/repositories/pedido_repository.dart';

import 'ayuda_pruebas.dart';

/// Parte de Doña Rosa (puesto 1) en el pedido de la demo #345-A.
Future<PedidoPuesto> _parteRosa(WidgetTester tester) async {
  final lista = await tester.runAsync(
      () => PedidoRepositoryMock.instancia.pedidosDePuesto(1));
  return lista!.firstWhere((p) => p.id == 345).parteDePuesto(1)!;
}

void main() {
  testWidgets('V1 → V1b: Rosa ve la alerta del pedido #345-A y lo acepta',
      (tester) async {
    await entrarComo(tester, perfil: 'Comerciante', celular: '912345678');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('¡NUEVO PEDIDO!'), findsOneWidget);
    expect(find.textContaining('Pedido compartido con Carnicería Huancayo'),
        findsOneWidget);
    await tocar(tester, find.text('Aceptar pedido'));

    expect(find.text('Pedido #345-A'), findsOneWidget);
    expect((await _parteRosa(tester)).estado, EstadoPedidoPuesto.aceptado);
  });

  testWidgets('V1: el interruptor cierra el puesto para los clientes',
      (tester) async {
    await entrarComo(tester, perfil: 'Comerciante', celular: '912345678');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    if (find.text('Verlo después').evaluate().isNotEmpty) {
      await tocar(tester, find.text('Verlo después'));
    }
    await tocar(tester, find.text('Puesto abierto'));
    expect(find.text('Puesto cerrado'), findsOneWidget);
    final p = await tester.runAsync(() => CatalogoRepositoryMock().puesto(1));
    expect(p!.abierto, isFalse);
    await tocar(tester, find.text('Puesto cerrado')); // lo deja abierto
  });

  testWidgets('V1b → V1c: Rosa rechaza un pedido nuevo eligiendo el motivo',
      (tester) async {
    // Otro cliente le pide a Rosa mientras ella no está en la app.
    final nuevo = await tester.runAsync(() async {
      final rosa = (await CatalogoRepositoryMock().puesto(1))!;
      return PedidoRepositoryMock.instancia.crearPedido(
        clienteNombre: 'Jorge',
        clienteCelular: '976543210',
        direccion: const Direccion(direccion: 'Jr. Los Pinos 120'),
        metodo: MetodoPago.efectivo,
        puestos: [
          SolicitudPuesto(puesto: rosa, items: const [
            SolicitudItem(
                nombre: 'Tomate', unidad: UnidadMedida.kg, cantidad: 1, precioUnitario: 4),
          ]),
        ],
      );
    });
    await entrarComo(tester, perfil: 'Comerciante', celular: '912345678');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Puede salir primero la alerta del #345-A: se deja para después.
    while (find.textContaining('#${nuevo!.codigoCorto}').evaluate().isEmpty &&
        find.text('Verlo después').evaluate().isNotEmpty) {
      await tocar(tester, find.text('Verlo después'));
    }
    expect(find.text('¡NUEVO PEDIDO!'), findsOneWidget);
    await tocar(tester, find.text('Rechazar'));
    expect(find.text('¿Por qué no puedes atenderlo?'), findsOneWidget);
    await tocar(tester, find.text(MotivoRechazo.cerrando.etiqueta));
    await tocar(tester, find.text('Sí, rechazar pedido'));

    final lista = await tester.runAsync(
        () => PedidoRepositoryMock.instancia.pedidosDePuesto(1));
    final parte = lista!.firstWhere((p) => p.id == nuevo.id).parteDePuesto(1)!;
    expect(parte.estado, EstadoPedidoPuesto.rechazado);
    expect(parte.motivoRechazo, MotivoRechazo.cerrando.etiqueta);
  });

  testWidgets('V2: Rosa revisa productos tocando Lo tengo → Sin stock',
      (tester) async {
    await tester.runAsync(() async {
      final parte = (await PedidoRepositoryMock.instancia.pedidosDePuesto(1))
          .firstWhere((p) => p.id == 345)
          .parteDePuesto(1)!;
      if (parte.estado == EstadoPedidoPuesto.pendiente) {
        await PedidoRepositoryMock.instancia.aceptarSubpedido(parte.id);
      }
    });
    await entrarComo(tester, perfil: 'Comerciante', celular: '912345678');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    while (find.text('Verlo después').evaluate().isNotEmpty) {
      await tocar(tester, find.text('Verlo después'));
    }
    await tocar(tester, find.textContaining('#345-A'));
    expect(find.text('Pedido compartido'), findsOneWidget);
    await verEnLista(tester, find.text('Revisa cada producto'));

    final tomate = find.bySemanticsLabel(RegExp(r'^Tomate, 1 kg'));
    await tocar(tester, tomate);
    expect(find.bySemanticsLabel(RegExp(r'^Tomate, 1 kg: Lo tengo')), findsOneWidget);
    await tocar(tester, tomate);
    expect(find.bySemanticsLabel(RegExp(r'^Tomate, 1 kg: Sin stock')), findsOneWidget);
    await tocar(tester, tomate);
    await tocar(tester, tomate); // vuelve a "Lo tengo"
    expect((await _parteRosa(tester)).estado, EstadoPedidoPuesto.pesando);
  });

  testWidgets('V3: Rosa pesa el tomate en 1.5 kg y el cliente ve S/ 48.00',
      (tester) async {
    await tester.runAsync(() async {
      final repo = PedidoRepositoryMock.instancia;
      var parte = (await repo.pedidosDePuesto(1))
          .firstWhere((p) => p.id == 345)
          .parteDePuesto(1)!;
      if (parte.estado == EstadoPedidoPuesto.pendiente) {
        await repo.aceptarSubpedido(parte.id);
      }
      for (final d in parte.detalles) {
        await repo.marcarDisponibilidad(d.id, Disponibilidad.disponible);
      }
    });
    await entrarComo(tester, perfil: 'Comerciante', celular: '912345678');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    while (find.text('Verlo después').evaluate().isNotEmpty) {
      await tocar(tester, find.text('Verlo después'));
    }
    await tocar(tester, find.textContaining('#345-A'));
    await tocar(tester, find.text('Pesar y poner precio'));
    expect(find.text('Así lo verá María'), findsNothing); // aún no se ve (scroll)

    await tocar(tester, find.bySemanticsLabel('Agregar 0.5 kg de Tomate'));
    await verEnLista(tester, find.text('Así lo verá María'));
    expect(find.text('S/ 17.00'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Nota para el cliente (opcional)'),
        'el tomate pesó 1.5 kg');
    await verEnLista(tester, find.text('Enviar precio final'));
    await tocar(tester, find.text('Enviar precio final'));

    final p = (await tester.runAsync(
            () => PedidoRepositoryMock.instancia.pedidoActivoCliente('987654321')))!;
    expect(p.estado, EstadoPedido.esperandoConfirmacion);
    expect(p.cotizacion!.totalCliente, 48.00);
    expect(p.cotizacion!.dePuesto(p.parteDePuesto(1)!.id)!.nota, 'el tomate pesó 1.5 kg');
    expect(find.text('Lo que pesaste'), findsOneWidget); // ya no pide pesar
  });
}
