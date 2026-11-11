import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mimercado_frontend/core/state/sesion_state.dart';
import 'package:mimercado_frontend/data/repositories/canasta_api_repository.dart';
import 'package:mimercado_frontend/data/models/producto.dart';
import 'package:mimercado_frontend/data/models/puesto.dart';
import 'package:mimercado_frontend/data/repositories/catalogo_api_repository.dart';
import 'package:mimercado_frontend/features/mercado/widgets/lo_que_siempre_pides.dart';

Map<String, dynamic> _puesto(
  int id,
  String nombre, {
  double calificacion = 0,
}) => {
  'id': id,
  'mercado_id': 3,
  'nombre': nombre,
  'casero': 'Casero',
  'categoria': 'Verduras y frutas',
  'abierto': true,
  'calificacion': calificacion,
  'resenas': 1,
};

void main() {
  tearDown(SesionState.cerrar);

  test(
    'con sesión, "más queridos" son los recomendados para el cliente',
    () async {
      SesionState.iniciar(token: 'tk', expiresIn: 3600);
      late http.Request pedida;
      final repo = CatalogoApiRepository(
        baseUrl: 'http://localhost',
        client: MockClient((r) async {
          pedida = r;
          return http.Response(
            jsonEncode({
              'puestos': [
                _puesto(7, 'Donde más compro'),
                _puesto(2, 'Segundo'),
              ],
              'productos': [],
            }),
            200,
          );
        }),
      );
      final r = await repo.masQueridos(mercadoId: 3);
      expect(r.map((p) => p.nombre), ['Donde más compro', 'Segundo']);
      expect(pedida.url.path, '/api/comprador/recomendaciones/');
      expect(pedida.url.queryParameters, {'mercado_id': '3'});
      expect(pedida.headers['Authorization'], 'Bearer tk');
    },
  );

  test(
    'sin sesión o si falla, usa el orden general por calificación',
    () async {
      final rutas = <String>[];
      final repo = CatalogoApiRepository(
        baseUrl: 'http://localhost',
        client: MockClient((r) async {
          rutas.add(r.url.path);
          if (r.url.path.contains('recomendaciones')) {
            return http.Response('{"detail":"Sin rol comprador"}', 403);
          }
          return http.Response(
            jsonEncode([
              _puesto(1, 'Baja', calificacion: 3),
              _puesto(2, 'Alta', calificacion: 5),
            ]),
            200,
          );
        }),
      );
      expect((await repo.masQueridos()).first.nombre, 'Alta');
      expect(rutas, ['/api/puestos/']);
      SesionState.iniciar(token: 'tk', expiresIn: 3600);
      expect((await repo.masQueridos()).first.nombre, 'Alta');
      expect(rutas.last, '/api/puestos/');
    },
  );

  test('volver a pedir actualiza la canasta y avisa lo que no había', () async {
    SesionState.iniciar(token: 'tk', expiresIn: 3600);
    final repo = CanastaApiRepository(
      baseUrl: 'http://localhost',
      client: MockClient((r) async {
        expect(r.method, 'POST');
        expect(r.url.path, '/api/comprador/pedidos/25/volver-a-pedir/');
        return http.Response(
          jsonEncode({
            'agregados': ['Tomate'],
            'omitidos': ['Pollo'],
            'carrito': {
              'id': 1,
              'mercado_id': 3,
              'puestos': [
                {
                  'puesto_id': 7,
                  'mercado_id': 3,
                  'nombre': 'Verduras Rosa',
                  'abierto': true,
                  'items': [
                    {
                      'id': 9,
                      'producto_id': 101,
                      'nombre': 'Tomate',
                      'unidad': 'kg',
                      'cantidad': '1.000',
                      'precio_unitario_centavos': 400,
                    },
                  ],
                },
              ],
            },
          }),
          200,
        );
      }),
    );
    expect(await repo.volverAPedir(25), ['Pollo']);
    expect(repo.canasta.value.cantidadDe(101), 1);
  });

  test(
    '"lo que siempre pides" trae producto y puesto con una sola llamada',
    () async {
      SesionState.iniciar(token: 'tk', expiresIn: 3600);
      var llamadas = 0;
      final repo = CatalogoApiRepository(
        baseUrl: 'http://localhost',
        client: MockClient((r) async {
          llamadas++;
          return http.Response(
            jsonEncode({
              'puestos': [_puesto(7, 'Rosa')],
              'productos': [
                {
                  'id': 101,
                  'puesto_id': 7,
                  'nombre': 'Tomate',
                  'unidad': 'kg',
                  'precio_unitario_centavos': 400,
                  'disponible': true,
                  'veces': 3,
                  'puesto': _puesto(7, 'Rosa'),
                },
                {'id': 102, 'puesto_id': 9, 'nombre': 'Sin puesto'},
              ],
            }),
            200,
          );
        }),
      );
      final caseros = repo.masQueridos(mercadoId: 3);
      final frecuentes = await repo.loQueSiemprePides(mercadoId: 3);
      expect((await caseros).single.nombre, 'Rosa');
      expect(frecuentes.single.producto.nombre, 'Tomate');
      expect(frecuentes.single.producto.precioUnitario, 4);
      expect(frecuentes.single.puesto.nombre, 'Rosa');
      expect(frecuentes.single.veces, 3);
      expect(llamadas, 1);

      SesionState.cerrar();
      expect(await repo.loQueSiemprePides(), isEmpty);
      expect(llamadas, 1);
    },
  );

  testWidgets('la sección muestra lo frecuente y agrega con un toque', (
    tester,
  ) async {
    const puesto = Puesto(
      id: 7,
      mercadoId: 3,
      nombre: 'Verduras Rosa',
      casero: 'Rosa',
      categoria: CategoriaPuesto.verduras,
      calificacion: 5,
      resenas: 2,
    );
    const tomate = ProductoFrecuente(
      producto: Producto(
        id: 101,
        puestoId: 7,
        nombre: 'Tomate',
        unidad: UnidadMedida.kg,
        precioUnitario: 4,
      ),
      puesto: puesto,
      veces: 3,
    );
    const papa = ProductoFrecuente(
      producto: Producto(
        id: 102,
        puestoId: 7,
        nombre: 'Papa',
        unidad: UnidadMedida.kg,
        precioUnitario: 2,
        disponible: false,
      ),
      puesto: puesto,
      veces: 2,
    );
    ProductoFrecuente? agregado;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoQueSiemprePides(
            productos: const [tomate, papa],
            onAgregar: (f) => agregado = f,
          ),
        ),
      ),
    );
    expect(find.text('Lo que siempre pides'), findsOneWidget);
    expect(find.text('Verduras Rosa · S/ 4.00'), findsOneWidget);
    expect(find.text('Hoy no hay'), findsOneWidget);
    await tester.tap(find.text('Agregar').first);
    expect(agregado, same(tomate));
    await tester.tap(find.text('Agregar').last); // la papa está deshabilitada
    expect(agregado, same(tomate));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoQueSiemprePides(productos: const [], onAgregar: (_) {}),
        ),
      ),
    );
    expect(find.text('Lo que siempre pides'), findsNothing);
  });
}
