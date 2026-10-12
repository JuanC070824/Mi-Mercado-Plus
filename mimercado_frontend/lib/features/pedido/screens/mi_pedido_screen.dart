import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/botones_app.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../core/widgets/encabezado_simple.dart';
import '../../../data/models/cotizacion.dart';
import '../../../data/models/pedido.dart';
import '../../../data/models/usuario.dart';
import '../../../data/repositories/pedido_repository.dart';
import '../widgets/precio_final_sheet.dart';

/// Mi pedido: seguimiento del pedido en curso.
/// C5 pesando · C5b confirmar precio final.
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
  bool _cargando = true;
  String? _error;

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
      final p = await _repo.pedidoActivoCliente(widget.usuario.celular);
      if (!mounted) return;
      setState(() {
        _pedido = p;
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
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          ..._ahora(p),
          const SizedBox(height: 20),
          const TituloSeccion('Tus puestos'),
          const SizedBox(height: 8),
          for (final parte in p.puestos) ...[
            _FilaPuesto(parte: parte),
            const SizedBox(height: 8),
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
              label: const Text('¿Qué significa cada paso?',
                  style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sinPedido() => AvisoPantalla(
        icono: Icons.inventory_2_outlined,
        titulo: 'No tienes pedidos en curso',
        texto: 'Cuando hagas un pedido, aquí verás cómo va.',
        textoBoton: 'Ir al mercado',
        alTocar: () => context.go('/inicio'),
      );

  /// Tarjeta "AHORA": qué está pasando, en palabras simples.
  List<Widget> _ahora(Pedido p) {
    final aceptado = p.cotizacion?.estado == EstadoCotizacion.aceptada;
    final String texto = switch (p.estado) {
      EstadoPedido.pendiente => 'Tus caseros están viendo tu pedido.',
      EstadoPedido.enPreparacion when !aceptado =>
        'Tus caseros están pesando tus productos.',
      EstadoPedido.esperandoConfirmacion =>
        'Ya pesaron. Revisa y acepta el precio final para que salga tu pedido.',
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
              const Text('AHORA',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.azul,
                      letterSpacing: 1)),
              const SizedBox(height: 4),
              Text(texto,
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              etiquetaDePedido(p.estado),
            ],
          ),
        ),
      ),
      if (p.estado == EstadoPedido.esperandoConfirmacion) ...[
        const SizedBox(height: 12),
        BotonPrincipal(texto: 'Ver precio final', onPressed: () => _verPrecio(p)),
      ],
    ];
  }

  void _explicarPasos() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Qué significa cada paso?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
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
            Text('${parte.parada}. ${parte.puesto.nombre}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            etiquetaDePuesto(parte.estado),
          ],
        ),
      ),
    );
  }
}
