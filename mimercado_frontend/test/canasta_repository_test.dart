import 'package:flutter_test/flutter_test.dart';
import 'package:mimercado_frontend/data/models/producto.dart';
import 'package:mimercado_frontend/data/models/puesto.dart';
import 'package:mimercado_frontend/data/repositories/canasta_repository.dart';
import 'package:mimercado_frontend/data/repositories/catalogo_repository.dart';

void main() {
  final canasta = CanastaRepositoryMock.instancia;
  final catalogo = CatalogoRepositoryMock();

  late Puesto rosa;
  late Puesto carniceria;
  late Puesto frutasMary; // mercado 2
  late Puesto granja; // cerrado
  late Map<String, Producto> deRosa;
  late Map<String, Producto> deCarniceria;

  setUpAll(() async {
    rosa = (await catalogo.puesto(1))!;
    carniceria = (await catalogo.puesto(3))!;
    frutasMary = (await catalogo.puesto(7))!;
    granja = (await catalogo.puesto(6))!;
    deRosa = {for (final p in await catalogo.productosDePuesto(1)) p.nombre: p};
    deCarniceria = {
      for (final p in await catalogo.productosDePuesto(3)) p.nombre: p
    };
  });

  setUp(() => canasta.vaciar());

  test('el pedido de la demo #345-A da S/ 46.00 estimado con 2 puestos',
      () async {
    await canasta.cambiarCantidad(rosa, deRosa['Tomate']!, 1);
    await canasta.cambiarCantidad(rosa, deRosa['Papa amarilla']!, 2);
    await canasta.cambiarCantidad(rosa, deRosa['Limón']!, 0.5);
    await canasta.cambiarCantidad(carniceria, deCarniceria['Pollo entero']!, 1.5);
    final c = await canasta.cambiarCantidad(
        carniceria, deCarniceria['Carne molida']!, 0.5);

    expect(c.grupos.length, 2);
    expect(c.grupo(1)!.subtotal, 15.00);
    expect(c.grupo(3)!.subtotal, 26.00);
    expect(c.totalEstimado, 46.00);
    expect(canasta.canasta.value.totalEstimado, 46.00); // la barra se entera
  });

  test('agregar y restar avanzan de 0.5 kg; en 0 el puesto sale de la canasta',
      () async {
    final tomate = deRosa['Tomate']!;
    await canasta.agregar(rosa, tomate);
    var c = await canasta.agregar(rosa, tomate);
    expect(c.cantidadDe(tomate.id), 1.0);
    c = await canasta.restar(tomate);
    expect(c.cantidadDe(tomate.id), 0.5);
    c = await canasta.restar(tomate);
    expect(c.vacia, isTrue);
    expect(c.envio, 0);
  });

  test('el culantro va por atados enteros', () async {
    final c = await canasta.cambiarCantidad(rosa, deRosa['Culantro']!, 2.2);
    expect(c.cantidadDe(deRosa['Culantro']!.id), 2);
  });

  test('no deja mezclar mercados', () async {
    await canasta.agregar(rosa, deRosa['Tomate']!);
    final mandarina = (await catalogo.productosDePuesto(7)).first;
    expect(canasta.agregar(frutasMary, mandarina),
        throwsA(isA<CanastaException>()));
  });

  test('no deja agregar agotados ni de puestos cerrados', () async {
    expect(canasta.agregar(rosa, deRosa['Zanahoria']!),
        throwsA(isA<CanastaException>()));
    final gallina = (await catalogo.productosDePuesto(6)).first;
    expect(canasta.agregar(granja, gallina), throwsA(isA<CanastaException>()));
  });

  test('lista de mandado: se guarda, se borra y pide un producto antes',
      () async {
    expect(canasta.guardarListaMandado(1, 'culantro'),
        throwsA(isA<CanastaException>()));
    await canasta.agregar(rosa, deRosa['Tomate']!);
    var c = await canasta.guardarListaMandado(1, '  3 ajíes bien frescos  ');
    expect(c.grupo(1)!.listaMandado, '3 ajíes bien frescos');
    c = await canasta.guardarListaMandado(1, '');
    expect(c.grupo(1)!.listaMandado, isNull);
  });

  test('quitar respeta el orden de los demás productos', () async {
    await canasta.agregar(rosa, deRosa['Tomate']!);
    await canasta.agregar(rosa, deRosa['Limón']!);
    await canasta.agregar(rosa, deRosa['Cebolla roja']!);
    await canasta.agregar(rosa, deRosa['Limón']!); // sube, no se mueve
    final c = await canasta.quitar(deRosa['Tomate']!.id);
    expect(c.grupo(1)!.items.map((i) => i.producto.nombre),
        ['Limón', 'Cebolla roja']);
  });
}
