import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../core/widgets/encabezado_simple.dart';
import '../../../core/widgets/icono_producto.dart';
import '../../../data/models/producto.dart';
import '../../../data/models/usuario.dart';
import '../../../data/repositories/catalogo_repository.dart';
import '../../../data/repositories/catalogo_vendedor_api_repository.dart';

class CatalogoCaseroScreen extends StatefulWidget {
  const CatalogoCaseroScreen({super.key, required this.usuario});
  final Usuario usuario;
  @override
  State<CatalogoCaseroScreen> createState() => _CatalogoCaseroScreenState();
}

class _CatalogoCaseroScreenState extends State<CatalogoCaseroScreen> {
  final _repo = CatalogoVendedorApiRepository.instancia;
  final _busqueda = TextEditingController();
  List<Producto> _productos = [];
  bool _cargando = true;
  String? _error;
  int? _guardando;

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
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final productos = await _repo.cargar();
      if (mounted) {
        setState(() {
          _productos = productos;
          _cargando = false;
        });
      }
    } on CatalogoException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.mensaje;
          _cargando = false;
        });
      }
    }
  }

  Future<void> _editar([Producto? producto]) async {
    final nuevo = await showDialog<Producto>(
      context: context,
      builder: (_) => _DialogoProducto(producto: producto),
    );
    if (nuevo == null || !mounted) return;
    setState(() => _guardando = producto?.id ?? -1);
    try {
      final guardado = producto == null
          ? await _repo.crear(nuevo)
          : await _repo.actualizar(nuevo);
      if (!mounted) return;
      setState(() {
        if (producto == null) {
          _productos = [..._productos, guardado]
            ..sort((a, b) => a.nombre.compareTo(b.nombre));
        } else {
          _productos = [
            for (final p in _productos)
              if (p.id == guardado.id) guardado else p,
          ];
        }
      });
      avisar(
        context,
        producto == null
            ? '${guardado.nombre} fue añadido.'
            : 'Producto actualizado.',
      );
    } on CatalogoException catch (e) {
      if (mounted) avisar(context, e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = null);
    }
  }

  Future<void> _disponibilidad(Producto p, bool valor) async {
    setState(() => _guardando = p.id);
    try {
      final guardado = await _repo.actualizar(p.copyWith(disponible: valor));
      if (mounted) {
        setState(
          () => _productos = [
            for (final x in _productos)
              if (x.id == p.id) guardado else x,
          ],
        );
      }
    } on CatalogoException catch (e) {
      if (mounted) avisar(context, e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _busqueda.text.trim().toLowerCase();
    final visibles = _productos
        .where((p) => p.nombre.toLowerCase().contains(q))
        .toList();
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
              ),
            ),
          ),
          Expanded(child: _cuerpo(visibles)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _guardando == null ? () => _editar() : null,
        backgroundColor: AppColors.azul,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Añadir producto',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
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
    if (_productos.isEmpty) {
      return const AvisoPantalla(
        icono: Icons.inventory_2_outlined,
        titulo: 'Tu catálogo está vacío',
        texto: 'Añade tu primer producto con el botón inferior.',
      );
    }
    if (visibles.isEmpty) {
      return const AvisoPantalla(
        icono: Icons.search_off,
        titulo: 'No encontramos ese producto',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: visibles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final p = visibles[i];
        final ocupado = _guardando == p.id;
        return TarjetaApp(
          colorBorde: p.disponible ? AppColors.borde : AppColors.error,
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconoProducto(valor: p.imagen),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.nombre,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${soles(p.precioUnitario)} / ${p.unidad.simbolo}',
                          style: const TextStyle(fontSize: 17),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: ocupado ? null : () => _editar(p),
                    tooltip: 'Editar ${p.nombre}',
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppColors.azul,
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: p.disponible,
                onChanged: ocupado ? null : (v) => _disponibilidad(p, v),
                secondary: Icon(
                  p.disponible
                      ? Icons.check_circle
                      : Icons.remove_shopping_cart_outlined,
                  color: p.disponible ? AppColors.exitoTexto : AppColors.error,
                ),
                title: Text(
                  p.disponible ? 'Disponible' : 'Agotado',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DialogoProducto extends StatefulWidget {
  const _DialogoProducto({this.producto});
  final Producto? producto;
  @override
  State<_DialogoProducto> createState() => _DialogoProductoState();
}

class _DialogoProductoState extends State<_DialogoProducto> {
  late final _nombre = TextEditingController(
    text: widget.producto?.nombre ?? '',
  );
  late final _precio = TextEditingController(
    text: widget.producto?.precioUnitario.toStringAsFixed(2) ?? '',
  );
  late UnidadMedida _unidad = widget.producto?.unidad ?? UnidadMedida.kg;
  late String _icono = widget.producto?.imagen ?? 'icono:otro';
  String? _error;
  @override
  void dispose() {
    _nombre.dispose();
    _precio.dispose();
    super.dispose();
  }

  void _guardar() {
    final nombre = _nombre.text.trim();
    final precio = double.tryParse(_precio.text.replaceAll(',', '.'));
    if (nombre.length < 2) {
      setState(() => _error = 'Escribe el nombre del producto.');
      return;
    }
    if (precio == null || precio < .1 || precio > 99999.99) {
      setState(() => _error = 'Escribe un precio válido desde S/ 0.10.');
      return;
    }
    final base = widget.producto;
    Navigator.pop(
      context,
      Producto(
        id: base?.id ?? 0,
        puestoId: base?.puestoId ?? 0,
        nombre: nombre,
        unidad: _unidad,
        precioUnitario: precio,
        disponible: base?.disponible ?? true,
        imagen: _icono,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.producto == null ? 'Añadir producto' : 'Editar producto',
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nombre,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _precio,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Precio',
              prefixText: 'S/ ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<UnidadMedida>(
            initialValue: _unidad,
            decoration: const InputDecoration(
              labelText: 'Unidad de venta',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final u in UnidadMedida.values)
                DropdownMenuItem(value: u, child: Text(u.simbolo)),
            ],
            onChanged: (v) => setState(() => _unidad = v!),
          ),
          const SizedBox(height: 16),
          const Text(
            'Ícono del producto',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in iconosProducto.entries)
                ChoiceChip(
                  avatar: Icon(e.value.icono, color: e.value.color),
                  label: Text(e.value.nombre),
                  selected: _icono == e.key,
                  onSelected: (_) => setState(() => _icono = e.key),
                ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _guardar, child: const Text('Guardar')),
    ],
  );
}
