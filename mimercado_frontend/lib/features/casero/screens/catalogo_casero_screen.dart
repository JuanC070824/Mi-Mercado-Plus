import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';
import '../../../core/widgets/componentes_app.dart';
import '../widgets/encabezado_pedido_casero.dart';
import '../../../core/widgets/icono_producto.dart';
import '../../../data/models/producto.dart';
import '../../../data/models/usuario.dart';
import '../../../data/repositories/catalogo_repository.dart';
import '../../../data/repositories/catalogo_vendedor_api_repository.dart';

class CatalogoCaseroScreen extends StatefulWidget {
  const CatalogoCaseroScreen({
    super.key,
    required this.usuario,
    this.repository,
  });
  final Usuario usuario;
  final CatalogoVendedorApiRepository? repository;
  @override
  State<CatalogoCaseroScreen> createState() => _CatalogoCaseroScreenState();
}

class _CatalogoCaseroScreenState extends State<CatalogoCaseroScreen> {
  late final _repo =
      widget.repository ?? CatalogoVendedorApiRepository.instancia;
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

  bool _editando = false;
  int _filtro = 0;
  Future<void> _editar([Producto? producto]) async {
    if (_editando || _guardando != null || _cargando || _error != null) return;
    setState(() => _editando = true);
    try {
      final guardado = await showDialog<Producto>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _DialogoProducto(
          producto: producto,
          guardar: producto == null ? _repo.crear : _repo.actualizar,
        ),
      );
      if (!mounted || guardado == null) return;
      setState(() {
        _productos = [
          for (final p in _productos)
            if (p.id != guardado.id) p,
          guardado,
        ]..sort((a, b) => a.nombre.compareTo(b.nombre));
      });
      avisar(
        context,
        producto == null
            ? '${guardado.nombre} fue añadido.'
            : 'Producto actualizado.',
      );
    } finally {
      if (mounted) setState(() => _editando = false);
    }
  }

  Future<void> _disponibilidad(Producto p, bool valor) async {
    if (_guardando != null || _editando) return;
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
        .where(
          (p) =>
              p.nombre.toLowerCase().contains(q) &&
              (_filtro == 0 || (_filtro == 1 ? p.disponible : !p.disponible)),
        )
        .toList();
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                EncabezadoPedidoCasero(
                  titulo: 'Mi catálogo',
                  mostrarAtras: false,
                  subtitulo: '${_productos.length} productos',
                ),
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
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final (i, texto) in const [
                        (0, 'Todos'),
                        (1, 'Disponibles'),
                        (2, 'Agotados'),
                      ])
                        ChoiceChip(
                          label: Text(texto),
                          selected: _filtro == i,
                          onSelected: (_) => setState(() => _filtro = i),
                        ),
                      OutlinedButton.icon(
                        onPressed: _cargando || _guardando != null || _editando
                            ? null
                            : _cargar,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Actualizar'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      padding: const EdgeInsets.all(12),
                    ),
                    onPressed:
                        _cargando ||
                            _error != null ||
                            _guardando != null ||
                            _editando
                        ? null
                        : () => _editar(),
                    icon: const Icon(Icons.add),
                    label: const Text(
                      'Añadir producto',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _cuerpo(visibles),
        ],
      ),
    );
  }

  Widget _cuerpo(List<Producto> visibles) {
    if (_cargando) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: CargandoApp(texto: 'Cargando tu catálogo…'),
      );
    }
    if (_error != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: AvisoPantalla(
          icono: Icons.wifi_off,
          titulo: _error!,
          esError: true,
          textoBoton: 'Reintentar',
          alTocar: _cargar,
        ),
      );
    }
    if (_productos.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: AvisoPantalla(
          icono: Icons.inventory_2_outlined,
          titulo: 'Tu catálogo está vacío',
          texto: 'Usa Añadir producto para comenzar.',
        ),
      );
    }
    if (visibles.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: AvisoPantalla(
          icono: Icons.search_off,
          titulo: 'No encontramos ese producto',
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      sliver: SliverList.separated(
        itemCount: visibles.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final p = visibles[i];
          final ocupado = _guardando != null || _editando;
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
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: p.disponible,
                    onChanged: ocupado ? null : (v) => _disponibilidad(p, v),
                    secondary: Icon(
                      p.disponible
                          ? Icons.check_circle
                          : Icons.remove_shopping_cart_outlined,
                      color: p.disponible
                          ? AppColors.exitoTexto
                          : AppColors.error,
                    ),
                    title: Text(
                      p.disponible ? 'Disponible' : 'Agotado',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DialogoProducto extends StatefulWidget {
  const _DialogoProducto({this.producto, required this.guardar});
  final Producto? producto;
  final Future<Producto> Function(Producto) guardar;
  @override
  State<_DialogoProducto> createState() => _DialogoProductoState();
}

class _DialogoProductoState extends State<_DialogoProducto> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(
    text: widget.producto?.nombre ?? '',
  );
  late final _precio = TextEditingController(
    text: widget.producto?.precioUnitario.toStringAsFixed(2) ?? '',
  );
  late UnidadMedida _unidad = widget.producto?.unidad ?? UnidadMedida.kg;
  late String _icono = widget.producto?.imagen ?? 'icono:otro';
  bool _guardando = false;
  bool _finalizado = false;
  String? _error;
  @override
  void dispose() {
    _nombre.dispose();
    _precio.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando ||
        _finalizado ||
        !(_form.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    final base = widget.producto;
    final producto = Producto(
      id: base?.id ?? 0,
      puestoId: base?.puestoId ?? 0,
      nombre: _nombre.text.trim(),
      unidad: _unidad,
      precioUnitario: double.parse(_precio.text.trim().replaceAll(',', '.')),
      disponible: base?.disponible ?? true,
      imagen: _icono,
    );
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final guardado = await widget.guardar(producto);
      if (!mounted) return;
      setState(() => _finalizado = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.of(context).pop(guardado);
    } on CatalogoException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.mensaje;
          _guardando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_guardando || _finalizado,
    child: Dialog(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.producto == null ? 'Añadir producto' : 'Editar producto',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Nombre del producto', style: TextStyle(fontSize: 18)),
              TextFormField(
                key: const ValueKey('nombre_producto'),
                controller: _nombre,
                enabled: !_guardando,
                maxLength: 150,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 19),
                validator: (v) => (v ?? '').trim().length < 2
                    ? 'Escribe un nombre de al menos 2 letras.'
                    : null,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  errorMaxLines: 3,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Precio por unidad de venta',
                style: TextStyle(fontSize: 18),
              ),
              TextFormField(
                key: const ValueKey('precio_producto'),
                controller: _precio,
                enabled: !_guardando,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(fontSize: 19),
                validator: (v) {
                  final valor = (v ?? '').trim();
                  final precio = double.tryParse(valor.replaceAll(',', '.'));
                  return !RegExp(r'^\d{1,5}([.,]\d{1,2})?$').hasMatch(valor) ||
                          precio == null ||
                          !precio.isFinite ||
                          precio < .10 ||
                          precio > 99999.99
                      ? 'Usa entre S/ 0.10 y S/ 99999.99, con hasta 2 decimales.'
                      : null;
                },
                decoration: const InputDecoration(
                  prefixText: 'S/ ',
                  border: OutlineInputBorder(),
                  errorMaxLines: 5,
                ),
              ),
              const SizedBox(height: 12),
              const Text('Unidad de venta', style: TextStyle(fontSize: 18)),
              DropdownButtonFormField<UnidadMedida>(
                initialValue: _unidad,
                isExpanded: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: [
                  for (final u in UnidadMedida.values)
                    DropdownMenuItem(
                      value: u,
                      child: Text(
                        u.simbolo,
                        style: const TextStyle(fontSize: 19),
                      ),
                    ),
                ],
                onChanged: _guardando
                    ? null
                    : (v) => setState(() => _unidad = v!),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ícono del producto',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in iconosProducto.entries)
                    ChoiceChip(
                      avatar: Icon(e.value.icono, color: e.value.color),
                      label: Text(e.value.nombre),
                      selected: _icono == e.key,
                      onSelected: _guardando
                          ? null
                          : (_) => setState(() => _icono = e.key),
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                    ),
                ],
              ),
              if (_error != null)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 18,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 56),
                  padding: const EdgeInsets.all(16),
                ),
                onPressed: _guardando ? null : _guardar,
                child: Text(
                  _guardando ? 'Guardando producto…' : 'Guardar producto',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: _guardando
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('Cancelar', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
