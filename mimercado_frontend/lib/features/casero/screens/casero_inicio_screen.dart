import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../core/widgets/encabezado_simple.dart';
import '../../../data/models/cotizacion.dart';
import '../../../data/models/pedido.dart';
import '../../../data/models/puesto.dart';
import '../../../data/models/usuario.dart';
import '../../../data/repositories/catalogo_repository.dart';
import '../../../data/repositories/pedido_repository.dart';
import '../widgets/alerta_pedido.dart';

/// V1 · Inicio del casero: abierto/cerrado, resumen de hoy y pedidos activos.
class CaseroInicioScreen extends StatefulWidget {
  const CaseroInicioScreen({super.key, required this.usuario});
  final Usuario usuario;

  @override
  State<CaseroInicioScreen> createState() => _CaseroInicioScreenState();
}

class _CaseroInicioScreenState extends State<CaseroInicioScreen> {
  final PedidoRepository _pedidos = PedidoRepositoryMock.instancia;
  final CatalogoRepository _catalogo = CatalogoRepositoryMock();

  /// Pedidos que ya se anunciaron con la ventana grande (no repetir la alerta).
  /// Incluye la hora de creación: el pedido real de la demo reemplaza al #345-A
  /// de prueba con los mismos IDs y también debe anunciarse.
  static final Set<String> _yaAvisados = {};

  Puesto? _puesto;
  List<Pedido> _lista = [];
  bool _cargando = true;
  String? _error;
  bool _alertaAbierta = false;

  int get _puestoId => widget.usuario.puestoId ?? 1;

  @override
  void initState() {
    super.initState();
    _pedidos.cambios.addListener(_cargar);
    _cargar();
  }

