import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';
import '../../../core/widgets/botones_app.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../core/widgets/control_cantidad.dart';
import '../../../core/widgets/encabezado_simple.dart';
import '../../../core/widgets/mensaje_error.dart';
import '../../../data/models/cotizacion.dart';
import '../../../data/models/pedido.dart';
import '../../../data/models/usuario.dart';
import '../../../data/repositories/pedido_repository.dart';
import '../../../data/repositories/pedidos_vendedor_api_repository.dart';
import '../widgets/alerta_pedido.dart';

/// V3 · Pesar y poner precio: balanza "− kg +" por producto, "Así lo verá"
/// el cliente y "Enviar precio final" (crea la cotización del puesto).
class PesarScreen extends StatefulWidget {
  const PesarScreen({super.key, required this.pedidoId, required this.usuario});
  final int pedidoId;
  final Usuario usuario;

  @override
  State<PesarScreen> createState() => _PesarScreenState();
}

class _PesarScreenState extends State<PesarScreen> {
  final PedidosVendedorApiRepository _repo =
      PedidosVendedorApiRepository.instancia;
  final _nota = TextEditingController();

  Pedido? _pedido;
  PedidoPuesto? _parte;
  bool _cargando = true;
  bool _enviando = false;
  String? _error;

  /// Peso real de la balanza por detalle (id → cantidad).
  final Map<int, double> _peso = {};

  /// Nombre del producto que se ofrece en lugar del pedido (solo "Ofrezco otro").
  final Map<int, TextEditingController> _reemplazos = {};

  int get _puestoId => widget.usuario.puestoId ?? 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _nota.dispose();
    for (final c in _reemplazos.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    final lista = await _repo.pedidosDePuesto(_puestoId);
    if (!mounted) return;
    final p = lista.where((x) => x.id == widget.pedidoId).firstOrNull;
    final parte = p?.parteDePuesto(_puestoId);
    setState(() {
      _pedido = p;
      _parte = parte;
      _cargando = false;
      for (final d in parte?.detalles ?? const <PedidoDetalle>[]) {
        _peso[d.id] = d.cantidadSolicitada;
        if (d.disponibilidad == Disponibilidad.reemplazo) {
          _reemplazos[d.id] = TextEditingController(
            text: '${d.nombre} (otra variedad)',
          );
        }
      }
    });
  }

  /// Productos que sí se entregan (sin los "Sin stock").
  List<PedidoDetalle> get _aPesar => [
    for (final d in _parte?.detalles ?? const <PedidoDetalle>[])
      if (d.disponibilidad != Disponibilidad.sinStock) d,
  ];

  List<CotizacionDetalle> get _cotizacion => [
    for (final d in _aPesar)
      CotizacionDetalle(
        pedidoDetalleId: d.id,
        nombreFinal: _reemplazos[d.id]?.text.trim().isNotEmpty == true
            ? _reemplazos[d.id]!.text.trim()
            : d.nombre,
        cantidadReal: _peso[d.id]!,
        precioUnitario: d.precioEstimadoUnitario,
      ),
  ];

  double get _totalFinal =>
      redondear2(_cotizacion.fold(0.0, (s, d) => s + d.subtotal));

