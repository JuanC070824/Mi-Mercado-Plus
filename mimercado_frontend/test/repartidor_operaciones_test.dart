import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimercado_frontend/core/theme/app_theme.dart';
import 'package:mimercado_frontend/data/models/rol.dart';
import 'package:mimercado_frontend/data/models/usuario.dart';
import 'package:mimercado_frontend/data/repositories/pedidos_api_repository.dart';
import 'package:mimercado_frontend/data/repositories/pedido_repository.dart';
import 'package:mimercado_frontend/features/repartidor/screens/repartidor_operaciones_screen.dart';
import 'package:mimercado_frontend/features/repartidor/widgets/movilidad_repartidor.dart';
import 'package:mimercado_frontend/features/repartidor/widgets/mercado_repartidor.dart';
import 'package:mimercado_frontend/features/pedido/widgets/pago_yape_simulado.dart';
import 'helpers/reparto_fixture.dart';

class _Repo extends PedidosApiRepository {
  _Repo(this.inicio);
  Map<String, dynamic> inicio;
  int recojos = 0, entregas = 0, pagos = 0, solicitudes = 0;
  bool fallo = false;
  String? guardada;
  @override
  Future<Map<String, dynamic>> inicioRepartidor() async => inicio;
  @override
  Future<void> accionRepartidor(int id, String accion, {int? parte}) async {
    if (accion == 'recoger') {
      recojos++;
      (inicio['en_curso']['puestos'] as List).firstWhere(
        (p) => p['id'] == parte,
      )['estado'] = 'recogido';
    }
  }

  @override
  Future<void> entregar(int id, String codigo, {bool efectivo = false}) async {
    entregas++;
    throw const PedidoException(
      'El código no coincide. Pídeselo de nuevo al cliente.',
    );
  }

  @override
  Future<void> cambiarMovilidad(
    String movilidad,
    String placa,
    String descripcion,
  ) async {
    guardada = movilidad;
    inicio['movilidad'] = movilidad;
  }

  @override
  Future<void> solicitarMercado(
    int id,
    String movilidad,
    String placa, {
    String descripcion = '',
  }) async {
    solicitudes++;
  }

  @override
  Future<Map<String, dynamic>> configuracionPago() async => {
    'modo': 'mock',
    'configurado': true,
    'codigo_demostracion': '123456',
  };
  @override
  Future<void> pagarYape(
    int id,
    String celular,
    String codigo, {
    String? correo,
  }) async {
    pagos++;
    if (fallo) {
      throw const PedidoException('Código de demostración incorrecto.');
    }
  }
}

const _usuario = Usuario(
  nombres: 'Ernesto',
  celular: '900000090',
  rol: Rol.repartidor,
);

