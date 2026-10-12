import 'package:flutter_test/flutter_test.dart';
import 'package:mimercado_frontend/data/models/producto.dart';
import 'package:mimercado_frontend/data/repositories/catalogo_repository.dart';

void main() {
  final repo = CatalogoRepositoryMock();

  test('puesto() encuentra a Doña Rosa y devuelve null si no existe', () async {
    expect((await repo.puesto(1))?.nombre, 'Doña Rosa Verdulería');
    expect(await repo.puesto(999), isNull);
  });

  test('productos de Doña Rosa: disponibles primero y Zanahoria agotada al final',
      () async {
    final lista = await repo.productosDePuesto(1);
    expect(lista, isNotEmpty);
    expect(lista.every((p) => p.puestoId == 1), isTrue);
    expect(lista.last.nombre, 'Zanahoria');
    expect(lista.last.disponible, isFalse);
  });

  test('el pedido de la demo #345-A suma S/ 46.00 con los precios del catálogo',
      () async {
    final rosa = {for (final p in await repo.productosDePuesto(1)) p.nombre: p};
    final carne = {for (final p in await repo.productosDePuesto(3)) p.nombre: p};
    final total = 1 * rosa['Tomate']!.precioUnitario +
        2 * rosa['Papa amarilla']!.precioUnitario +
        0.5 * rosa['Limón']!.precioUnitario +
        1.5 * carne['Pollo entero']!.precioUnitario +
        0.5 * carne['Carne molida']!.precioUnitario +
        5.00; // envío
    expect(total, closeTo(46.00, 0.001));
  });

  test('actualizarProducto lo ven otras instancias del repositorio', () async {
    final tomate =
        (await repo.productosDePuesto(1)).firstWhere((p) => p.id == 101);
    await repo.actualizarProducto(tomate.copyWith(disponible: false));
    final otra = await CatalogoRepositoryMock().productosDePuesto(1);
    expect(otra.firstWhere((p) => p.id == 101).disponible, isFalse);
    await repo.actualizarProducto(tomate); // dejarlo como estaba
  });

  test('actualizarProducto con un id desconocido da un error claro', () async {
    const fantasma = Producto(
      id: 9999,
      puestoId: 1,
      nombre: 'Fantasma',
      unidad: UnidadMedida.kg,
      precioUnitario: 1,
    );
    expect(repo.actualizarProducto(fantasma),
        throwsA(isA<CatalogoException>()));
  });
}
