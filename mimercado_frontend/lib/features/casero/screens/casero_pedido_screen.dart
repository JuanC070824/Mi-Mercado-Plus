import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';
import '../../../core/widgets/botones_app.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../core/widgets/encabezado_simple.dart';
import '../../../data/models/pedido.dart';
import '../../../data/models/usuario.dart';
import '../../../data/repositories/pedido_repository.dart';
import '../widgets/alerta_pedido.dart';
import '../widgets/llamar_dialog.dart';

/// Detalle de un pedido para el casero. Muestra lo que toca hacer según el
/// estado de SU parte: aceptar/rechazar (V1b/V1c), revisar (V2), pesar (V3),
/// empaquetar (V4) y entregar al repartidor (V5).
class CaseroPedidoScreen extends StatefulWidget {
  const CaseroPedidoScreen({super.key, required this.pedidoId, required this.usuario});
  final int pedidoId;
  final Usuario usuario;

  @override
  State<CaseroPedidoScreen> createState() => _CaseroPedidoScreenState();
}

class _CaseroPedidoScreenState extends State<CaseroPedidoScreen> {
  final PedidoRepository _repo = PedidoRepositoryMock.instancia;

  Pedido? _pedido;
  bool _cargando = true;
  bool _ocupado = false;

  int get _puestoId => widget.usuario.puestoId ?? 1;

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
    final lista = await _repo.pedidosDePuesto(_puestoId);
    if (!mounted) return;
    setState(() {
      _pedido = lista.where((p) => p.id == widget.pedidoId).firstOrNull;
      _cargando = false;
    });
  }

  /// Ejecuta una acción del repositorio mostrando el error si falla.
  Future<void> _hacer(Future<void> Function() accion, {String? exito}) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      await accion();
      if (mounted && exito != null) avisar(context, exito);
    } on PedidoException catch (e) {
      if (mounted) avisar(context, e.mensaje);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _pedido;
    return Scaffold(
      body: Column(
        children: [
          EncabezadoSimple(titulo: p == null ? 'Pedido' : 'Pedido #${p.codigoCorto}'),
          Expanded(child: _cuerpo()),
        ],
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando) return const CargandoApp();
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
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
                child: Text(p.clienteNombre,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              IconButton.outlined(
                tooltip: 'Llamar a ${p.clienteNombre}',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: () =>
                    mostrarLlamar(context, nombre: p.clienteNombre, celular: p.clienteCelular),
                icon: const Icon(Icons.call, color: AppColors.azul),
              ),
            ],
          ),
          Text(
            '${fechaCorta(p.creadoEn)} · Bolsa ${parte.codigoBolsa}',
            style: const TextStyle(fontSize: 16, color: AppColors.textoSecundario),
          ),
          const SizedBox(height: 8),
          etiquetaDePuesto(parte.estado),
          if (compartido != null) ...[
            const SizedBox(height: 8),
            EtiquetaEstado(texto: compartido, icono: Icons.people_outline, tipo: TipoEstado.info),
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
          Text('Estimado: ${soles(parte.subtotalEstimado)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          BotonPrincipal(
            texto: 'Aceptar pedido',
            cargando: _ocupado,
            onPressed: () => _hacer(() => _repo.aceptarSubpedido(parte.id),
                exito: 'Aceptaste el pedido. Ahora revisa los productos.'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error, width: 2),
              minimumSize: const Size(48, 56),
              shape: const StadiumBorder(),
            ),
            onPressed: _ocupado ? null : () => rechazarConMotivo(context, parte),
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
            texto: parte.motivoRechazo == null ? null : 'Motivo: ${parte.motivoRechazo}',
          ),
        ];
      default:
        return [
          const TituloSeccion('Productos'),
          const SizedBox(height: 8),
          ListaProductosParte(parte: parte),
        ];
    }
  }
}
