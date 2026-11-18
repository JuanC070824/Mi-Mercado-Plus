import 'package:flutter/material.dart';
import '../../../core/state/preferencias_vendedor_state.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../data/models/pedido.dart';
import '../../../data/models/usuario.dart';
import '../../../data/repositories/pedido_repository.dart';
import '../../../data/repositories/pedidos_vendedor_api_repository.dart';
import '../../../data/repositories/vendedor_inicio_repository.dart';
import '../../../data/repositories/puesto_vendedor_repository.dart';
import '../widgets/accesos_inicio_casero.dart';
import '../widgets/encabezado_inicio_casero.dart';
import '../widgets/alerta_pedido.dart';

class CaseroInicioScreen extends StatefulWidget {
  const CaseroInicioScreen({
    super.key,
    required this.usuario,
    this.repository,
    this.pedidosRepository,
  });

  final Usuario usuario;
  final VendedorInicioApiRepository? repository;
  final PedidosVendedorApiRepository? pedidosRepository;

  @override
  State<CaseroInicioScreen> createState() => _CaseroInicioScreenState();
}

class _CaseroInicioScreenState extends State<CaseroInicioScreen> {
  late final VendedorInicioApiRepository _repository;
  late final PedidosVendedorApiRepository _pedidosRepository;
  final Set<int> _pedidosAvisados = {};
  bool _alertaAbierta = false;
  VendedorInicio? _inicio;
  bool _cargando = true;
  bool _cambiandoEstado = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? VendedorInicioApiRepository.instancia;
    _pedidosRepository =
        widget.pedidosRepository ?? PedidosVendedorApiRepository.instancia;
    PuestoVendedorApiRepository.cambios.addListener(_cargar);
    if (widget.usuario.puestoId == null) {
      _inicio = const VendedorInicio.sinPuesto();
      _cargando = false;
    } else {
      _cargar();
    }
  }

  @override
  void dispose() {
    PuestoVendedorApiRepository.cambios.removeListener(_cargar);
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final inicio = await _repository.cargar();
      if (!mounted) return;
      setState(() {
        _inicio = inicio;
        _cargando = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _alertaAbierta || !_inicioVisible) return;
        final nuevo = inicio.pedidos
            .where(
              (p) =>
                  p.estado == 'pendiente' && !_pedidosAvisados.contains(p.id),
            )
            .firstOrNull;
        if (nuevo != null) _mostrarAlerta(nuevo.id);
      });
    } on VendedorInicioException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.mensaje;
        _cargando = false;
      });
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos leer la información de tu puesto.';
        _cargando = false;
      });
    }
  }

  bool get _inicioVisible =>
      TickerMode.valuesOf(context).enabled &&
      (ModalRoute.of(context)?.isCurrent ?? false);

  Future<void> _mostrarAlerta(int pedidoId) async {
    if (_alertaAbierta || !_inicioVisible) return;
    final puestoId = _inicio?.puesto?.id;
    if (puestoId == null) return;
    setState(() => _alertaAbierta = true);
    try {
      final lista = await _pedidosRepository.pedidosDePuesto(puestoId);
      if (!mounted || !_inicioVisible) return;
      final pedido = lista.where((p) => p.id == pedidoId).firstOrNull;
      final parte = pedido?.parteDePuesto(puestoId);
      if (pedido == null ||
          parte == null ||
          parte.estado != EstadoPedidoPuesto.pendiente) {
        _pedidosAvisados.add(pedidoId);
        avisar(
          context,
          'Este pedido ya no está pendiente. Actualiza tu lista.',
        );
        return;
      }
      _pedidosAvisados.add(pedidoId);
      final aceptar = await mostrarNuevoPedido(
        context,
        pedido: pedido,
        parte: parte,
        casero: PreferenciasVendedorState.de(widget.usuario),
      );
      if (!mounted) return;
      if (aceptar == true) {
        await _pedidosRepository.aceptarSubpedido(parte.id);
        if (!mounted) return;
        await _cargar();
        if (mounted) context.push('/casero/inicio/pedido/$pedidoId');
      } else if (aceptar == false) {
        final rechazado = await rechazarConMotivo(
          context,
          parte,
          repository: _pedidosRepository,
        );
        if (rechazado && mounted) await _cargar();
      }
    } on PedidoException catch (error) {
      if (mounted) avisar(context, error.mensaje);
    } finally {
      if (mounted) setState(() => _alertaAbierta = false);
    }
  }

  Future<void> _cambiarAbierto(bool valor) async {
    if (_cambiandoEstado) return;
    setState(() => _cambiandoEstado = true);
    try {
      final abierto = await _repository.cambiarAbierto(valor);
      if (!mounted) return;
      final actual = _inicio!;
      setState(() {
        _inicio = VendedorInicio(
          puesto: actual.puesto!.conEstado(abierto),
          atencion: actual.atencion,
          pedidos: actual.pedidos,
          resumen: actual.resumen,
        );
      });
      avisar(
        context,
        abierto
            ? 'Tu puesto está abierto. Ya pueden hacerte pedidos.'
            : 'Tu puesto está cerrado por ahora.',
      );
    } on VendedorInicioException catch (error) {
      if (mounted) avisar(context, error.mensaje);
    } finally {
      if (mounted) setState(() => _cambiandoEstado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.usuario.nombres.trim().split(RegExp(r'\s+')).first;
    if (!_cargando && _error == null && (_inicio?.tienePuesto ?? false)) {
      return Scaffold(body: _conPuesto(_inicio!));
    }
    return Scaffold(
      body: Column(
        children: [
          EncabezadoInicioCasero(
            nombre: nombre,
            puesto: null,
            guardandoEstado: false,
            onCambiarEstado: _cambiarAbierto,
          ),
          Expanded(child: _contenido()),
        ],
      ),
    );
  }

  Widget _contenido() {
    if (_cargando) return const CargandoApp(texto: 'Cargando tu puesto…');
    if (_error != null) {
      return AvisoPantalla(
        icono: Icons.wifi_off_rounded,
        titulo: 'No pudimos cargar tu inicio',
        texto: _error,
        esError: true,
        textoBoton: 'Reintentar',
        alTocar: _cargar,
      );
    }
    if (!(_inicio?.tienePuesto ?? false)) return _sinPuesto();
    return _conPuesto(_inicio!);
  }

  Widget _sinPuesto() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
      children: [
        const _BannerPuesto(),
        const SizedBox(height: 14),
        Semantics(
          container: true,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.azulClaro,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.azul, width: 1.5),
            ),
            child: Column(
              children: [
                const ExcludeSemantics(
                  child: Icon(
                    Icons.storefront_outlined,
                    size: 48,
                    color: AppColors.azul,
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  header: true,
                  child: const Text(
                    'Aún no tienes un puesto',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Elige tu mercado y registra tu puesto. Después podrás agregar productos y recibir pedidos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, height: 1.35),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => context.go('/casero/puesto'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.azul,
            foregroundColor: AppColors.blanco,
            minimumSize: const Size(48, 56),
            padding: const EdgeInsets.all(16),
            textStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          icon: const Icon(Icons.add_business_outlined),
          label: const Text('Crear mi puesto', textAlign: TextAlign.center),
        ),
        const SizedBox(height: 18),
        const TituloSeccion('¿Qué aparecerá aquí?'),
        const SizedBox(height: 8),
        const _PasoVacio(
          icono: Icons.notifications_none_rounded,
          titulo: 'Pedidos que requieren atención',
          texto: 'Nuevos, en preparación y listos para recoger.',
        ),
        const SizedBox(height: 10),
        const _PasoVacio(
          icono: Icons.payments_outlined,
          titulo: 'Resumen de tus ventas',
          texto: 'Ventas, comisión de la aplicación y lo que recibirás.',
        ),
      ],
    );
  }

  Widget _conPuesto(VendedorInicio inicio) {
    final puesto = inicio.puesto!;
    final atencion = inicio.atencion!;
    final resumen = inicio.resumen!;
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          EncabezadoInicioCasero(
            nombre: widget.usuario.nombres.trim().split(RegExp(r'\s+')).first,
            puesto: puesto,
            guardandoEstado: _cambiandoEstado,
            onCambiarEstado: _cambiarAbierto,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_alertaAbierta) ...[
                  Semantics(
                    liveRegion: true,
                    child: const Text(
                      'Consultando o actualizando el pedido…',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const TituloSeccion('Requieren atención'),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: _Conteo(
                        icono: Icons.inbox_rounded,
                        valor: atencion.nuevos,
                        etiqueta: 'Nuevos',
                        color: AppColors.azul,
                        fondo: const Color(0xFFEAF5FD),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Conteo(
                        icono: Icons.schedule_rounded,
                        valor: atencion.preparando,
                        etiqueta: 'Preparando',
                        color: AppColors.azul,
                        fondo: AppColors.blanco,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Conteo(
                        icono: Icons.check_circle_rounded,
                        valor: atencion.listos,
                        etiqueta: 'Listos',
                        color: AppColors.exito,
                        fondo: AppColors.exitoFondo,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const TituloSeccion('Pedidos activos'),
                const SizedBox(height: 7),
                if (inicio.pedidos.isEmpty)
                  const _SinPedidos()
                else
                  for (final pedido in inicio.pedidos) ...[
                    _TarjetaPedido(
                      pedido: pedido,
                      onTap: () => pedido.estado == 'pendiente'
                          ? _mostrarAlerta(pedido.id)
                          : context.push('/casero/inicio/pedido/${pedido.id}'),
                    ),
                    const SizedBox(height: 8),
                  ],
                const SizedBox(height: 6),
                AccesosInicioCasero(
                  onVerPedidos: () => context.go('/casero/pedidos'),
                  onVerCatalogo: () => context.go('/casero/catalogo'),
                ),
                const SizedBox(height: 18),
                const TituloSeccion('Resumen de hoy'),
                const SizedBox(height: 7),
                _Resumen(resumen: resumen),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerPuesto extends StatelessWidget {
  const _BannerPuesto();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Espacio para la futura foto del puesto',
      child: Container(
        constraints: const BoxConstraints(minHeight: 114),
        padding: const EdgeInsets.all(12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFDCE8EF),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(14),
          ),
          border: Border.all(color: AppColors.divisor),
        ),
        child: const _ImagenPendiente(),
      ),
    );
  }
}

class _ImagenPendiente extends StatelessWidget {
  const _ImagenPendiente();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFDCE8EF),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 34,
              color: AppColors.azul,
            ),
            SizedBox(height: 4),
            Text(
              'Espacio para la foto de tu puesto',
              style: TextStyle(
                color: AppColors.textoSecundario,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Conteo extends StatelessWidget {
  const _Conteo({
    required this.icono,
    required this.valor,
    required this.etiqueta,
    required this.color,
    required this.fondo,
  });
  final IconData icono;
  final int valor;
  final String etiqueta;
  final Color color;
  final Color fondo;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$valor $etiqueta',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 94),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divisor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: color, size: 27),
            Text(
              '$valor',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            Text(
              etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _SinPedidos extends StatelessWidget {
  const _SinPedidos();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.blanco,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divisor),
      ),
      child: const Column(
        children: [
          ExcludeSemantics(
            child: Icon(Icons.inbox_outlined, size: 48, color: AppColors.azul),
          ),
          SizedBox(height: 12),
          Text(
            'Todavía no hay pedidos',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.azul,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Aquí aparecerán los pedidos de tus clientes. '
            'Mientras tanto, puedes revisar tus productos en Mi catálogo.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: AppColors.textoSecundario),
          ),
        ],
      ),
    );
  }
}

class _TarjetaPedido extends StatelessWidget {
  const _TarjetaPedido({required this.pedido, required this.onTap});
  final PedidoActivoVendedor pedido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nuevo = pedido.estado == 'pendiente';
    return Semantics(
      button: true,
      label:
          'Pedido de ${pedido.cliente}, ${pedido.productos} productos, ${_estadoLegible(pedido.estado)}',
      child: Material(
        color: AppColors.blanco,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.divisor),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pedido de ${pedido.cliente}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.azul,
                    ),
                  ],
                ),
                Text(
                  '${pedido.productos} ${pedido.productos == 1 ? 'producto' : 'productos'} · ${_detalleTiempo(pedido)}',
                  style: const TextStyle(color: AppColors.textoSecundario),
                ),
                const SizedBox(height: 9),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _EtiquetaEstado(estado: pedido.estado),
                    Text(
                      nuevo ? 'Revisar pedido' : 'Continuar',
                      style: const TextStyle(
                        color: AppColors.azul,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _detalleTiempo(PedidoActivoVendedor pedido) {
    if (pedido.responderAntes != null && pedido.estado == 'pendiente') {
      final hora = TimeOfDay.fromDateTime(pedido.responderAntes!.toLocal());
      final minutos = hora.minute.toString().padLeft(2, '0');
      return 'Responder antes de ${hora.hour}:$minutos';
    }
    return _estadoLegible(pedido.estado);
  }
}

class _EtiquetaEstado extends StatelessWidget {
  const _EtiquetaEstado({required this.estado});
  final String estado;

  @override
  Widget build(BuildContext context) {
    final listo = estado == 'listo';
    final color = listo ? AppColors.exitoTexto : AppColors.azul;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: listo ? AppColors.exitoFondo : const Color(0xFFEAF5FD),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            listo ? Icons.check_circle_outline : Icons.inventory_2_outlined,
            size: 17,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            _estadoLegible(estado),
            style: TextStyle(fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.resumen});
  final ResumenVendedor resumen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.blanco,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divisor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Importe(etiqueta: 'Ventas', centavos: resumen.ventas),
          ),
          const SizedBox(height: 46, child: VerticalDivider()),
          Expanded(
            child: _Importe(etiqueta: 'Comisión', centavos: resumen.comision),
          ),
          const SizedBox(height: 46, child: VerticalDivider()),
          Expanded(
            child: ColoredBox(
              color: AppColors.azulClaro,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: _Importe(
                  etiqueta: 'Recibes',
                  centavos: resumen.recibes,
                  destacado: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Importe extends StatelessWidget {
  const _Importe({
    required this.etiqueta,
    required this.centavos,
    this.destacado = false,
  });
  final String etiqueta;
  final int centavos;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Column(
        children: [
          Text(
            etiqueta,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textoSecundario,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'S/ ${(centavos / 100).toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: destacado ? AppColors.azul : AppColors.texto,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasoVacio extends StatelessWidget {
  const _PasoVacio({
    required this.icono,
    required this.titulo,
    required this.texto,
  });
  final IconData icono;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.blanco,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divisor),
      ),
      child: Row(
        children: [
          Icon(icono, color: AppColors.azul, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  texto,
                  style: const TextStyle(
                    color: AppColors.textoSecundario,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _estadoLegible(String estado) {
  switch (estado) {
    case 'pendiente':
      return 'Nuevo';
    case 'aceptado':
      return 'Aceptado';
    case 'pesando':
      return 'Pesando';
    case 'pesado':
      return 'Pesado';
    case 'en_preparacion':
      return 'Empaquetando';
    case 'listo':
      return 'Listo';
    default:
      return 'En proceso';
  }
}
