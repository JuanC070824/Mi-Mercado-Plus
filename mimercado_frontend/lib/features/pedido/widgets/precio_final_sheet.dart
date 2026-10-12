import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/botones_app.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../data/models/cotizacion.dart';
import '../../../data/models/pedido.dart';
import '../../../data/repositories/pedido_repository.dart';

/// C5b · Hoja "Confirma el precio final": estimado vs final por puesto, envío,
/// total final y notas del casero. Devuelve true si el cliente aceptó.
Future<bool> mostrarPrecioFinal(BuildContext context, Pedido pedido) async {
  final c = pedido.cotizacion;
  if (c == null) return false;
  final r = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => _HojaPrecio(pedido: pedido, scroll: scroll),
    ),
  );
  return r ?? false;
}

class _HojaPrecio extends StatefulWidget {
  const _HojaPrecio({required this.pedido, required this.scroll});
  final Pedido pedido;
  final ScrollController scroll;

  @override
  State<_HojaPrecio> createState() => _HojaPrecioState();
}

class _HojaPrecioState extends State<_HojaPrecio> {
  bool _aceptando = false;

  Future<void> _aceptar() async {
    setState(() => _aceptando = true);
    try {
      await PedidoRepositoryMock.instancia.aceptarCotizacion(widget.pedido.id);
      if (mounted) Navigator.of(context).pop(true);
    } on PedidoException catch (e) {
      if (!mounted) return;
      setState(() => _aceptando = false);
      avisar(context, e.mensaje);
    }
  }

  Future<void> _duda() async {
    final mensaje = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Escribe a tus caseros',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        children: [
          for (final m in const [
            '¿Por qué cambió el precio?',
            'Quiero menos cantidad',
            'Por favor, llámenme',
          ])
            SimpleDialogOption(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              onPressed: () => Navigator.of(ctx).pop(m),
              child: Text(m, style: const TextStyle(fontSize: 18)),
            ),
        ],
      ),
    );
    if (mensaje != null && mounted) {
      avisar(context, 'Enviamos tu mensaje a los caseros: "$mensaje"');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pedido;
    final c = p.cotizacion!;
    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Center(
          child: Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.borde,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          header: true,
          child: const Text('Tus caseros ya pesaron',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        ),
        const Text('Revisa el precio final antes de que salga tu pedido.',
            style: TextStyle(fontSize: 18)),
        const SizedBox(height: 16),
        for (final parte in p.puestosActivos) ...[
          _Puesto(parte: parte, cotizacion: c.dePuesto(parte.id)),
          const SizedBox(height: 10),
        ],
        for (final parte in p.puestos.where((x) => x.estado.descartado)) ...[
          EtiquetaEstado(
            texto: '${parte.puesto.nombre} no pudo atenderte'
                '${parte.motivoRechazo == null ? '' : ': ${parte.motivoRechazo}'}',
            icono: Icons.block,
            tipo: TipoEstado.error,
          ),
          const SizedBox(height: 10),
        ],
        TarjetaApp(
          child: Column(
            children: [
              FilaMonto(etiqueta: 'Productos (estimado)', monto: p.totalProductosEstimado),
              FilaMonto(etiqueta: 'Productos (final)', monto: c.totalProductos),
              FilaMonto(etiqueta: 'Envío', monto: c.costoEnvio),
              const Divider(color: AppColors.divisor),
              FilaMonto(etiqueta: 'Total final', monto: c.totalCliente, destacado: true),
            ],
          ),
        ),
        const SizedBox(height: 20),
        BotonPrincipal(
          texto: 'Aceptar y continuar',
          cargando: _aceptando,
          onPressed: _aceptar,
        ),
        const SizedBox(height: 10),
        BotonSecundario(texto: 'Tengo una duda', onPressed: _duda),
      ],
    );
  }
}

class _Puesto extends StatelessWidget {
  const _Puesto({required this.parte, required this.cotizacion});
  final PedidoPuesto parte;
  final CotizacionPuesto? cotizacion;

  @override
  Widget build(BuildContext context) {
    final cp = cotizacion;
    final estimado = parte.subtotalEstimado;
    final final_ = cp?.bruto;
    final cambio = final_ != null && final_ != estimado;
    return MergeSemantics(
      child: TarjetaApp(
        colorBorde: cambio ? AppColors.aviso : AppColors.borde,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(parte.puesto.nombre,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            FilaMonto(etiqueta: 'Estimado', monto: estimado),
            if (final_ != null) FilaMonto(etiqueta: 'Final', monto: final_, destacado: true),
            if (cp?.nota != null)
              Text('Nota del casero: "${cp!.nota}"', style: const TextStyle(fontSize: 17)),
            if (cambio)
              EtiquetaEstado(
                texto: final_ > estimado ? 'Subió por el peso real' : 'Bajó por el peso real',
                icono: final_ > estimado ? Icons.trending_up : Icons.trending_down,
                tipo: TipoEstado.aviso,
              ),
          ],
        ),
      ),
    );
  }
}