Future<void> _abrir(
  WidgetTester tester,
  Widget pantalla, {
  double escala = 1,
}) async {
  tester.view.physicalSize = Size(escala == 1 ? 390 : 320, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(
          ctx,
        ).copyWith(textScaler: TextScaler.linear(escala)),
        child: child!,
      ),
      home: pantalla,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _ver(WidgetTester tester, Finder objetivo) async {
  await tester.scrollUntilVisible(
    objetivo,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

FilledButton _boton(WidgetTester tester, String texto) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, texto));

void main() {
  testWidgets('muestra el mercado real y distingue solicitud de autorización', (
    tester,
  ) async {
    await _abrir(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: MercadoRepartidor(datos: inicioRepartoJson()),
        ),
      ),
      escala: 2,
    );
    expect(find.text('Mi mercado asignado'), findsOneWidget);
    expect(find.text('Mercado Santa Rosa'), findsOneWidget);
    expect(find.text('Autorizado para repartir'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _abrir(
      tester,
      const Scaffold(
        body: SingleChildScrollView(
          child: MercadoRepartidor(
            datos: {
              'autorizado': false,
              'pendiente': true,
              'mercado_solicitado': 'Mercado Central',
            },
          ),
        ),
      ),
      escala: 2,
    );
    expect(find.text('Mi mercado solicitado'), findsOneWidget);
    expect(find.text('Mercado Central'), findsOneWidget);
    expect(find.text('Autorización pendiente'), findsOneWidget);
    expect(find.text('Autorizado para repartir'), findsNothing);
    expect(tester.takeException(), isNull);
    await _abrir(
      tester,
      const Scaffold(
        body: MercadoRepartidor(
          datos: {'autorizado': false, 'pendiente': false},
        ),
      ),
    );
    expect(find.text('Sin mercado autorizado'), findsOneWidget);
    expect(find.text('Mercado Central'), findsNothing);
  });
  testWidgets(
    'oferta muestra condiciones y permite salir con teclado sin asignar',
    (tester) async {
      final repo = _Repo(inicioRepartoJson(ofertas: [pedidoRepartoJson()]));
      await _abrir(
        tester,
        RepartidorOperacionesScreen(usuario: _usuario, repository: repo),
        escala: 2,
      );
      expect(find.text('¡Nuevo pedido para recoger!'), findsOneWidget);
      final dialogo = find
          .descendant(
            of: find.byType(Dialog),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Aceptar reparto'),
        180,
        scrollable: dialogo,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('1.2 km'), findsWidgets);
      expect(find.text('Ganas S/ 5.00'), findsWidgets);
      expect(find.textContaining('MM-interno'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(repo.inicio['en_curso'], isNull);
      final semantica = tester.ensureSemantics();
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantica.dispose();
    },
  );
  testWidgets('recojo exige orden y preparación, y solicita confirmación', (
    tester,
  ) async {
    final repo = _Repo(inicioRepartoJson(actual: pedidoRepartoJson()));
    await _abrir(
      tester,
      RepartidorOperacionesScreen(
        usuario: _usuario,
        vista: 'ruta',
        repository: repo,
      ),
    );
    await _ver(tester, find.text('Recogí la bolsa').first);
    final botones = tester
        .widgetList<FilledButton>(
          find.widgetWithText(FilledButton, 'Recogí la bolsa'),
        )
        .toList();
    expect(botones.first.onPressed, isNotNull);
    await tester.tap(find.text('Recogí la bolsa').first);
    await tester.pumpAndSettle();
    expect(repo.recojos, 0);
    await tester.tap(find.text('Sí, confirmar'));
    await tester.pumpAndSettle();
    expect(repo.recojos, 1);
    await _ver(tester, find.text('Ya recogí todo · Ir a entregar'));
    expect(_boton(tester, 'Ya recogí todo · Ir a entregar').onPressed, isNull);
    expect(find.textContaining('MM-interno'), findsNothing);
  });
  testWidgets(
    'efectivo exige confirmar cobro y código erróneo permite corregir',
    (tester) async {
      final repo = _Repo(
        inicioRepartoJson(
          actual: pedidoRepartoJson(
            estado: 'en_camino',
            metodo: 'efectivo',
            estados: ['recogido', 'recogido'],
          ),
        ),
      );
      await _abrir(
        tester,
        RepartidorOperacionesScreen(
          usuario: _usuario,
          vista: 'entrega',
          repository: repo,
        ),
      );
      await _ver(tester, find.text('Confirmar entrega'));
      expect(_boton(tester, 'Confirmar entrega').onPressed, isNull);
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.enterText(
        find.byKey(const ValueKey('codigo_entrega')),
        '0000',
      );
      await _ver(tester, find.text('Confirmar entrega'));
      await tester.tap(find.text('Confirmar entrega'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, confirmar'));
      await tester.pumpAndSettle();
      expect(repo.entregas, 1);
      expect(find.textContaining('El código no coincide'), findsOneWidget);
      await _ver(tester, find.text('Confirmar entrega'));
      expect(_boton(tester, 'Confirmar entrega').onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('ruta en 320 y letra al 200% conserva acciones sin desbordarse', (
    tester,
  ) async {
    final repo = _Repo(inicioRepartoJson(actual: pedidoRepartoJson()));
    await _abrir(
      tester,
      RepartidorOperacionesScreen(
        usuario: _usuario,
        vista: 'ruta',
        repository: repo,
      ),
      escala: 2,
    );
    await _ver(tester, find.text('Ya recogí todo · Ir a entregar'));
    expect(tester.takeException(), isNull);
    final size = tester.getSize(
      find.widgetWithText(FilledButton, 'Ya recogí todo · Ir a entregar'),
    );
    expect(size.height, greaterThanOrEqualTo(48));
    expect(size.width, greaterThanOrEqualTo(48));
  });
  testWidgets('sin autorización permite solicitar mercado y elegir movilidad', (
    tester,
  ) async {
    final repo = _Repo({
      'autorizado': false,
      'pendiente': false,
      'mercados': [
        {'id': 1, 'nombre': 'Santa Rosa'},
      ],
    });
    await _abrir(
      tester,
      RepartidorOperacionesScreen(usuario: _usuario, repository: repo),
      escala: 2,
    );
    await _ver(tester, find.text('Solicitar autorización'));
    expect(_boton(tester, 'Solicitar autorización').onPressed, isNull);
    expect(repo.solicitudes, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('perfil permite elegir moto y bloquea cambios durante reparto', (
    tester,
  ) async {
    final repo = _Repo(inicioRepartoJson());
    await _abrir(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: MovilidadRepartidor(repository: repo),
        ),
      ),
    );
    await tester.tap(find.text('Bicicleta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Moto').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ABC-123');
    await tester.ensureVisible(find.text('Guardar movilidad'));
    await tester.tap(find.text('Guardar movilidad'));
    await tester.pumpAndSettle();
    expect(repo.guardada, 'moto');
    await tester.pumpWidget(const SizedBox());
    repo.inicio = inicioRepartoJson(actual: pedidoRepartoJson());
    await _abrir(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: MovilidadRepartidor(repository: repo),
        ),
      ),
      escala: 2,
    );
    await tester.ensureVisible(find.text('Guardar movilidad'));
    expect(_boton(tester, 'Guardar movilidad').onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('pago local valida formato y permite reintentar tras rechazo', (
    tester,
  ) async {
    final repo = _Repo(inicioRepartoJson())..fallo = true;
    final datos = pedidoRepartoJson()..['pago_aprobado'] = false;
    final pedido = repo.leer(datos);
    await _abrir(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: PagoYapeSimulado(
            pedido: pedido,
            usuario: _usuario,
            repository: repo,
          ),
        ),
      ),
    );
    await _ver(tester, find.text('Confirmar pago de prueba'));
    await tester.tap(find.text('Confirmar pago de prueba'));
    await tester.pumpAndSettle();
    expect(repo.pagos, 0);
    await tester.enterText(find.byKey(const ValueKey('pago_codigo')), '000000');
    await _ver(tester, find.text('Confirmar pago de prueba'));
    await tester.tap(find.text('Confirmar pago de prueba'));
    await tester.pumpAndSettle();
    expect(repo.pagos, 1);
    repo.fallo = false;
    await tester.enterText(find.byKey(const ValueKey('pago_codigo')), '123456');
    await _ver(tester, find.text('Confirmar pago de prueba'));
    await tester.tap(find.text('Confirmar pago de prueba'));
    await tester.pumpAndSettle();
    expect(repo.pagos, 2);
  });
  testWidgets(
    'pago local 320/200% y estado pendiente no permite pagar otra vez',
    (tester) async {
      final repo = _Repo(inicioRepartoJson());
      final datos = pedidoRepartoJson()..['pago_aprobado'] = false;
      final pedido = repo.leer(datos);
      await _abrir(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: PagoYapeSimulado(
              pedido: pedido,
              usuario: _usuario,
              repository: repo,
            ),
          ),
        ),
        escala: 2,
      );
      await _ver(tester, find.text('Confirmar pago de prueba'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      datos['pago_pendiente'] = true;
      repo.leer(datos);
      await _abrir(
        tester,
        Scaffold(
          body: PagoYapeSimulado(
            pedido: pedido,
            usuario: _usuario,
            repository: repo,
          ),
        ),
      );
      expect(find.text('Confirmar pago de prueba'), findsNothing);
      expect(repo.pagos, 0);
    },
  );
}
