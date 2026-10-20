import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';
import '../../../core/widgets/botones_app.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../core/widgets/encabezado_simple.dart';
import '../../../data/models/cotizacion.dart';
import '../../../data/models/pedido.dart';
import '../../../data/models/repartidor.dart';
import '../../../data/models/usuario.dart';
import '../../../data/repositories/pedido_repository.dart';
import '../widgets/estrellas.dart';
import '../widgets/precio_final_sheet.dart';

/// Mi pedido: seguimiento del pedido en curso.
/// C5 pesando · C5b confirmar precio final · C6 recojo · C7 en camino ·
/// C7b repartidor afuera · C8 calificar. C9 (historial) desde el enlace.
class MiPedidoScreen extends StatefulWidget {
  const MiPedidoScreen({super.key, required this.usuario});
  final Usuario usuario;

  @override
  State<MiPedidoScreen> createState() => _MiPedidoScreenState();
}

class _MiPedidoScreenState extends State<MiPedidoScreen> {
  final PedidoRepository _repo = PedidoRepositoryMock.instancia;

  /// Pedidos cuya hoja de precio final ya se abrió sola (no repetirla).
  static final Set<int> _precioMostrado = {};

  Pedido? _pedido;
  Repartidor? _repartidor;
  bool _cargando = true;
  String? _error;

  // C8 · calificación
  final Map<int, int> _estrellas = {};
  int _estrellasRepartidor = 0;
  bool _enviandoCalificacion = false;

  @override
  void initState() {
    super.initState();
    _repo.cambios.addListener(_cargar);
    _cargar();
  }

