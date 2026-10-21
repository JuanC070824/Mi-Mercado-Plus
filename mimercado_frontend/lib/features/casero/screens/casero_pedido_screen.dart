import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';
import '../../../core/widgets/botones_app.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../data/models/cotizacion.dart';
import '../../../data/models/pedido.dart';
import '../../../data/models/usuario.dart';
import '../../../data/repositories/pedido_repository.dart';
import '../../../data/repositories/pedidos_vendedor_api_repository.dart';
import '../widgets/alerta_pedido.dart';
import '../widgets/llamar_dialog.dart';
import '../widgets/encabezado_pedido_casero.dart';
import '../widgets/revision_producto_casero.dart';
import '../widgets/cotizacion_casero.dart';

/// Detalle de un pedido para el casero. Muestra lo que toca hacer según el
/// estado de SU parte: aceptar/rechazar (V1b/V1c), revisar (V2), pesar (V3),
/// empaquetar (V4) y entregar al repartidor (V5).
class CaseroPedidoScreen extends StatefulWidget {
  const CaseroPedidoScreen({
    super.key,
    required this.pedidoId,
    required this.usuario,
    this.repository,
  });
  final int pedidoId;
  final Usuario usuario;
  final PedidosVendedorApiRepository? repository;

  @override
  State<CaseroPedidoScreen> createState() => _CaseroPedidoScreenState();
}

