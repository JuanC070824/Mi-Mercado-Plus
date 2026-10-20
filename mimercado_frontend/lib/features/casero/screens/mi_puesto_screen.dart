import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/botones_app.dart';
import '../../../core/widgets/campo_texto_app.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../core/widgets/encabezado_simple.dart';
import '../../../core/widgets/mensaje_error.dart';
import '../../../data/models/usuario.dart';
import '../../../data/repositories/puesto_vendedor_repository.dart';

class MiPuestoScreen extends StatefulWidget {
  const MiPuestoScreen({
    super.key,
    required this.usuario,
    required this.onPuestoGuardado,
  });

  final Usuario usuario;
  final ValueChanged<PuestoDelVendedor> onPuestoGuardado;

  @override
  State<MiPuestoScreen> createState() => _MiPuestoScreenState();
}

class _MiPuestoScreenState extends State<MiPuestoScreen> {
  final _repository = PuestoVendedorApiRepository.instancia;
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _numero = TextEditingController();
  final _referencia = TextEditingController();
  final _busqueda = TextEditingController();

  DatosPuestoVendedor? _datos;
  MercadoParaPuesto? _mercado;
  int? _categoriaId;
  bool _cargando = true;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _busqueda.addListener(_actualizarBusqueda);
    _cargar();
  }

  @override
  void dispose() {
    _busqueda.removeListener(_actualizarBusqueda);
    _nombre.dispose();
    _numero.dispose();
    _referencia.dispose();
    _busqueda.dispose();
    super.dispose();
  }

  void _actualizarBusqueda() => setState(() {});

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await _repository.cargar();
      if (!mounted) return;
      final puesto = datos.puesto;
      setState(() {
        _datos = datos;
        _mercado = puesto?.mercado;
        _categoriaId = puesto?.categoria.id;
        _nombre.text = puesto?.nombre ?? '';
        _numero.text = puesto?.numero ?? '';
        _referencia.text = puesto?.referencia ?? '';
        _cargando = false;
      });
    } on PuestoVendedorException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.mensaje;
        _cargando = false;
      });
    }
  }

  List<MercadoParaPuesto> get _mercadosFiltrados {
    final consulta = _busqueda.text.trim().toLowerCase();
    final mercados = _datos?.mercados ?? const [];
    if (consulta.isEmpty) return mercados;
    return mercados.where((mercado) {
      final texto =
          '${mercado.nombre} ${mercado.direccion} ${mercado.distrito ?? ''}'
              .toLowerCase();
      return texto.contains(consulta);
    }).toList();
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (_mercado == null) {
      setState(() => _error = 'Selecciona el mercado donde está tu puesto.');
      return;
    }
    if (_categoriaId == null) {
      setState(
        () => _error = 'Selecciona la categoría principal de tu puesto.',
      );
      return;
    }
    setState(() => _guardando = true);
    final creando = _datos?.puesto == null;
    try {
      final puesto = await _repository.guardar(
        puestoId: _datos?.puesto?.id,
        mercadoId: _mercado!.id,
        categoriaId: _categoriaId!,
        nombre: _nombre.text.trim(),
        numero: _numero.text.trim(),
        referencia: _referencia.text.trim(),
      );
      if (!mounted) return;
      widget.onPuestoGuardado(puesto);
      setState(() {
        _datos = DatosPuestoVendedor(
          mercados: _datos!.mercados,
          categorias: _datos!.categorias,
          puesto: puesto,
        );
        _mercado = puesto.mercado;
        _categoriaId = puesto.categoria.id;
        _guardando = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            creando
                ? 'Puesto creado correctamente.'
                : 'Puesto guardado correctamente.',
          ),
        ),
      );
    } on PuestoVendedorException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.mensaje;
        _guardando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const EncabezadoSimple(titulo: 'Mi puesto', mostrarAtras: false),
          Expanded(child: _contenido()),
        ],
      ),
    );
  }

  Widget _contenido() {
    if (_cargando) return const CargandoApp(texto: 'Cargando tu puesto…');
    if (_datos == null) {
      return AvisoPantalla(
        icono: Icons.wifi_off_rounded,
        titulo: 'No pudimos cargar tu puesto',
        texto: _error,
        esError: true,
        textoBoton: 'Reintentar',
        alTocar: _cargar,
      );
    }
    final editando = _datos!.puesto != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AccesoPerfil(
                nombre: widget.usuario.nombreCompleto,
                onTap: () => context.push('/casero/puesto/perfil'),
              ),
              const SizedBox(height: 18),
              _BannerVacio(fotoUrl: _datos!.puesto?.fotoUrl),
              const SizedBox(height: 18),
              Text(
                editando ? 'Información del puesto' : 'Crea tu puesto',
                style: const TextStyle(
                  color: AppColors.azul,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                editando
                    ? 'Puedes corregir estos datos cuando sea necesario.'
                    : 'Elige el mercado y completa los datos para comenzar.',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textoSecundario,
                ),
              ),
              const SizedBox(height: 18),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CampoTextoApp(
                      etiqueta: 'Nombre del puesto',
                      hint: 'Ej.: Verdulería Doña Rosa',
                      controller: _nombre,
                      maxLongitud: 150,
                      mostrarContador: true,
                      icono: Icons.storefront_outlined,
                      mayusculas: TextCapitalization.words,
                      validator: (valor) => Validadores.requerido(
                        valor,
                        campo: 'El nombre del puesto',
                      ),
                    ),
                    const SizedBox(height: 16),
                    CampoTextoApp(
                      etiqueta: 'Número del puesto (opcional)',
                      hint: 'Ej.: A-12',
                      controller: _numero,
                      maxLongitud: 30,
                      mostrarContador: true,
                      icono: Icons.tag,
                    ),
                    const SizedBox(height: 20),
                    const _TituloFormulario(
                      icono: Icons.location_on_outlined,
                      texto: 'Mercado y dirección',
                    ),
                    const SizedBox(height: 10),
                    CampoTextoApp(
                      etiqueta: 'Buscar mercado',
                      hint: 'Escribe el nombre o la dirección',
                      controller: _busqueda,
                      icono: Icons.search,
                    ),
                    const SizedBox(height: 10),
                    _ListaMercados(
                      mercados: _mercadosFiltrados,
                      seleccionado: _mercado?.id,
                      onSeleccionar: (mercado) {
                        setState(() => _mercado = mercado);
                      },
                    ),
                    if (_mercado != null) ...[
                      const SizedBox(height: 12),
                      _DireccionSeleccionada(mercado: _mercado!),
                    ],
                    const SizedBox(height: 18),
                    DropdownButtonFormField<int>(
                      initialValue: _categoriaId,
                      isExpanded: true,
                      decoration: _decoracion(
                        'Categoría principal',
                        Icons.category_outlined,
                      ),
                      items: [
                        for (final categoria in _datos!.categorias)
                          DropdownMenuItem(
                            value: categoria.id,
                            child: Text(categoria.nombre),
                          ),
                      ],
                      onChanged: (valor) =>
                          setState(() => _categoriaId = valor),
                      validator: (valor) => valor == null
                          ? 'Selecciona la categoría principal.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    CampoTextoApp(
                      etiqueta: 'Referencia para encontrar el puesto',
                      hint: 'Ej.: Pasillo 2, junto a la entrada',
                      controller: _referencia,
                      maxLongitud: 300,
                      mostrarContador: true,
                      icono: Icons.assistant_direction_outlined,
                      accion: TextInputAction.done,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      MensajeError(_error!),
                    ],
                    const SizedBox(height: 20),
                    BotonPrincipal(
                      texto: editando ? 'Guardar cambios' : 'Crear mi puesto',
                      cargando: _guardando,
                      onPressed: _guardar,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoracion(String etiqueta, IconData icono) {
    return InputDecoration(
      labelText: etiqueta,
      prefixIcon: Icon(icono, color: AppColors.azul),
      filled: true,
      fillColor: AppColors.blanco,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: AppColors.azul, width: 1.5),
      ),
    );
  }
}