  @override
  void dispose() {
    _repo.cambios.removeListener(_cargar);
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final cel = widget.usuario.celular;
      final p =
          await _repo.pedidoActivoCliente(cel) ??
          await _repo.pedidoParaCalificar(cel);
      final rep = p == null ? null : await _repo.repartidorDe(p.id);
      if (!mounted) return;
      setState(() {
        _pedido = p;
        _repartidor = rep;
        _cargando = false;
        _error = null;
      });
      _abrirPrecioSiToca();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No pudimos cargar tu pedido. Inténtalo de nuevo.';
      });
    }
  }

  /// C5b se abre sola la primera vez que llega el precio final.
  void _abrirPrecioSiToca() {
    final p = _pedido;
    if (p == null || p.estado != EstadoPedido.esperandoConfirmacion) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
    if (!_precioMostrado.add(p.id)) return;
    _verPrecio(p);
  }

  Future<void> _verPrecio(Pedido p) async {
    final acepto = await mostrarPrecioFinal(context, p);
    if (acepto && mounted) {
      avisar(context, '¡Listo! Tus caseros ya empaquetan tu pedido.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _pedido;
    return Scaffold(
      body: Column(
        children: [
          EncabezadoSimple(
            titulo: p == null ? 'Mi pedido' : 'Mi pedido #${p.codigoCorto}',
            mostrarAtras: false,
          ),
          Expanded(child: _cuerpo()),
        ],
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando) return const CargandoApp(texto: 'Buscando tu pedido…');
    if (_error != null) {
      return AvisoPantalla(
        icono: Icons.wifi_off,
        titulo: 'Algo salió mal',
        texto: _error,
        esError: true,
        textoBoton: 'Reintentar',
        alTocar: _cargar,
      );
    }
    final p = _pedido;
    if (p == null) return _sinPedido();
    if (p.estado == EstadoPedido.entregado) return _calificar(p); // C8
    final aceptado = p.cotizacion?.estado == EstadoCotizacion.aceptada;
    final llego =
        p.estado == EstadoPedido.enCamino &&
        p.historial.isNotEmpty &&
        p.historial.last.texto == 'El repartidor llegó a tu puerta';
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (llego) ...[
            _repartidorAfuera(p),
            const SizedBox(height: 16),
          ], // C7b
          ..._ahora(p),
          const SizedBox(height: 20),
          if (p.estado == EstadoPedido.enCamino)
            ..._enCamino(p) // C7
          else if (aceptado)
            ..._recojo(p) // C6
          else ...[
            const TituloSeccion('Tus puestos'),
            const SizedBox(height: 8),
            for (final parte in p.puestos) ...[
              _FilaPuesto(parte: parte),
              const SizedBox(height: 8),
            ],
          ],
          const SizedBox(height: 12),
          const TituloSeccion('Paso a paso'),
          const SizedBox(height: 8),
          LineaTiempo(eventos: p.historial),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _explicarPasos,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: const Icon(Icons.help_outline),
              label: const Text(
                '¿Qué significa cada paso?',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
          _enlaceHistorial(),
        ],
      ),
    );
  }

  Widget _enlaceHistorial() => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: () => context.push('/pedido/historial'),
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      icon: const Icon(Icons.receipt_long_outlined),
      label: const Text(
        'Ver mis pedidos anteriores',
        style: TextStyle(fontSize: 18),
      ),
    ),
  );

  // ------------------------------------------------------------ C6 Recojo

  List<Widget> _recojo(Pedido p) {
    final r = _repartidor;
    final paradas = [...p.puestosActivos]
      ..sort((a, b) => a.parada.compareTo(b.parada));
    return [
      const TituloSeccion('Tu repartidor'),
      const SizedBox(height: 8),
      TarjetaApp(
        child: r == null
            ? const Row(
                children: [
                  Icon(Icons.person_search, color: AppColors.azul, size: 32),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Estamos buscando un repartidor de tu mercado.',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.azulClaro,
                    child: Icon(
                      Icons.delivery_dining,
                      color: AppColors.azul,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MergeSemantics(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.nombre,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            r.movilidadTexto,
                            style: const TextStyle(fontSize: 17),
                          ),
                          Text(
                            '★ ${r.calificacion.toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.textoSecundario,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton.outlined(
                    tooltip: 'Llamar a ${r.nombre}',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: () => avisar(
                      context,
                      'Llama a ${r.nombre.split(' ').first} al ${r.celular}.',
                    ),
                    icon: const Icon(Icons.call, color: AppColors.azul),
                  ),
                ],
              ),
      ),
      const SizedBox(height: 16),
      const TituloSeccion('Ruta de recojo'),
      const SizedBox(height: 8),
      for (final pp in paradas) ...[
        MergeSemantics(
          child: TarjetaApp(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  pp.estado == EstadoPedidoPuesto.recogido
                      ? Icons.check_circle
                      : Icons.hourglass_top,
                  color: pp.estado == EstadoPedidoPuesto.recogido
                      ? AppColors.exitoTexto
                      : AppColors.aviso,
                  size: 30,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${pp.parada}. ${pp.puesto.nombre}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  pp.estado == EstadoPedidoPuesto.recogido
                      ? 'Recogido'
                      : 'Por recoger',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
      MergeSemantics(
        child: TarjetaApp(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.home, color: AppColors.azul, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${paradas.length + 1}. Tu casa',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  // --------------------------------------------------------- C7 En camino

  List<Widget> _enCamino(Pedido p) {
    final total = p.cotizacion?.totalCliente ?? p.totalEstimado;
    return [
      TarjetaApp(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Llega en unos 8 minutos',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: 0.7,
              minHeight: 12,
              borderRadius: BorderRadius.circular(6),
              color: AppColors.azul,
              backgroundColor: AppColors.divisor,
              semanticsLabel: 'Tu pedido está cerca',
            ),
            if (_repartidor != null) ...[
              const SizedBox(height: 8),
              Text(
                '${_repartidor!.nombre} · ${_repartidor!.movilidadTexto}',
                style: const TextStyle(fontSize: 17),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      TarjetaApp(
        color: AppColors.azulClaro,
        colorBorde: AppColors.azul,
        child: Semantics(
          label:
              'Tu código de entrega es ${p.codigoEntrega.split('').join(' ')}. '
              'Dáselo al repartidor cuando llegue.',
          excludeSemantics: true,
          child: Column(
            children: [
              const Text(
                'Tu código de entrega',
                style: TextStyle(fontSize: 18),
              ),
              Text(
                p.codigoEntrega,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 10,
                  color: AppColors.azul,
                ),
              ),
              const Text(
                'Dáselo al repartidor cuando llegue.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      EtiquetaEstado(
        texto: p.metodoPago == MetodoPago.yape
            ? 'Ya pagaste con Yape'
            : 'Ten listo ${soles(total)} para pagar en ${p.metodoPago.etiqueta.toLowerCase()}',
        icono: p.metodoPago == MetodoPago.yape
            ? Icons.check_circle
            : Icons.payments_outlined,
        tipo: p.metodoPago == MetodoPago.yape
            ? TipoEstado.exito
            : TipoEstado.aviso,
      ),
    ];
  }

  /// C7b · Banner "el repartidor está afuera".
  Widget _repartidorAfuera(Pedido p) => Semantics(
    liveRegion: true,
    child: TarjetaApp(
      color: AppColors.avisoFondo,
      colorBorde: AppColors.aviso,
      child: Row(
        children: [
          const Icon(Icons.doorbell_outlined, color: AppColors.aviso, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '¡Tu repartidor está afuera! Dale el código ${p.codigoEntrega}.',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    ),
  );

  // ------------------------------------------------------------ C8 Calificar

  Future<void> _enviarCalificacion(Pedido p) async {
    setState(() => _enviandoCalificacion = true);
    try {
      await _repo.calificar(p.id, Map.of(_estrellas), _estrellasRepartidor);
      if (!mounted) return;
      avisar(context, '¡Gracias! Tu calificación ayuda a tus caseros.');
      _estrellas.clear();
      _estrellasRepartidor = 0;
    } on PedidoException catch (e) {
      if (mounted) avisar(context, e.mensaje);
    } finally {
      if (mounted) setState(() => _enviandoCalificacion = false);
    }
  }

  Widget _calificar(Pedido p) {
    final puestos = p.puestosActivos;
    final completo =
        puestos.every((x) => (_estrellas[x.puesto.id] ?? 0) > 0) &&
        (_repartidor == null || _estrellasRepartidor > 0);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const Icon(Icons.check_circle, size: 80, color: AppColors.exitoTexto),
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: const Text(
            '¡Pedido entregado!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
        ),
        const Text(
          '¿Cómo te atendieron? Toca las estrellas.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 16),
        for (final pp in puestos) ...[
          TarjetaApp(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pp.puesto.nombre,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Estrellas(
                  para: pp.puesto.nombre,
                  valor: _estrellas[pp.puesto.id] ?? 0,
                  onCambio: (v) => setState(() => _estrellas[pp.puesto.id] = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (_repartidor != null)
          TarjetaApp(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Repartidor: ${_repartidor!.nombre}',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Estrellas(
                  para: _repartidor!.nombre,
                  valor: _estrellasRepartidor,
                  onCambio: (v) => setState(() => _estrellasRepartidor = v),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        BotonPrincipal(
          texto: 'Enviar calificación',
          cargando: _enviandoCalificacion,
          onPressed: completo ? () => _enviarCalificacion(p) : null,
        ),
        if (!completo)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Califica a cada uno para enviar.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppColors.textoSecundario),
            ),
          ),
        const SizedBox(height: 8),
        _enlaceHistorial(),
      ],
    );
  }

  Widget _sinPedido() => Column(
    children: [
      Expanded(
        child: AvisoPantalla(
          icono: Icons.inventory_2_outlined,
          titulo: 'No tienes pedidos en curso',
          texto: 'Cuando hagas un pedido, aquí verás cómo va.',
          textoBoton: 'Ir al mercado',
          alTocar: () => context.go('/inicio'),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Center(child: _enlaceHistorial()),
      ),
    ],
  );

  /// Tarjeta "AHORA": qué está pasando, en palabras simples.
  List<Widget> _ahora(Pedido p) {
    final aceptado = p.cotizacion?.estado == EstadoCotizacion.aceptada;
    final String texto = switch (p.estado) {
      EstadoPedido.pendiente => 'Tus caseros están viendo tu pedido.',
      EstadoPedido.enPreparacion when !aceptado =>
        'Tus caseros están pesando tus productos.',
      EstadoPedido.enPreparacion => 'Tus caseros están empaquetando tu pedido.',
      EstadoPedido.esperandoConfirmacion =>
        'Ya pesaron. Revisa y acepta el precio final para que salga tu pedido.',
      EstadoPedido.listoParaRecojo =>
        'Tus bolsas están listas. El repartidor va a recogerlas.',
      EstadoPedido.enRecojo => 'El repartidor está recogiendo en tus puestos.',
      EstadoPedido.enCamino => '¡Tu pedido va en camino a tu casa!',
      _ => p.estado.etiqueta,
    };
    return [
      TarjetaApp(
        color: AppColors.azulClaro,
        colorBorde: AppColors.azul,
        child: Semantics(
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AHORA',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.azul,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                texto,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              etiquetaDePedido(p.estado),
            ],
          ),
        ),
      ),
      if (p.estado == EstadoPedido.esperandoConfirmacion) ...[
        const SizedBox(height: 12),
        BotonPrincipal(
          texto: 'Ver precio final',
          onPressed: () => _verPrecio(p),
        ),
      ],
    ];
  }

  void _explicarPasos() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '¿Qué significa cada paso?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        content: const SingleChildScrollView(
          child: Text(
            '1. Pedido enviado: tus caseros lo reciben.\n'
            '2. Pesando: cada casero pesa tus productos.\n'
            '3. Precio final: tú lo revisas y lo aceptas.\n'
            '4. Empaquetando: preparan tus bolsas.\n'
            '5. Recogiendo: el repartidor pasa por cada puesto.\n'
            '6. En camino: va a tu casa. Dale tu código de entrega.\n'
            '7. Entregado: ¡listo! Puedes calificar.',
            style: TextStyle(fontSize: 18, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}

class _FilaPuesto extends StatelessWidget {
  const _FilaPuesto({required this.parte});
  final PedidoPuesto parte;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: TarjetaApp(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${parte.parada}. ${parte.puesto.nombre}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            etiquetaDePuesto(parte.estado),
          ],
        ),
      ),
    );
  }
}
