import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../core/widgets/encabezado_simple.dart';
import '../../../data/models/producto.dart';
import '../../../data/models/usuario.dart';
import '../../../data/repositories/catalogo_repository.dart';

/// V7 · Mi catálogo: buscar, cambiar precio y Disponible / Agotado.
class CatalogoCaseroScreen extends StatefulWidget {
  const CatalogoCaseroScreen({super.key, required this.usuario});
  final Usuario usuario;

  @override
  State<CatalogoCaseroScreen> createState() => _CatalogoCaseroScreenState();
}

class _CatalogoCaseroScreenState extends State<CatalogoCaseroScreen> {
  final CatalogoRepository _repo = CatalogoRepositoryMock();
  final _busqueda = TextEditingController();
  List<Producto> _productos = [];
  bool _cargando = true;
  String? _error;
  int? _guardando;

  int get _puestoId => widget.usuario.puestoId ?? 1;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final l = await _repo.productosDePuesto(_puestoId);
      if (!mounted) return;
      setState(() {
        _productos = l;
        _cargando = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No pudimos cargar tu catálogo.';
      });
    }
  }

  Future<void> _guardar(Producto nuevo, String aviso) async {
    setState(() => _guardando = nuevo.id);
    try {
      await _repo.actualizarProducto(nuevo);
      if (!mounted) return;
      setState(() {
        _productos = [for (final p in _productos) p.id == nuevo.id ? nuevo : p];
      });
      avisar(context, aviso);
    } on CatalogoException catch (e) {
      if (mounted) avisar(context, e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = null);
    }
  }

  Future<void> _editarPrecio(Producto p) async {
    final precio = await showDialog<double>(
      context: context,
      builder: (ctx) => _DialogoPrecio(producto: p),
    );
    if (precio == null || !mounted) return;
    await _guardar(p.copyWith(precioUnitario: precio),
        'Nuevo precio de ${p.nombre}: ${soles(precio)} / ${p.unidad.simbolo}');
  }

  @override
  Widget build(BuildContext context) {
    final q = _busqueda.text.trim().toLowerCase();
    final visibles = [
      for (final p in _productos)
        if (q.isEmpty || p.nombre.toLowerCase().contains(q)) p,
    ];
    return Scaffold(
      body: Column(
        children: [
          const EncabezadoSimple(titulo: 'Mi catálogo', mostrarAtras: false),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _busqueda,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 18),
              decoration: const InputDecoration(
                labelText: 'Buscar producto',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.borde, width: 1.5),
                ),
              ),
            ),
          ),
          Expanded(child: _cuerpo(visibles)),
        ],
      ),
    );
  }

  Widget _cuerpo(List<Producto> visibles) {
    if (_cargando) return const CargandoApp(texto: 'Cargando tu catálogo…');
    if (_error != null) {
      return AvisoPantalla(
        icono: Icons.wifi_off,
        titulo: _error!,
        esError: true,
        textoBoton: 'Reintentar',
        alTocar: _cargar,
      );
    }
    if (visibles.isEmpty) {
      return const AvisoPantalla(icono: Icons.search_off, titulo: 'No encontramos ese producto');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: visibles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final p = visibles[i];
        final ocupado = _guardando == p.id;
        return TarjetaApp(
          colorBorde: p.disponible ? AppColors.borde : AppColors.error,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: MergeSemantics(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.nombre,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                          Text('${soles(p.precioUnitario)} / ${p.unidad.simbolo}',
                              style: const TextStyle(fontSize: 18)),
                        ],
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: ocupado ? null : () => _editarPrecio(p),
                    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text('Precio',
                        semanticsLabel: 'Cambiar precio de ${p.nombre}',
                        style: const TextStyle(fontSize: 17)),
                  ),
                ],
              ),
              Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: p.disponible,
                  onChanged: ocupado
                      ? null
                      : (v) => _guardar(
                            p.copyWith(disponible: v),
                            v ? '${p.nombre} vuelve a estar disponible.' : '${p.nombre} quedó agotado por hoy.',
                          ),
                  secondary: Icon(
                    p.disponible ? Icons.check_circle : Icons.remove_shopping_cart_outlined,
                    color: p.disponible ? AppColors.exitoTexto : AppColors.error,
                  ),
                  title: Text(p.disponible ? 'Disponible' : 'Agotado',
                      semanticsLabel: '${p.nombre}: ${p.disponible ? 'Disponible' : 'Agotado'}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Ventana para cambiar el precio. Dueña de su TextEditingController, así se
/// libera cuando la ventana termina de cerrarse (y no antes).
class _DialogoPrecio extends StatefulWidget {
  const _DialogoPrecio({required this.producto});
  final Producto producto;

  @override
  State<_DialogoPrecio> createState() => _DialogoPrecioState();
}

class _DialogoPrecioState extends State<_DialogoPrecio> {
  late final _ctrl =
      TextEditingController(text: widget.producto.precioUnitario.toStringAsFixed(2));
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _guardar() {
    final v = double.tryParse(_ctrl.text.replaceAll(',', '.'));
    if (v == null || v < 0.1 || v > 999) {
      setState(() => _error = 'Escribe un precio entre 0.10 y 999.');
      return;
    }
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.producto;
    return AlertDialog(
      title: Text('Precio de ${p.nombre}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        onSubmitted: (_) => _guardar(),
        style: const TextStyle(fontSize: 22),
        decoration: InputDecoration(
          labelText: 'Soles por ${p.unidad.simbolo}',
          prefixText: 'S/ ',
          errorText: _error,
          border: const OutlineInputBorder(),
        ),
      ),
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar', style: TextStyle(fontSize: 18)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.azul, minimumSize: const Size(48, 48)),
          onPressed: _guardar,
          child: const Text('Guardar', style: TextStyle(fontSize: 18)),
        ),
      ],
    );
  }
}