class _AccesoPerfil extends StatelessWidget {
  const _AccesoPerfil({required this.nombre, required this.onTap});
  final String nombre;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.azulClaro,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.azul,
                foregroundColor: AppColors.blanco,
                child: Icon(Icons.person_outline),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mi perfil',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textoSecundario),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.azul),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerVacio extends StatelessWidget {
  const _BannerVacio({this.fotoUrl});
  final String? fotoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFDCE8EF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divisor),
      ),
      child: fotoUrl == null
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 38,
                    color: AppColors.azul,
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Aquí irá la foto de tu puesto',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'La añadiremos en el paso de imágenes',
                    style: TextStyle(color: AppColors.textoSecundario),
                  ),
                ],
              ),
            )
          : Image.network(
              fotoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 40,
                  color: AppColors.azul,
                ),
              ),
            ),
    );
  }
}

class _TituloFormulario extends StatelessWidget {
  const _TituloFormulario({required this.icono, required this.texto});
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, color: AppColors.azul),
        const SizedBox(width: 8),
        Text(
          texto,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _ListaMercados extends StatelessWidget {
  const _ListaMercados({
    required this.mercados,
    required this.seleccionado,
    required this.onSeleccionar,
  });
  final List<MercadoParaPuesto> mercados;
  final int? seleccionado;
  final ValueChanged<MercadoParaPuesto> onSeleccionar;

  @override
  Widget build(BuildContext context) {
    if (mercados.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No encontramos mercados con esa búsqueda.',
          style: TextStyle(color: AppColors.textoSecundario),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 230),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: mercados.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final mercado = mercados[index];
          final activo = mercado.id == seleccionado;
          return Semantics(
            button: true,
            selected: activo,
            label: '${mercado.nombre}, ${mercado.direccion}',
            child: Material(
              color: activo ? AppColors.azulClaro : AppColors.blanco,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: activo ? AppColors.azul : AppColors.divisor,
                  width: activo ? 2 : 1,
                ),
              ),
              child: ListTile(
                onTap: () => onSeleccionar(mercado),
                minTileHeight: 64,
                leading: Icon(
                  activo
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: AppColors.azul,
                ),
                title: Text(
                  mercado.nombre,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(mercado.direccion),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DireccionSeleccionada extends StatelessWidget {
  const _DireccionSeleccionada({required this.mercado});
  final MercadoParaPuesto mercado;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.exitoFondo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.exitoTexto),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: AppColors.exitoTexto),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Dirección conservada del mercado:\n${mercado.direccion}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