  Future<void> _enviar() async {
    final parte = _parte!;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await _repo.enviarPrecioFinal(parte.id, _cotizacion, nota: _nota.text);
      if (!mounted) return;
      avisar(
        context,
        'Enviaste el precio final. Te avisamos cuando ${_pedido!.clienteNombre} lo acepte.',
      );
      context.pop();
    } on PedidoException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          EncabezadoSimple(
            titulo: 'Pesar y poner precio',
            subtitulo: _pedido == null
                ? null
                : 'Pedido de ${_pedido!.clienteNombre}',
          ),
          Expanded(child: _cuerpo()),
        ],
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando) return const CargandoApp();
    final p = _pedido;
    final parte = _parte;
    if (p == null || parte == null) {
      return const AvisoPantalla(
        icono: Icons.search_off,
        titulo: 'No encontramos este pedido',
      );
    }
    if (parte.estado != EstadoPedidoPuesto.aceptado &&
        parte.estado != EstadoPedidoPuesto.pesando) {
      return AvisoPantalla(
        icono: Icons.check_circle,
        titulo: 'Este pedido ya tiene precio final',
        textoBoton: 'Volver al pedido',
        alTocar: () => context.pop(),
      );
    }
    if (_aPesar.isEmpty) {
      return AvisoPantalla(
        icono: Icons.remove_shopping_cart_outlined,
        titulo: 'No tienes ningún producto',
        texto:
            'Marcaste todo como "Sin stock". Es mejor rechazar el pedido para que '
            'el cliente lo pida en otro puesto.',
        textoBoton: 'Rechazar pedido',
        alTocar: () async {
          if (await rechazarConMotivo(context, parte, repository: _repo) &&
              mounted)
            context.pop();
        },
      );
    }

    final nombre = p.clienteNombre.split(' ').first;
    final estimado = parte.subtotalEstimado;
    final finalTotal = _totalFinal;
    final sinStock = parte.detalles.where(
      (d) => d.disponibilidad == Disponibilidad.sinStock,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const Text(
          'Pon cada producto en la balanza y ajusta el peso real con − y +.',
          style: TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 12),
        for (final d in _aPesar) ...[
          TarjetaApp(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.nombre,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Pidió ${cantidadConUnidad(d.cantidadSolicitada, d.unidad)} · '
                  '${soles(d.precioEstimadoUnitario)} / ${d.unidad.simbolo}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textoSecundario,
                  ),
                ),
                if (_reemplazos.containsKey(d.id)) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reemplazos[d.id],
                    style: const TextStyle(fontSize: 18),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: '¿Qué le ofreces en su lugar?',
                      prefixIcon: Icon(Icons.swap_horiz),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: AppColors.borde,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ControlCantidad(
                      cantidad: _peso[d.id]!,
                      unidad: d.unidad,
                      nombre: d.nombre,
                      onRestar: _peso[d.id]! > d.unidad.paso
                          ? () => setState(
                              () => _peso[d.id] = _peso[d.id]! - d.unidad.paso,
                            )
                          : null,
                      onSumar: () => setState(
                        () => _peso[d.id] = _peso[d.id]! + d.unidad.paso,
                      ),
                    ),
                    Text(
                      soles(_peso[d.id]! * d.precioEstimadoUnitario),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (sinStock.isNotEmpty) ...[
          EtiquetaEstado(
            texto:
                'Sin stock (no se cobra): ${sinStock.map((d) => d.nombre).join(', ')}',
            icono: Icons.remove_shopping_cart_outlined,
            tipo: TipoEstado.error,
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _nota,
          maxLength: 120,
          style: const TextStyle(fontSize: 18),
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Nota para el cliente (opcional)',
            hintText: 'Ej.: el tomate pesó 1.5 kg',
            border: OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.borde, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // "Así lo verá María"
        TarjetaApp(
          color: AppColors.azulClaro,
          colorBorde: AppColors.azul,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.visibility_outlined, color: AppColors.azul),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Así lo verá $nombre',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilaMonto(etiqueta: 'Estimado', monto: estimado),
              FilaMonto(
                etiqueta: 'Precio final',
                monto: finalTotal,
                destacado: true,
              ),
              if (finalTotal != estimado)
                Text(
                  finalTotal > estimado
                      ? 'Sube ${soles(finalTotal - estimado)} por el peso real.'
                      : 'Baja ${soles(estimado - finalTotal)}.',
                  style: const TextStyle(fontSize: 16),
                ),
              if (_nota.text.trim().isNotEmpty)
                Text(
                  'Nota: "${_nota.text.trim()}"',
                  style: const TextStyle(fontSize: 16),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_error != null) ...[
          MensajeError(_error!),
          const SizedBox(height: 12),
        ],
        BotonPrincipal(
          texto: 'Enviar precio final',
          cargando: _enviando,
          onPressed: _enviar,
        ),
      ],
    );
  }
}