  @override
  void dispose() {
    _pedidos.cambios.removeListener(_cargar);
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final puesto = await _catalogo.puesto(_puestoId);
      final lista = await _pedidos.pedidosDePuesto(_puestoId);
      if (!mounted) return;
      setState(() {
        _puesto = puesto;
        _lista = lista;
        _cargando = false;
        _error = null;
      });
      _avisarNuevo();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No pudimos cargar tus pedidos. Inténtalo de nuevo.';
      });
    }
  }

  /// V1b: si llegó un pedido nuevo, lo anuncia con la ventana grande.
  Future<void> _avisarNuevo() async {
    if (_alertaAbierta || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    for (final p in _lista) {
      final parte = p.parteDePuesto(_puestoId);
      if (parte == null || parte.estado != EstadoPedidoPuesto.pendiente) {
        continue;
      }
      final clave = '${parte.id}@${p.creadoEn.microsecondsSinceEpoch}';
      if (!_yaAvisados.add(clave)) continue;
      if (!mounted) return;
      _alertaAbierta = true;
      final r = await mostrarNuevoPedido(
        context,
        pedido: p,
        parte: parte,
        casero: widget.usuario,
      );
      _alertaAbierta = false;
      if (!mounted) return;
      if (r == true) {
        await _aceptar(p, parte);
      } else if (r == false) {
        await rechazarConMotivo(context, parte);
      }
      return; // uno a la vez
    }
  }

  Future<void> _aceptar(Pedido p, PedidoPuesto parte) async {
    try {
      await _pedidos.aceptarSubpedido(parte.id);
      if (!mounted) return;
      avisar(context, 'Aceptaste el pedido #${p.codigoCorto}.');
      context.push('/casero/inicio/pedido/${p.id}');
    } on PedidoException catch (e) {
      if (mounted) avisar(context, e.mensaje);
    }
  }

  Future<void> _cambiarAbierto(bool abierto) async {
    try {
      final p = await _catalogo.cambiarAbierto(_puestoId, abierto);
      if (!mounted) return;
      setState(() => _puesto = p);
      avisar(
        context,
        abierto
            ? 'Tu puesto está abierto: ya te pueden pedir.'
            : 'Cerraste tu puesto por hoy.',
      );
    } on CatalogoException catch (e) {
      if (mounted) avisar(context, e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.usuario.nombres.split(' ').first;
    return Scaffold(
      body: Column(
        children: [
          EncabezadoSimple(
            titulo: '¡Hola, $nombre!',
            subtitulo: _puesto?.nombre,
            mostrarAtras: false,
          ),
          Expanded(child: _cuerpo()),
        ],
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando) return const CargandoApp(texto: 'Cargando tus pedidos…');
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
    final hoy = DateTime.now();
    bool esDeHoy(Pedido p) =>
        p.creadoEn.year == hoy.year &&
        p.creadoEn.month == hoy.month &&
        p.creadoEn.day == hoy.day;

    var entregados = 0;
    var vendido = 0.0;
    var neto = 0.0;
    final activos = <Pedido>[];
    for (final p in _lista) {
      final parte = p.parteDePuesto(_puestoId)!;
      if (parte.estado == EstadoPedidoPuesto.recogido && esDeHoy(p)) {
        entregados++;
        final cp = p.cotizacion?.dePuesto(parte.id);
        vendido += cp?.bruto ?? 0;
        neto += cp?.neto ?? 0;
      }
      final terminado =
          parte.estado == EstadoPedidoPuesto.recogido ||
          parte.estado.descartado ||
          !p.estado.activo;
      if (!terminado) activos.add(p);
    }
    final abierto = _puesto?.abierto ?? true;

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          TarjetaApp(
            color: abierto ? AppColors.exitoFondo : AppColors.errorFondo,
            colorBorde: abierto ? AppColors.exitoTexto : AppColors.error,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: abierto,
                onChanged: _cambiarAbierto,
                secondary: Icon(
                  abierto ? Icons.storefront : Icons.lock_clock,
                  size: 32,
                  color: abierto ? AppColors.exitoTexto : AppColors.error,
                ),
                title: Text(
                  abierto ? 'Puesto abierto' : 'Puesto cerrado',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  abierto
                      ? 'Los clientes pueden pedirte'
                      : 'Nadie puede pedirte ahora',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const TituloSeccion('Resumen de hoy'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _Dato(
                  icono: Icons.done_all,
                  valor: '$entregados',
                  texto: entregados == 1
                      ? 'pedido entregado'
                      : 'pedidos entregados',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Dato(
                  icono: Icons.payments_outlined,
                  valor: soles(redondear2(vendido)),
                  texto: 'vendido (recibes ${soles(redondear2(neto))})',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TituloSeccion('Pedidos activos (${activos.length})'),
          const SizedBox(height: 8),
          if (activos.isEmpty)
            const TarjetaApp(
              child: Row(
                children: [
                  Icon(Icons.inbox_outlined, size: 32, color: AppColors.azul),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No tienes pedidos activos. Te avisamos con sonido cuando llegue uno.',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            )
          else
            for (final p in activos) ...[
              TarjetaPedidoCasero(
                pedido: p,
                parte: p.parteDePuesto(_puestoId)!,
                onTap: () => context.push('/casero/inicio/pedido/${p.id}'),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.valor, required this.texto});
  final IconData icono;
  final String valor;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: TarjetaApp(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: AppColors.azul, size: 28),
            Text(
              valor,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            Text(
              texto,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textoSecundario,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de un pedido en las listas del casero (V1 y V6).
class TarjetaPedidoCasero extends StatelessWidget {
  const TarjetaPedidoCasero({
    super.key,
    required this.pedido,
    required this.parte,
    required this.onTap,
  });

  final Pedido pedido;
  final PedidoPuesto parte;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = parte.detalles.length;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: TarjetaApp(
          colorBorde: parte.estado == EstadoPedidoPuesto.pendiente
              ? AppColors.azul
              : AppColors.borde,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '#${pedido.codigoCorto} · ${pedido.clienteNombre}',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.azul,
                    size: 30,
                  ),
                ],
              ),
              Text(
                '$n ${n == 1 ? 'producto' : 'productos'} · ${fechaCorta(pedido.creadoEn)}'
                '${parte.listaMandado != null ? ' · con lista de mandado' : ''}',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textoSecundario,
                ),
              ),
              const SizedBox(height: 8),
              etiquetaDePuesto(parte.estado),
            ],
          ),
        ),
      ),
    );
  }
}
