import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../data/models/pedido.dart';
import '../../../data/models/usuario.dart';
import '../../../data/repositories/pedido_repository.dart';
import '../../../data/repositories/pedidos_api_repository.dart';
import '../../casero/widgets/encabezado_pedido_casero.dart';
import '../views/repartidor_entrega_view.dart';
import '../views/repartidor_ganancias_view.dart';
import '../views/repartidor_inicio_view.dart';
import '../views/repartidor_ruta_view.dart';
import '../views/repartidor_sin_mercado_view.dart';
import '../widgets/dialogos_repartidor.dart';
import '../widgets/mercado_repartidor.dart';
import '../widgets/piezas_repartidor.dart';

/// Flujo conectado al servidor. No muestra pedidos ni distancias inventados.
/// Esta pantalla solo carga, refresca y ejecuta acciones; cada vista dibuja.
class RepartidorOperacionesScreen extends StatefulWidget {
  const RepartidorOperacionesScreen({
    super.key,
    required this.usuario,
    this.vista = 'inicio',
    this.repository,
  });
  final Usuario usuario;
  final String vista;
  final PedidosApiRepository? repository;
  @override
  State<RepartidorOperacionesScreen> createState() =>
      _RepartidorOperacionesScreenState();
}

class _RepartidorOperacionesScreenState
    extends State<RepartidorOperacionesScreen>
    with WidgetsBindingObserver {
  late final _repo = widget.repository ?? PedidosApiRepository.instancia;
  final _scroll = ScrollController();
  final _codigo = TextEditingController();
  Timer? _timer;
  Map<String, dynamic>? _inicio;
  bool _cargando = true,
      _leyendo = false,
      _ocupado = false,
      _dialogo = false,
      _efectivo = false;
  bool _enPrimerPlano = true;
  String? _error;
  final _avisados = <int>{};
  // Pedidos con el aviso de llegada enviado en esta sesión (paso 2 de entrega).
  final _llegados = <int>{};
  bool _verLlegada = false;
  bool get _visible =>
      mounted &&
      _enPrimerPlano &&
      TickerMode.valuesOf(context).enabled &&
      (ModalRoute.of(context)?.isCurrent ?? false);
  Pedido? get _actual => _inicio?['en_curso'] is Map
      ? _repo.leer(Map<String, dynamic>.from(_inicio!['en_curso']))
      : null;
  List<Pedido> get _ofertas => [
    for (final j in _inicio?['ofertas'] as List? ?? [])
      _repo.leer(Map<String, dynamic>.from(j)),
  ];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repo.cambios.addListener(_cambio);
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_visible && !_ocupado && !_dialogo) _cargar();
    });
    _cargar();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _enPrimerPlano = state == AppLifecycleState.resumed;
    if (_enPrimerPlano && _visible && !_ocupado && !_dialogo) _cargar();
  }

  void _cambio() {
    if (_visible && !_ocupado && !_dialogo) _cargar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _repo.cambios.removeListener(_cambio);
    _timer?.cancel();
    _scroll.dispose();
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    if (_leyendo) return;
    _leyendo = true;
    try {
      final data = await _repo.inicioRepartidor();
      if (!mounted) return;
      setState(() {
        _inicio = data;
        _cargando = false;
        _error = null;
      });
      if (widget.vista == 'inicio' &&
          _visible &&
          !_ocupado &&
          !_dialogo &&
          data['en_curso'] == null) {
        final ofertas = data['ofertas'] as List? ?? [];
        final nueva = ofertas
            .where((p) => !_avisados.contains(p['id']))
            .firstOrNull;
        if (nueva != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_visible && !_dialogo && !_ocupado) {
              _oferta(
                _repo.leer(Map<String, dynamic>.from(nueva)),
                automatica: true,
              );
            }
          });
        }
      }
    } on PedidoException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.mensaje;
          _cargando = false;
        });
      }
    } finally {
      _leyendo = false;
    }
  }

  Future<void> _hacer(Future<void> Function() accion, {String? mensaje}) async {
    if (_ocupado || _leyendo) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await accion();
      if (!mounted) return;
      await _cargar();
      if (mounted && mensaje != null) avisar(context, mensaje);
    } on PedidoException catch (e) {
      if (mounted) {
        setState(() => _error = e.mensaje);
        FocusScope.of(context).unfocus();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
        });
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /// Abre un diálogo sin que la recarga automática abra otro encima.
  Future<T?> _enDialogo<T>(Future<T> Function() abrir) async {
    if (_dialogo) return null;
    _dialogo = true;
    try {
      return await abrir();
    } finally {
      _dialogo = false;
    }
  }

  Future<void> _oferta(Pedido pedido, {bool automatica = false}) async {
    if (_dialogo || _ocupado) return;
    _avisados.add(pedido.id);
    if (automatica) {
      if (_inicio?['sonido'] == true) {
        SystemSound.play(SystemSoundType.alert).catchError((_) {});
      }
      if (_inicio?['vibracion'] == true) {
        HapticFeedback.heavyImpact().catchError((_) {});
      }
    }
    final aceptar = await _enDialogo(
      () => mostrarOfertaRepartidor(
        context,
        pedido: pedido,
        datos: _repo.datosDe(pedido.id),
      ),
    );
    if (aceptar != true || !mounted) return;
    await _hacer(() => _repo.aceptarEntrega(pedido.id, widget.usuario.celular));
    if (mounted && _actual?.id == pedido.id) context.go('/repartidor/ruta');
  }

  Future<bool> _confirmar(String titulo, String texto) async =>
      await _enDialogo(() => confirmarRepartidor(context, titulo, texto)) ??
      false;

  Future<void> _confirmarRecojo(Pedido p, PedidoPuesto pp) async {
    if (await _confirmar(
          'Confirmar recojo',
          '¿Tienes la bolsa de ${pp.puesto.nombre} para ${p.clienteNombre}?',
        ) &&
        mounted) {
      await _hacer(() => _repo.accionRepartidor(p.id, 'recoger', parte: pp.id));
    }
  }

  Future<void> _salir(Pedido p) async {
    await _hacer(() => _repo.accionRepartidor(p.id, 'salir'));
    if (mounted && _actual?.estado == EstadoPedido.enCamino) {
      context.go('/repartidor/ruta/entrega');
    }
  }

  Future<void> _completar(Pedido p) async {
    if (_ocupado) return;
    if (!RegExp(r'^\d{4}$').hasMatch(_codigo.text.trim())) {
      setState(
        () => _error = 'Escribe los 4 números que te indica el cliente.',
      );
      return;
    }
    if (!await _confirmar(
          'Confirmar pedido entregado',
          'Confirma después de entregar todas las bolsas a ${p.clienteNombre}.',
        ) ||
        !mounted) {
      return;
    }
    final codigo = _codigo.text.trim();
    bool exito = false;
    await _hacer(() async {
      await _repo.entregar(p.id, codigo, efectivo: _efectivo);
      exito = true;
    });
    if (!mounted || !exito) return;
    _codigo.clear();
    await _enDialogo(
      () => mostrarEntregado(context, gananciaDe(_repo.datosDe(p.id))),
    );
    if (mounted) context.go('/repartidor/inicio');
  }

  /// El aviso de llegada queda en el historial del pedido en el servidor.
  bool _yaLlegue(Pedido p) =>
      _llegados.contains(p.id) ||
      p.historial.any((e) => e.texto.contains('llegó a tu dirección'));

  Future<void> _llegar(Pedido p) async {
    await _hacer(() async {
      await _repo.avisarLlegada(p.id);
      _llegados.add(p.id);
      _verLlegada = false;
    }, mensaje: 'El cliente puede ver que llegaste.');
  }

  Widget _vista() {
    final inicio = _inicio;
    if (inicio == null) {
      return AvisoPantalla(
        icono: Icons.wifi_off,
        titulo: 'No pudimos cargar tus pedidos',
        texto: 'Revisa tu conexión.',
        textoBoton: 'Reintentar',
        alTocar: _ocupado || _leyendo ? null : _cargar,
      );
    }
    if (inicio['autorizado'] != true) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TarjetaApp(child: MercadoRepartidor(datos: inicio)),
          const SizedBox(height: 8),
          RepartidorSinMercadoView(
            inicio: inicio,
            ocupado: _ocupado,
            alSolicitar: (mercado, movilidad, placa, descripcion) => _hacer(
              () => _repo.solicitarMercado(
                mercado,
                movilidad,
                placa,
                descripcion: descripcion,
              ),
              mensaje:
                  'Solicitud registrada. Espera la autorización de tu mercado.',
            ),
          ),
        ],
      );
    }
    if (widget.vista == 'ganancias') {
      return RepartidorGananciasView(inicio: inicio);
    }
    final actual = _actual;
    if (widget.vista == 'inicio') {
      return RepartidorInicioView(
        inicio: inicio,
        actual: actual,
        ofertas: _ofertas,
        datosDe: _repo.datosDe,
        ocupado: _ocupado,
        alCambiarDisponible: (v) => _hacer(() => _repo.disponibilidad(v)),
        alVerOferta: _oferta,
        alContinuar: () => context.go(
          actual?.estado == EstadoPedido.enCamino
              ? '/repartidor/ruta/entrega'
              : '/repartidor/ruta',
        ),
      );
    }
    if (actual == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AvisoPantalla(
            icono: Icons.route_outlined,
            titulo: 'No tienes una entrega en curso',
            texto: 'Acepta un pedido en Inicio para ver tu ruta.',
          ),
          AccionRepartidor(
            'Ver pedidos',
            () => context.go('/repartidor/inicio'),
            ocupado: _ocupado,
          ),
        ],
      );
    }
    if (widget.vista == 'entrega') {
      return RepartidorEntregaView(
        pedido: actual,
        datos: _repo.datosDe(actual.id),
        ocupado: _ocupado,
        llegue: _yaLlegue(actual) && !_verLlegada,
        efectivo: _efectivo,
        codigo: _codigo,
        alCambiarEfectivo: (v) => setState(() => _efectivo = v),
        alLlegar: () => _llegar(actual),
        alVolverALlegada: () => setState(() => _verLlegada = true),
        alConfirmar: () => _completar(actual),
      );
    }
    return RepartidorRutaView(
      pedido: actual,
      ocupado: _ocupado,
      alRecoger: (pp) => _confirmarRecojo(actual, pp),
      alAvisar: () => _hacer(
        () => _repo.accionRepartidor(actual.id, 'recogiendo'),
        mensaje: 'El aviso quedó en el seguimiento del cliente.',
      ),
      alSalir: () => _salir(actual),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_ocupado,
    child: Scaffold(
      body: Column(
        children: [
          EncabezadoPedidoCasero(
            titulo: switch (widget.vista) {
              'ruta' => 'Ruta de recojo',
              'entrega' => 'Entregar al cliente',
              'ganancias' => 'Mis ganancias',
              _ => 'Hola, ${widget.usuario.nombres.split(' ').first}',
            },
            subtitulo: _inicio?['mercado']?['nombre']?.toString(),
            mostrarAtras: false,
          ),
          Expanded(
            child: _cargando
                ? const CargandoApp()
                : RefreshIndicator(
                    onRefresh: _cargar,
                    child: ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if (_ocupado)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: LinearProgressIndicator(
                              semanticsLabel: 'Guardando y comprobando…',
                            ),
                          ),
                        if (_error != null) ...[
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                fontSize: 18,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _vista(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}
