import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../data/models/pedido.dart';
import '../../../data/models/usuario.dart';
import '../../../data/models/repartidor.dart';
import '../../../data/repositories/pedido_repository.dart';
import '../../../data/repositories/pedidos_api_repository.dart';
import '../../casero/widgets/encabezado_pedido_casero.dart';
import '../../casero/widgets/llamar_dialog.dart';
import '../widgets/mercado_repartidor.dart';

/// Flujo conectado al servidor. No muestra pedidos ni distancias inventados.
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
  final _placa = TextEditingController();
  final _descripcion = TextEditingController();
  Timer? _timer;
  Map<String, dynamic>? _inicio;
  bool _cargando = true,
      _leyendo = false,
      _ocupado = false,
      _dialogo = false,
      _efectivo = false;
  bool _enPrimerPlano = true;
  bool _formularioInicializado = false;
  String? _error;
  int? _mercado;
  String _movilidad = 'a_pie';
  final _avisados = <int>{};
  bool get _visible =>
      mounted &&
      _enPrimerPlano &&
      TickerMode.valuesOf(context).enabled &&
      (ModalRoute.of(context)?.isCurrent ?? false);
  Pedido? get _actual => _inicio?['en_curso'] is Map
      ? _repo.leer(Map<String, dynamic>.from(_inicio!['en_curso']))
      : null;
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
    _placa.dispose();
    _descripcion.dispose();
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
        if (!_formularioInicializado) {
          _formularioInicializado = true;
          _movilidad = data['movilidad']?.toString() ?? 'a_pie';
          _placa.text = data['placa']?.toString() ?? '';
          _descripcion.text = data['descripcion_movilidad']?.toString() ?? '';
        }
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

  ButtonStyle get _boton => FilledButton.styleFrom(
    minimumSize: const Size(48, 56),
    padding: const EdgeInsets.all(16),
    backgroundColor: AppColors.azul,
    foregroundColor: AppColors.blanco,
  );
  Widget _accion(String texto, VoidCallback? fn) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: FilledButton(
      style: _boton,
      onPressed: _ocupado ? null : fn,
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
    ),
  );
  Widget _titulo(String texto) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Semantics(
      header: true,
      child: Text(
        texto,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
    ),
  );
  String _ganancia(Pedido p) => soles(
    ((_repo.datosDe(p.id)['ganancia_repartidor_centavos'] as num?) ?? 0)
            .toDouble() /
        100,
  );
  String _distancia(Pedido p) {
    final d = _repo.datosDe(p.id)['distancia_km'];
    return d is num
        ? 'Distancia aproximada: ${d.toStringAsFixed(1)} km en línea recta'
        : 'Distancia no disponible: consulta la dirección de entrega.';
  }

  Future<void> _oferta(Pedido pedido, {bool automatica = false}) async {
    if (_dialogo || _ocupado) return;
    _avisados.add(pedido.id);
    _dialogo = true;
    if (automatica) {
      if (_inicio?['sonido'] == true) {
        SystemSound.play(SystemSoundType.alert).catchError((_) {});
      }
      if (_inicio?['vibracion'] == true) {
        HapticFeedback.heavyImpact().catchError((_) {});
      }
    }
    bool? aceptar;
    try {
      aceptar = await showDialog<bool>(
        context: context,
        builder: (ctx) => Dialog(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.delivery_dining,
                  size: 48,
                  color: AppColors.azul,
                ),
                _titulo('¡Nuevo pedido para recoger!'),
                Text(
                  'Cliente: ${pedido.clienteNombre}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                _titulo('Recoges en ${pedido.puestosActivos.length} puestos'),
                for (final parte in pedido.puestosActivos)
                  Text(
                    '${parte.parada}. ${parte.puesto.nombre}',
                    style: const TextStyle(fontSize: 18),
                  ),
                const SizedBox(height: 12),
                Text(
                  'Entregas en: ${pedido.direccion}',
                  style: const TextStyle(fontSize: 18),
                ),
                Text(_distancia(pedido), style: const TextStyle(fontSize: 17)),
                const SizedBox(height: 12),
                Text(
                  'Ganas ${_ganancia(pedido)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.azul,
                  ),
                ),
                Text(
                  pedido.metodoPago == MetodoPago.efectivo
                      ? 'El cliente paga en efectivo al recibir.'
                      : _repo.datosDe(pedido.id)['pago_simulado'] == true
                      ? 'Pago de demostración confirmado. No se movió dinero.'
                      : 'El pago con Yape ya está confirmado.',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: _boton,
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text(
                    'Aceptar reparto',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Ahora no', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      _dialogo = false;
    }
    if (aceptar != true || !mounted) return;
    await _hacer(() => _repo.aceptarEntrega(pedido.id, widget.usuario.celular));
    if (mounted && _actual?.id == pedido.id) context.go('/repartidor/ruta');
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
                        if (widget.vista == 'inicio' && _inicio != null) ...[
                          TarjetaApp(child: MercadoRepartidor(datos: _inicio!)),
                          const SizedBox(height: 16),
                        ],
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
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: _ocupado || _leyendo ? null : _cargar,
                          icon: const Icon(Icons.refresh),
                          label: const Text(
                            'Actualizar',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                        if (_ocupado)
                          Semantics(
                            liveRegion: true,
                            child: const Text(
                              'Guardando y comprobando…',
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        if (_inicio == null)
                          const Text(
                            'Revisa tu conexión y vuelve a actualizar.',
                            style: TextStyle(fontSize: 18),
                          )
                        else if (_inicio!['autorizado'] != true)
                          ..._sinMercado()
                        else if (widget.vista == 'ganancias')
                          ..._ganancias()
                        else if (widget.vista == 'inicio')
                          ..._home()
                        else if (_actual == null) ...[
                          const AvisoPantalla(
                            icono: Icons.route_outlined,
                            titulo: 'No tienes una entrega en curso',
                            texto:
                                'Acepta un pedido en Inicio para ver tu ruta.',
                          ),
                          _accion(
                            'Ver pedidos',
                            () => context.go('/repartidor/inicio'),
                          ),
                        ] else if (widget.vista == 'entrega')
                          ..._entrega(_actual!)
                        else
                          ..._ruta(_actual!),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
  List<Widget> _sinMercado() => [
    _titulo(
      _inicio?['pendiente'] == true
          ? 'Esperando autorización del mercado'
          : 'Elige el mercado donde trabajarás',
    ),
    Text(
      _inicio?['pendiente'] == true
          ? 'Tu solicitud para ${_inicio?['mercado_solicitado']} está registrada. El responsable del mercado debe autorizarte.'
          : 'Solo recibirás pedidos del mercado que autorice tu cuenta.',
      style: const TextStyle(fontSize: 18),
    ),
    const SizedBox(height: 12),
    const Text('Mercado', style: TextStyle(fontSize: 18)),
    DropdownButtonFormField<int>(
      initialValue: _mercado,
      isExpanded: true,
      itemHeight: null,
      items: [
        for (final m in _inicio?['mercados'] as List? ?? [])
          DropdownMenuItem(
            value: (m['id'] as num).toInt(),
            child: Text(
              m['nombre'].toString(),
              style: const TextStyle(fontSize: 18),
            ),
          ),
      ],
      onChanged: _ocupado ? null : (v) => setState(() => _mercado = v),
      decoration: const InputDecoration(border: OutlineInputBorder()),
    ),
    const SizedBox(height: 12),
    const Text('Movilidad', style: TextStyle(fontSize: 18)),
    DropdownButtonFormField<String>(
      initialValue: _movilidad,
      isExpanded: true,
      itemHeight: null,
      items: [
        for (final e in const {
          'a_pie': 'Estibador a pie',
          'carretilla': 'Carretilla',
          'bicicleta': 'Bicicleta',
          'moto': 'Moto',
          'mototaxi': 'Mototaxi',
          'otro': 'Otra movilidad',
        }.entries)
          DropdownMenuItem(
            value: e.key,
            child: Text(e.value, style: const TextStyle(fontSize: 18)),
          ),
      ],
      onChanged: _ocupado ? null : (v) => setState(() => _movilidad = v!),
      decoration: const InputDecoration(border: OutlineInputBorder()),
    ),
    const SizedBox(height: 12),
    const Text('Placa, si corresponde', style: TextStyle(fontSize: 18)),
    TextField(
      controller: _placa,
      maxLength: 20,
      enabled: !_ocupado,
      style: const TextStyle(fontSize: 18),
      decoration: const InputDecoration(border: OutlineInputBorder()),
    ),
    if (_movilidad == 'otro') ...[
      const Text('Describe tu movilidad', style: TextStyle(fontSize: 18)),
      TextField(
        controller: _descripcion,
        maxLength: 150,
        maxLines: 3,
        enabled: !_ocupado,
        style: const TextStyle(fontSize: 18),
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
    ],
    _accion(
      'Solicitar autorización',
      _mercado == null
          ? null
          : () => _hacer(
              () => _repo.solicitarMercado(
                _mercado!,
                _movilidad,
                _placa.text.trim(),
                descripcion: _descripcion.text.trim(),
              ),
              mensaje:
                  'Solicitud registrada. Espera la autorización de tu mercado.',
            ),
    ),
  ];
  List<Widget> _ganancias() => [
    _titulo('Tu trabajo de hoy'),
    TarjetaApp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${_inicio?['entregas_hoy'] ?? 0} entregas completadas',
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
          ),
          Text(
            'Ganaste ${soles(((_inicio?['ganancia_hoy_centavos'] as num?) ?? 0).toDouble() / 100)}',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.azul,
            ),
          ),
        ],
      ),
    ),
    for (final j in _inicio?['historial_hoy'] as List? ?? [])
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TarjetaApp(
          child: Text(
            '${j['cliente_nombre']} · ${_ganancia(_repo.leer(Map<String, dynamic>.from(j)))}',
            style: const TextStyle(fontSize: 19),
          ),
        ),
      ),
  ];
  List<Widget> _home() => [
    Text(
      'Movilidad: ${Movilidad.desdeCodigo(_inicio?['movilidad']?.toString()).etiqueta}',
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
    ),
    const Text(
      'Puedes cambiarla desde Perfil cuando termines tu entrega.',
      style: TextStyle(fontSize: 17),
    ),
    Material(
      color: Colors.transparent,
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _inicio?['disponible'] == true,
        onChanged: _ocupado
            ? null
            : (v) => _hacer(() => _repo.disponibilidad(v)),
        title: const Text(
          'Disponible para recibir pedidos',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          _inicio?['disponible'] == true
              ? 'Recibes ofertas de tu mercado.'
              : 'No recibirás nuevas ofertas. Puedes terminar tu entrega actual.',
          style: const TextStyle(fontSize: 17),
        ),
      ),
    ),
    ..._ganancias().take(2),
    if (_actual case final p?) ...[
      _titulo('Entrega en curso'),
      _resumen(p),
      _accion(
        'Continuar mi entrega',
        () => context.go(
          p.estado == EstadoPedido.enCamino
              ? '/repartidor/ruta/entrega'
              : '/repartidor/ruta',
        ),
      ),
    ] else ...[
      _titulo('Pedidos de tu mercado'),
      if ((_inicio?['ofertas'] as List? ?? []).isEmpty)
        const AvisoPantalla(
          icono: Icons.delivery_dining,
          titulo: 'Todavía no hay pedidos para recoger',
          texto:
              'Con tu disponibilidad activada, aparecerán aquí cuando el cliente confirme su pedido y el pago correspondiente.',
        ),
      for (final j in _inicio?['ofertas'] as List? ?? []) ...[
        _resumen(_repo.leer(Map<String, dynamic>.from(j))),
        _accion(
          'Ver y aceptar reparto',
          () => _oferta(_repo.leer(Map<String, dynamic>.from(j))),
        ),
      ],
    ],
  ];
  Widget _resumen(Pedido p) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TarjetaApp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            p.clienteNombre,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          Text(
            'Recoges en ${p.puestosActivos.length} puestos',
            style: const TextStyle(fontSize: 18),
          ),
          Text(p.direccion, style: const TextStyle(fontSize: 18)),
          Text(_distancia(p), style: const TextStyle(fontSize: 17)),
          Text(
            'Ganas ${_ganancia(p)}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.azul,
            ),
          ),
        ],
      ),
    ),
  );
  List<Widget> _ruta(Pedido p) {
    final partes = [...p.puestosActivos]
      ..sort((a, b) => a.parada.compareTo(b.parada));
    final recogidos = partes
        .where((x) => x.estado == EstadoPedidoPuesto.recogido)
        .length;
    final siguiente = partes
        .where((x) => x.estado != EstadoPedidoPuesto.recogido)
        .firstOrNull
        ?.id;
    final listo = partes.isNotEmpty && recogidos == partes.length;
    return [
      _resumen(p),
      _titulo('Recogidos $recogidos de ${partes.length} puestos'),
      LinearProgressIndicator(
        value: partes.isEmpty ? 0 : recogidos / partes.length,
        minHeight: 10,
        semanticsLabel: 'Avance del recojo: $recogidos de ${partes.length}',
      ),
      const SizedBox(height: 12),
      const Text(
        'Sigue el orden de las paradas. Confirma el recojo cuando tengas la bolsa en la mano.',
        style: TextStyle(fontSize: 18),
      ),
      for (final pp in partes)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: TarjetaApp(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${pp.parada}. ${pp.puesto.nombre}',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Atiende: ${pp.puesto.casero}',
                  style: const TextStyle(fontSize: 17),
                ),
                etiquetaDePuesto(pp.estado),
                if (pp.estado != EstadoPedidoPuesto.recogido)
                  _accion(
                    'Recogí la bolsa',
                    pp.id == siguiente && pp.estado == EstadoPedidoPuesto.listo
                        ? () => _confirmarRecojo(p, pp)
                        : null,
                  ),
                if (pp.estado == EstadoPedidoPuesto.enPreparacion)
                  const Text(
                    'El vendedor está preparando esta bolsa.',
                    style: TextStyle(fontSize: 17),
                  ),
              ],
            ),
          ),
        ),
      OutlinedButton.icon(
        onPressed: _ocupado
            ? null
            : () => _hacer(
                () => _repo.accionRepartidor(p.id, 'recogiendo'),
                mensaje: 'El aviso quedó en el seguimiento del cliente.',
              ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.all(12),
        ),
        icon: const Icon(Icons.message_outlined),
        label: const Text(
          'Avisar: estoy recogiendo',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      ),
      if (!listo)
        const Text(
          'Recoge en todos los puestos para poder ir a entregar.',
          style: TextStyle(fontSize: 18),
        ),
      _accion(
        'Ya recogí todo · Ir a entregar',
        listo
            ? () async {
                await _hacer(() => _repo.accionRepartidor(p.id, 'salir'));
                if (mounted && _actual?.estado == EstadoPedido.enCamino) {
                  context.go('/repartidor/ruta/entrega');
                }
              }
            : null,
      ),
    ];
  }

  Future<bool> _confirmar(String titulo, String texto) async {
    if (_dialogo) return false;
    _dialogo = true;
    try {
      return await showDialog<bool>(
            context: context,
            builder: (ctx) => Dialog(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _titulo(titulo),
                    Text(texto, style: const TextStyle(fontSize: 19)),
                    const SizedBox(height: 16),
                    FilledButton(
                      style: _boton,
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text(
                        'Sí, confirmar',
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text(
                        'Volver a revisar',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ) ??
          false;
    } finally {
      _dialogo = false;
    }
  }

  Future<void> _confirmarRecojo(Pedido p, PedidoPuesto pp) async {
    if (await _confirmar(
          'Confirmar recojo',
          '¿Tienes la bolsa de ${pp.puesto.nombre} para ${p.clienteNombre}?',
        ) &&
        mounted) {
      await _hacer(() => _repo.accionRepartidor(p.id, 'recoger', parte: pp.id));
    }
  }

  List<Widget> _entrega(Pedido p) {
    final datos = _repo.datosDe(p.id);
    final pagado = datos['pago_aprobado'] == true;
    return [
      if (p.estado != EstadoPedido.enCamino) ...[
        const AvisoPantalla(
          icono: Icons.route_outlined,
          titulo: 'Primero completa el recojo en el mercado',
        ),
        _accion('Volver a mi ruta', () => context.go('/repartidor/ruta')),
      ] else ...[
        _titulo(p.clienteNombre),
        Text(p.direccion, style: const TextStyle(fontSize: 20)),
        if (p.referencia?.isNotEmpty ?? false)
          Text(
            'Referencia: ${p.referencia}',
            style: const TextStyle(fontSize: 18),
          ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => mostrarLlamar(
            context,
            nombre: p.clienteNombre,
            celular: p.clienteCelular,
          ),
          icon: const Icon(Icons.call),
          label: const Text(
            'Contactar al cliente',
            style: TextStyle(fontSize: 18),
          ),
        ),
        const SizedBox(height: 12),
        EtiquetaEstado(
          texto: p.metodoPago == MetodoPago.efectivo
              ? 'Cobrar ${soles(p.cotizacion?.totalCliente ?? 0)} en efectivo'
              : pagado
              ? datos['pago_simulado'] == true
                    ? 'Pago de demostración confirmado'
                    : 'El cliente ya pagó con Yape'
              : 'El pago todavía está pendiente',
          icono: pagado ? Icons.check_circle : Icons.payments_outlined,
          tipo: pagado ? TipoEstado.exito : TipoEstado.aviso,
        ),
        if (p.metodoPago == MetodoPago.efectivo)
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _efectivo,
              onChanged: _ocupado
                  ? null
                  : (v) => setState(() => _efectivo = v == true),
              title: Text(
                'Recibí ${soles(p.cotizacion?.totalCliente ?? 0)} en efectivo',
                style: const TextStyle(fontSize: 19),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
        _titulo('Código de entrega del cliente'),
        const Text(
          'Pídeselo cuando estés en su dirección y le entregues el pedido. Son 4 números.',
          style: TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('codigo_entrega'),
          controller: _codigo,
          enabled: !_ocupado,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 26),
          decoration: const InputDecoration(
            labelText: 'Código del cliente',
            border: OutlineInputBorder(),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _ocupado
              ? null
              : () => _hacer(
                  () => _repo.avisarLlegada(p.id),
                  mensaje: 'El cliente puede ver que llegaste.',
                ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.all(12),
          ),
          icon: const Icon(Icons.doorbell_outlined),
          label: const Text(
            'Avisar: llegué a tu dirección',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
        ),
        _accion(
          'Confirmar entrega',
          p.metodoPago == MetodoPago.efectivo && !_efectivo ||
                  p.metodoPago == MetodoPago.yape && !pagado
              ? null
              : () => _completar(p),
        ),
      ],
    ];
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
    _dialogo = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.celebration, size: 50, color: AppColors.azul),
              _titulo('¡Pedido entregado!'),
              Text(
                'Ganaste ${_ganancia(p)} por este reparto.',
                style: const TextStyle(fontSize: 21),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: _boton,
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Volver al inicio',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    _dialogo = false;
    if (mounted) context.go('/repartidor/inicio');
  }
}
