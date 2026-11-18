import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/config/api_config.dart';
import '../../../core/utils/formato.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../core/widgets/control_cantidad.dart';
import '../../../core/widgets/encabezado_simple.dart';
import '../../../core/widgets/icono_producto.dart';
import '../../../data/models/canasta.dart';
import '../../../data/models/producto.dart';
import '../../../data/models/puesto.dart';
import '../../../data/repositories/canasta_repository.dart';
import '../../../data/repositories/catalogo_api_repository.dart';
import '../../../data/repositories/catalogo_repository.dart';
import '../../../data/repositories/repositorios_app.dart';
import '../widgets/acciones_canasta.dart';
import '../widgets/barra_canasta.dart';

/// C2 · Puesto: productos del casero con "− cantidad +" y la barra de la canasta.
class PuestoScreen extends StatefulWidget {
  const PuestoScreen({super.key, required this.puestoId});
  final int puestoId;

  @override
  State<PuestoScreen> createState() => _PuestoScreenState();
}

class _PuestoScreenState extends State<PuestoScreen> {
  final CatalogoRepository _catalogo = ApiConfig.configurada
      ? CatalogoApiRepository.instancia
      : CatalogoRepositoryMock();
  final CanastaRepository _canasta = canastaApp;

  Puesto? _puesto;
  List<Producto> _productos = [];
  bool _cargando = true;
  String? _error;
  bool _ocupado = false; // evita dobles toques mientras se guarda

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final puesto = await _catalogo.puesto(widget.puestoId);
      final productos = await _catalogo.productosDePuesto(widget.puestoId);
      if (!mounted) return;
      setState(() {
        _puesto = puesto;
        _productos = productos;
        _cargando = false;
        if (puesto == null) _error = 'No encontramos este puesto.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No pudimos cargar los productos. Inténtalo de nuevo.';
      });
    }
  }

  Future<void> _cambiar(Future<Object?> Function() accion) async {
    if (_ocupado || _puesto == null) return;
    setState(() => _ocupado = true);
    await cambiarCanasta(context, _puesto!, accion);
    if (mounted) setState(() => _ocupado = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = _puesto;
    return Scaffold(
      body: Column(
        children: [
          EncabezadoSimple(
            titulo: p?.nombre ?? 'Puesto',
            subtitulo: p == null
                ? null
                : 'Casero: ${p.casero} · ★ ${p.calificacion.toStringAsFixed(1)} '
                      '(${p.resenas} reseñas)',
          ),
          Expanded(child: _cuerpo()),
        ],
      ),
      bottomNavigationBar: const BarraCanasta(),
    );
  }

  Widget _cuerpo() {
    if (_cargando) return const CargandoApp(texto: 'Cargando productos…');
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
    final puesto = _puesto!;
    if (_productos.isEmpty) {
      return AvisoPantalla(
        icono: Icons.inventory_2_outlined,
        titulo: '${puesto.nombre} aún no tiene productos',
        texto: 'Prueba con otro casero del mercado.',
        textoBoton: 'Volver a los caseros',
        alTocar: () => context.pop(),
      );
    }
    return ValueListenableBuilder<Canasta>(
      valueListenable: _canasta.canasta,
      builder: (context, canasta, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (!puesto.abierto) ...[
            const EtiquetaEstado(
              texto: 'Puesto cerrado ahora: puedes mirar, pero no comprar',
              icono: Icons.lock_clock,
              tipo: TipoEstado.aviso,
            ),
            const SizedBox(height: 12),
          ],
          const TituloSeccion('Productos'),
          const SizedBox(height: 4),
          const Text(
            'Precio estimado. El casero pesa y te confirma el precio final.',
            style: TextStyle(fontSize: 16, color: AppColors.textoSecundario),
          ),
          const SizedBox(height: 12),
          for (final prod in _productos) ...[
            _TarjetaProducto(
              producto: prod,
              cantidad: canasta.cantidadDe(prod.id),
              habilitado: puesto.abierto && !_ocupado,
              onSumar: () => _cambiar(() => _canasta.agregar(puesto, prod)),
              onRestar: () => _cambiar(() => _canasta.restar(prod)),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          TarjetaApp(
            color: AppColors.azulClaro,
            colorBorde: AppColors.azul,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¿Algo más de otro puesto?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Un solo repartidor recoge en todos los puestos del mercado.',
                  style: TextStyle(fontSize: 17),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => context.pop(),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text(
                    'Volver a los caseros',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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

class _TarjetaProducto extends StatelessWidget {
  const _TarjetaProducto({
    required this.producto,
    required this.cantidad,
    required this.habilitado,
    required this.onSumar,
    required this.onRestar,
  });

  final Producto producto;
  final double cantidad;
  final bool habilitado;
  final VoidCallback onSumar;
  final VoidCallback onRestar;

  @override
  Widget build(BuildContext context) {
    final unidad = producto.unidad;
    final precio = '${soles(producto.precioUnitario)} / ${unidad.simbolo}';
    return TarjetaApp(
      colorBorde: cantidad > 0 ? AppColors.azul : AppColors.borde,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconoProducto(valor: producto.imagen),
              const SizedBox(width: 12),
              Expanded(
                child: MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        producto.nombre,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.texto,
                        ),
                      ),
                      Text(
                        precio,
                        style: const TextStyle(
                          fontSize: 17,
                          color: AppColors.textoSecundario,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!producto.disponible)
            const EtiquetaEstado(
              texto: 'Agotado por hoy',
              icono: Icons.remove_shopping_cart_outlined,
              tipo: TipoEstado.error,
            )
          else if (cantidad == 0)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: habilitado ? onSumar : null,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  side: const BorderSide(color: AppColors.azul, width: 2),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.add_shopping_cart),
                label: Text(
                  'Agregar ${cantidadConUnidad(unidad.paso, unidad)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                ControlCantidad(
                  cantidad: cantidad,
                  unidad: unidad,
                  nombre: producto.nombre,
                  onRestar: habilitado ? onRestar : null,
                  onSumar: habilitado ? onSumar : null,
                ),
                Text(
                  'Subtotal ${soles(cantidad * producto.precioUnitario)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.texto,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