class _CaseroPedidoScreenState extends State<CaseroPedidoScreen>
    with WidgetsBindingObserver {
  late final PedidosVendedorApiRepository _repo;
  final _desplazamiento = ScrollController();

  Pedido? _pedido;
  bool _cargando = true;
  bool _ocupado = false;
  bool _actualizando = false;
  int _consultaId = 0;
  String? _errorCarga;
  String? _errorAccion;
  bool _confirmando = false;
  Timer? _refresco;
  bool get _visible =>
      mounted &&
      TickerMode.valuesOf(context).enabled &&
      (ModalRoute.of(context)?.isCurrent ?? false) &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  int get _puestoId => widget.usuario.puestoId ?? 0;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? PedidosVendedorApiRepository.instancia;
    _repo.cambios.addListener(_alCambiarPedidos);
    WidgetsBinding.instance.addObserver(this);
    _refresco = Timer.periodic(const Duration(seconds: 15), (_) {
      final estado = _pedido?.parteDePuesto(_puestoId)?.estado;
      if (_visible &&
          !_ocupado &&
          !_actualizando &&
          !_confirmando &&
          _errorCarga == null &&
          estado != null &&
          !estado.descartado &&
          estado != EstadoPedidoPuesto.recogido) {
        _cargar();
      }
    });
    _cargar();
  }

  @override
  void dispose() {
    _refresco?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _repo.cambios.removeListener(_alCambiarPedidos);
    _desplazamiento.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final consulta = ++_consultaId;
    setState(() {
      _actualizando = true;
      _errorCarga = null;
    });
    try {
      final lista = await _repo.pedidosDePuesto(_puestoId);
      if (!mounted || consulta != _consultaId) return;
      setState(() {
        _pedido = lista.where((p) => p.id == widget.pedidoId).firstOrNull;
        _cargando = false;
        _actualizando = false;
      });
    } catch (error) {
      if (!mounted || consulta != _consultaId) return;
      setState(() {
        _cargando = false;
        _actualizando = false;
        _errorCarga = error is PedidoException
            ? error.mensaje
            : 'No pudimos cargar el pedido. Inténtalo de nuevo.';
      });
    }
  }

  void _alCambiarPedidos() {
    if (!_ocupado && !_confirmando) _cargar();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _visible &&
        !_ocupado &&
        !_actualizando &&
        !_confirmando) {
      _cargar();
    }
  }

  /// Ejecuta una acción del repositorio mostrando el error si falla.
  Future<void> _hacer(Future<void> Function() accion, {String? exito}) async {
    if (_ocupado || _actualizando) return;
    setState(() {
      _ocupado = true;
      _errorAccion = null;
    });
    try {
      await accion();
      if (!mounted) return;
      await _cargar();
      if (mounted && exito != null) avisar(context, exito);
    } on PedidoException catch (e) {
      if (mounted) {
        setState(() => _errorAccion = e.mensaje);
        if (_desplazamiento.hasClients) _desplazamiento.jumpTo(0);
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const EncabezadoPedidoCasero(titulo: 'Detalle del pedido'),
          Expanded(child: _cuerpo()),
        ],
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando) return const CargandoApp();
    if (_errorCarga != null) {
      return AvisoPantalla(
        icono: Icons.wifi_off_outlined,
        titulo: 'No pudimos actualizar el pedido',
        texto: _errorCarga,
        esError: true,
        textoBoton: 'Reintentar',
        alTocar: _cargar,
      );
    }
    final p = _pedido;
    final parte = p?.parteDePuesto(_puestoId);
    if (p == null || parte == null) {
      return const AvisoPantalla(
        icono: Icons.search_off,
        titulo: 'No encontramos este pedido',
        texto: 'Puede que el cliente lo haya cancelado.',
      );
    }
    return ListView(
      controller: _desplazamiento,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (_errorAccion != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                _errorAccion!,
                style: const TextStyle(fontSize: 18, color: AppColors.error),
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: _ocupado || _actualizando || _confirmando ? null : _cargar,
          icon: const Icon(Icons.refresh),
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
          label: Text(
            _actualizando ? 'Actualizando…' : 'Actualizar pedido',
            style: const TextStyle(fontSize: 18),
          ),
        ),
        const Text(
          'Se actualiza cada 15 segundos mientras esta pantalla está visible.',
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 12),
        _cliente(p, parte),
        const SizedBox(height: 16),
        ..._segunEstado(p, parte),
      ],
    );
  }

  Widget _cliente(Pedido p, PedidoPuesto parte) {
    final compartido = textoCompartido(p, parte);
    return TarjetaApp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, color: AppColors.azul, size: 30),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  p.clienteNombre,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton.outlined(
                tooltip: 'Llamar a ${p.clienteNombre}',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: () => mostrarLlamar(
                  context,
                  nombre: p.clienteNombre,
                  celular: p.clienteCelular,
                ),
                icon: const Icon(Icons.call, color: AppColors.azul),
              ),
            ],
          ),
          Text(
            fechaCorta(p.creadoEn.toLocal()),
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textoSecundario,
            ),
          ),
          const SizedBox(height: 8),
          etiquetaDePuesto(parte.estado),
          if (compartido != null) ...[
            const SizedBox(height: 8),
            EtiquetaEstado(
              texto: compartido,
              icono: Icons.people_outline,
              tipo: TipoEstado.info,
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _segunEstado(Pedido p, PedidoPuesto parte) {
    switch (parte.estado) {
      case EstadoPedidoPuesto.pendiente:
        return [
          const TituloSeccion('Productos que pide'),
          const SizedBox(height: 8),
          ListaProductosParte(parte: parte),
          const SizedBox(height: 8),
          Text(
            'Estimado: ${soles(parte.subtotalEstimado)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          BotonPrincipal(
            texto: 'Aceptar pedido',
            cargando: _ocupado,
            onPressed: () => _hacer(
              () => _repo.aceptarSubpedido(parte.id),
              exito: 'Aceptaste el pedido. Ahora revisa los productos.',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error, width: 2),
              minimumSize: const Size(48, 56),
              shape: const StadiumBorder(),
            ),
            onPressed: _ocupado
                ? null
                : () => rechazarConMotivo(context, parte, repository: _repo),
            icon: const Icon(Icons.close),
            label: const Text('Rechazar', style: TextStyle(fontSize: 20)),
          ),
        ];
      case EstadoPedidoPuesto.rechazado:
      case EstadoPedidoPuesto.cancelado:
        return [
          AvisoPantalla(
            icono: Icons.block,
            titulo: 'No atendiste este pedido',
            texto: parte.motivoRechazo == null
                ? null
                : 'Motivo: ${parte.motivoRechazo}',
          ),
        ];
      case EstadoPedidoPuesto.aceptado:
      case EstadoPedidoPuesto.pesando:
        return _revisar(p, parte); // V2
      case EstadoPedidoPuesto.pesado:
        return _esperandoCliente(p, parte);
      case EstadoPedidoPuesto.enPreparacion:
        return _empaquetar(p, parte); // V4
      case EstadoPedidoPuesto.listo:
        return _entregar(p, parte); // V5
      case EstadoPedidoPuesto.recogido:
        return [
          const AvisoPantalla(
            icono: Icons.done_all,
            titulo: '¡Bolsa entregada al repartidor!',
            texto: 'Tu parte de este pedido ya terminó. Gracias, casero.',
          ),
        ];
    }
  }

  // ------------------------------------------------------------ V2 Revisar

  Future<void> _elegirDisponibilidad(PedidoDetalle detalle) async {
    if (_ocupado || _actualizando) return;
    final elegida = await elegirDisponibilidadProducto(context, detalle);
    if (!mounted || elegida == null || elegida == detalle.disponibilidad) {
      return;
    }
    await _hacer(() => _repo.marcarDisponibilidad(detalle.id, elegida));
  }

  List<Widget> _revisar(Pedido p, PedidoPuesto parte) {
    final revisados = parte.detalles
        .where((d) => d.disponibilidad != Disponibilidad.pendiente)
        .length;
    return [
      if (p.puestos.length > 1) ...[
        _compartido(p, parte),
        const SizedBox(height: 16),
      ],
      const TituloSeccion('Revisa cada producto'),
      const SizedBox(height: 4),
      Text(
        'Elige la disponibilidad y confirma antes de guardar. '
        'Revisados: $revisados de ${parte.detalles.length}.',
        style: const TextStyle(fontSize: 17, color: AppColors.textoSecundario),
      ),
      const SizedBox(height: 12),
      if (_ocupado || _actualizando) ...[
        Semantics(
          liveRegion: true,
          child: const Text(
            'Guardando y comprobando la disponibilidad…',
            style: TextStyle(fontSize: 18),
          ),
        ),
        const SizedBox(height: 12),
      ],
      for (final d in parte.detalles) ...[
        RevisionProductoCasero(
          detalle: d,
          habilitado: !_ocupado && !_actualizando,
          onTap: () => _elegirDisponibilidad(d),
        ),
        const SizedBox(height: 8),
      ],
      if ((parte.listaMandado ?? '').trim().isNotEmpty) ...[
        const SizedBox(height: 8),
        TarjetaApp(
          color: AppColors.avisoFondo,
          colorBorde: AppColors.aviso,
          child: MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lista de mandado',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                Text(parte.listaMandado!, style: const TextStyle(fontSize: 18)),
                const Text(
                  'Revisa también esta lista antes de enviar el precio final.',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      const SizedBox(height: 16),
      const TituloSeccion('Mensajes para copiar'),
      const Text(
        'Copia un mensaje para enviarlo desde tu aplicación de mensajes.',
        style: TextStyle(fontSize: 16, color: AppColors.textoSecundario),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final m in const [
            'Ya estoy pesando tu pedido',
            'No tengo un producto, ¿te ofrezco otro?',
            'Tu pedido sale en 10 minutos',
          ])
            OutlinedButton.icon(
              icon: const Icon(Icons.copy, size: 20),
              label: Text(m, style: const TextStyle(fontSize: 16)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.all(12),
              ),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: m));
                if (mounted) {
                  avisar(
                    context,
                    'Mensaje copiado. Envíalo al cliente desde tu aplicación de mensajes.',
                  );
                }
              },
            ),
        ],
      ),
      ..._despuesDeRevisar(
        p,
        parte,
        todosRevisados:
            revisados == parte.detalles.length && parte.detalles.isNotEmpty,
      ),
    ];
  }

  /// Lo que sigue después de revisar: ir a la balanza (V3).
  List<Widget> _despuesDeRevisar(
    Pedido p,
    PedidoPuesto parte, {
    required bool todosRevisados,
  }) {
    final conProductos = parte.detalles.any(
      (d) => d.disponibilidad != Disponibilidad.sinStock,
    );
    final listo = todosRevisados && conProductos && !_ocupado && !_actualizando;
    return [
      const SizedBox(height: 20),
      EtiquetaEstado(
        texto: todosRevisados && !conProductos
            ? 'No hay productos disponibles. Revisa las opciones o rechaza el pedido.'
            : todosRevisados
            ? 'Listo para pesar'
            : 'Revisa todos los productos para poder pesar',
        icono: todosRevisados && conProductos
            ? Icons.check_circle
            : Icons.info_outline,
        tipo: todosRevisados && conProductos
            ? TipoEstado.exito
            : TipoEstado.info,
      ),
      const SizedBox(height: 12),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.azul,
          foregroundColor: AppColors.blanco,
          minimumSize: const Size(48, 56),
          padding: const EdgeInsets.all(16),
        ),
        onPressed: listo
            ? () => context.push('/casero/inicio/pedido/${p.id}/pesar')
            : null,
        child: const Text(
          'Pesar y poner precio',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      if (todosRevisados && !conProductos) ...[
        const SizedBox(height: 12),
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: _ocupado || _actualizando
              ? null
              : () => rechazarConMotivo(context, parte, repository: _repo),
          child: const Text('Rechazar pedido', style: TextStyle(fontSize: 18)),
        ),
      ],
    ];
  }

  List<Widget> _empaquetar(Pedido p, PedidoPuesto parte) => [
    const EtiquetaEstado(
      texto: 'El cliente aceptó el precio final. Ya puedes preparar la bolsa.',
      icono: Icons.check_circle,
      tipo: TipoEstado.exito,
    ),
    const SizedBox(height: 12),
    SeguimientoPuestoCasero(estado: parte.estado),
    if (p.cotizacion?.dePuesto(parte.id) case final cp?) ...[
      const SizedBox(height: 12),
      CotizacionCasero(parte: parte, cotizacion: cp),
    ],
    if (p.puestos.length > 1) ...[
      const SizedBox(height: 12),
      _compartido(p, parte),
    ],
    const SizedBox(height: 16),
    Text(
      'Empaqueta los productos y etiqueta la bolsa con el nombre de ${p.clienteNombre} y de tu puesto.',
      style: const TextStyle(fontSize: 19),
    ),
    const SizedBox(height: 12),
    FilledButton.icon(
      style: _estiloAccion,
      onPressed: _ocupado || _actualizando || _confirmando
          ? null
          : () => _confirmarAccion(parte, entregar: false),
      icon: const Icon(Icons.inventory_2_outlined),
      label: const Text(
        'Ya empaqueté: marcar listo',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 20),
      ),
    ),
  ];

  final Set<int> _enBolsa = {};
  ButtonStyle get _estiloAccion => FilledButton.styleFrom(
    minimumSize: const Size(48, 56),
    padding: const EdgeInsets.all(16),
    backgroundColor: AppColors.azul,
    foregroundColor: AppColors.blanco,
  );

  Future<void> _confirmarAccion(
    PedidoPuesto parte, {
    required bool entregar,
  }) async {
    if (_ocupado || _actualizando || _confirmando) return;
    setState(() => _confirmando = true);
    bool? confirmado;
    try {
      confirmado = await showDialog<bool>(
        context: context,
        builder: (ctx) => Dialog(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  entregar
                      ? 'Confirmar entrega de la bolsa'
                      : 'Confirmar bolsa lista',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  'Pedido de ${_pedido!.clienteNombre}\n${parte.puesto.nombre}',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.azul,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  entregar
                      ? 'Confirma únicamente después de entregar esta bolsa al repartidor. La entrega al cliente la registra el repartidor.'
                      : 'Verifica que todos los productos estén empaquetados y que la bolsa tenga el nombre del cliente y de tu puesto.',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: _estiloAccion,
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(
                    entregar ? 'Sí, entregué la bolsa' : 'Sí, está lista',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
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
      );
    } finally {
      if (mounted) setState(() => _confirmando = false);
    }
    if (!mounted || confirmado != true) return;
    await _hacer(
      () => entregar
          ? _repo.entregarARepartidor(parte.id)
          : _repo.marcarListo(parte.id),
      exito: entregar
          ? 'Bolsa entregada al repartidor.'
          : 'Bolsa lista. Espera al repartidor.',
    );
  }

  List<Widget> _entregar(Pedido p, PedidoPuesto parte) {
    final cp = p.cotizacion?.dePuesto(parte.id);
    final items = cp?.detalles ?? const <CotizacionDetalle>[];
    final completo =
        items.isNotEmpty &&
        items.every((i) => _enBolsa.contains(i.pedidoDetalleId));
    final bloqueado = _ocupado || _actualizando || _confirmando;
    return [
      const EtiquetaEstado(
        texto:
            'Espera al repartidor y comprueba que la bolsa sea para este cliente antes de entregarla.',
        icono: Icons.delivery_dining,
      ),
      const SizedBox(height: 12),
      SeguimientoPuestoCasero(estado: parte.estado),
      const SizedBox(height: 16),
      const Text('Bolsa para entregar', style: TextStyle(fontSize: 18)),
      SelectableText(
        '${p.clienteNombre}\n${parte.puesto.nombre}',
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w900,
          color: AppColors.azul,
        ),
      ),
      const SizedBox(height: 16),
      const TituloSeccion('Revisa la bolsa'),
      for (final d in items)
        CheckboxListTile(
          value: _enBolsa.contains(d.pedidoDetalleId),
          onChanged: bloqueado
              ? null
              : (v) => setState(
                  () => v == true
                      ? _enBolsa.add(d.pedidoDetalleId)
                      : _enBolsa.remove(d.pedidoDetalleId),
                ),
          title: Text(
            '${d.nombreFinal} · ${cantidadExactaCasero(d.cantidadReal, parte.detalles.where((i) => i.id == d.pedidoDetalleId).firstOrNull?.unidad.simbolo ?? '')}',
            style: const TextStyle(fontSize: 18),
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
      if (!completo)
        const Text(
          'Marca todos los productos para poder entregar la bolsa. Si no aparece la lista, actualiza el pedido.',
          style: TextStyle(fontSize: 17),
        ),
      const SizedBox(height: 16),
      FilledButton(
        style: _estiloAccion,
        onPressed: completo && !bloqueado
            ? () => _confirmarAccion(parte, entregar: true)
            : null,
        child: Text(
          _ocupado ? 'Guardando entrega…' : 'Ya se lo entregué',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20),
        ),
      ),
    ];
  }

  List<Widget> _esperandoCliente(Pedido p, PedidoPuesto parte) {
    final cp = p.cotizacion?.dePuesto(parte.id);
    final borrador = p.cotizacion?.estado == EstadoCotizacion.borrador;
    return [
      EtiquetaEstado(
        texto: borrador
            ? 'Tu precio está guardado. Esperamos que los otros puestos envíen sus precios.'
            : 'Precio enviado. Esperamos que el cliente acepte el precio de todo su pedido antes de preparar la bolsa.',
        icono: Icons.hourglass_top,
        tipo: TipoEstado.aviso,
      ),
      const SizedBox(height: 12),
      SeguimientoPuestoCasero(estado: parte.estado),
      if (cp != null) ...[
        const SizedBox(height: 12),
        CotizacionCasero(parte: parte, cotizacion: cp),
      ],
    ];
  }

  /// Tarjeta del pedido compartido con el estado de los otros puestos.
  Widget _compartido(Pedido p, PedidoPuesto parte) {
    return TarjetaApp(
      color: AppColors.azulClaro,
      colorBorde: AppColors.azul,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pedido compartido',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          for (final otro in p.puestos)
            if (otro.id != parte.id)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${otro.parada}. ${otro.puesto.nombre}',
                      style: const TextStyle(fontSize: 17),
                    ),
                    etiquetaDePuesto(otro.estado),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
