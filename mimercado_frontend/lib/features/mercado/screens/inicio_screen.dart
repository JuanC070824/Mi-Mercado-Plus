import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/botones_app.dart';
import '../../../core/widgets/mensaje_error.dart';
import '../../../data/models/puesto.dart';
import '../../../data/models/usuario.dart';
import '../../../data/repositories/catalogo_repository.dart';
import '../widgets/componentes_inicio.dart';
import '../widgets/encabezado_inicio.dart';
import '../widgets/selector_mercado_sheet.dart';

class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key, required this.usuario});
  final Usuario usuario;

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  final CatalogoRepository _repo = CatalogoRepositoryMock();
  final _busqueda = TextEditingController();
  Timer? _espera;

  SeleccionMercado? _seleccion; // null = aún no eligió mercado
  Map<int, String> _nombresMercado = {};
  CategoriaPuesto? _categoria;
  List<Puesto> _puestos = [];
  bool _cargando = true;
  String? _errorCarga;
  int _consultaId = 0;

  bool get _hayFiltros =>
      _categoria != null || _busqueda.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _cargarNombres();
    _cargarPuestos();
  }

  @override
  void dispose() {
    _espera?.cancel();
    _busqueda.dispose();
    super.dispose();
  }

  // ---------- Datos ----------

  Future<void> _cargarNombres() async {
    final l = await _repo.mercados();
    if (!mounted) return;
    setState(() {
      _nombresMercado = {for (final m in l) m.mercado.id: m.mercado.nombre};
    });
  }

  Future<void> _cargarPuestos() async {
    final id = ++_consultaId;
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final sel = _seleccion;
      final texto = _busqueda.text.trim();
      final List<Puesto> r;
      if (sel == null) {
        r = await _repo.masQueridos();
      } else if (_categoria == null && texto.isEmpty) {
        r = await _repo.masQueridos(mercadoId: sel.mercado.id);
      } else {
        r = await _repo.buscar(
          mercadoId: sel.mercado.id,
          categoria: _categoria,
          texto: texto,
        );
      }
      if (!mounted || id != _consultaId) return;
      setState(() {
        _puestos = r;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted || id != _consultaId) return;
      setState(() {
        _cargando = false;
        _errorCarga =
            'No pudimos cargar los caseros. Revisa tu conexión e inténtalo de nuevo.';
      });
    }
  }

  // ---------- Acciones ----------

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto, style: const TextStyle(fontSize: 18))),
    );
  }

  /// Abre el selector. Devuelve true si el cliente eligió un mercado.
  Future<bool> _elegirMercado({String? mensaje}) async {
    final r = await mostrarSelectorMercado(
      context,
      repo: _repo,
      actual: _seleccion?.mercado,
      latitud: _seleccion?.latitud,
      longitud: _seleccion?.longitud,
      mensaje: mensaje,
    );
    if (r == null || !mounted) return false;
    // TODO: si el carrito tiene productos de otro mercado, pedir confirmación
    // ("Si cambias de mercado, se vaciará tu carrito") antes de cambiar.
    setState(() => _seleccion = r);
    return true;
  }

  Future<void> _tocarBarraMercado() async {
    if (await _elegirMercado()) _cargarPuestos();
  }

  Future<void> _tocarCategoria(CategoriaPuesto c) async {
    if (_seleccion == null) {
      final ok = await _elegirMercado(
        mensaje: 'Elige tu mercado para ver ${c.nombre.toLowerCase()}.',
      );
      if (!ok) return;
      setState(() => _categoria = c);
    } else {
      setState(() => _categoria = _categoria == c ? null : c);
    }
    _cargarPuestos();
  }

  Future<void> _pedirMercadoParaBuscar() async {
    final ok = await _elegirMercado(
      mensaje:
          'Primero elige tu mercado: la búsqueda funciona dentro del mercado que selecciones.',
    );
    if (ok) _cargarPuestos();
  }

  void _alEscribir(String _) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 300), _cargarPuestos);
  }

  void _limpiarBusqueda() {
    _busqueda.clear();
    _cargarPuestos();
  }

  void _quitarFiltros() {
    _busqueda.clear();
    setState(() => _categoria = null);
    _cargarPuestos();
  }

  // ---------- Interfaz ----------

  @override
  Widget build(BuildContext context) {
    final primerNombre = widget.usuario.nombres.split(' ').first;
    final sel = _seleccion;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            EncabezadoInicio(
              nombre: primerNombre,
              controlador: _busqueda,
              busquedaBloqueada: sel == null,
              onTapBusquedaBloqueada: _pedirMercadoParaBuscar,
              onCambio: _alEscribir,
              onLimpiar: _limpiarBusqueda,
              onVoz: () => sel == null
                  ? _pedirMercadoParaBuscar()
                  : _aviso('La búsqueda por voz estará disponible pronto.'),
              onSoporte: () => _aviso('Soporte estará disponible pronto.'),
              
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 28),
                      Semantics(
                        header: true,
                        child: const Text(
                          '¿Qué necesitas hoy?',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.texto,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _gridCategorias(),
                      const SizedBox(height: 20),
                      BarraMercado(
                        mercado: sel?.mercado,
                        distanciaTexto: sel?.item.distanciaTexto,
                        onTap: _tocarBarraMercado,
                      ),
                      const SizedBox(height: 28),
                      _seccionCaseros(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gridCategorias() {
    const todas = CategoriaPuesto.values;
    return Column(
      children: [
        for (var i = 0; i < todas.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final c in todas.skip(i).take(2)) ...[
                  if (c != todas[i]) const SizedBox(width: 12),
                  Expanded(
                    child: TarjetaCategoria(
                      categoria: c,
                      seleccionada: _categoria == c,
                      onTap: () => _tocarCategoria(c),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _titulo() {
    final texto = _busqueda.text.trim();
    if (texto.isNotEmpty) return 'Resultados para “$texto”';
    if (_categoria != null) return _categoria!.nombre;
    return 'Tus caseros más queridos';
  }

  String _subtitulo() {
    final sel = _seleccion;
    if (_cargando) return 'Buscando…';
    if (sel == null) {
      return 'De todos los mercados. Elige uno para filtrar por rubro y buscar.';
    }
    if (!_hayFiltros) return 'En ${sel.mercado.nombre}';
    final n = _puestos.length;
    return '$n ${n == 1 ? 'casero encontrado' : 'caseros encontrados'} en ${sel.mercado.nombre}';
  }

  Widget _seccionCaseros() {
    final sel = _seleccion;

    final Widget contenido;
    if (_cargando) {
      contenido = const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(semanticsLabel: 'Cargando caseros'),
        ),
      );
    } else if (_errorCarga != null) {
      contenido = Column(
        children: [
          MensajeError(_errorCarga!),
          const SizedBox(height: 12),
          BotonSecundario(texto: 'Reintentar', onPressed: _cargarPuestos),
        ],
      );
    } else if (_puestos.isEmpty) {
      contenido = Column(
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              'No encontramos caseros${sel == null ? '' : ' en ${sel.mercado.nombre}'} '
              'con esos datos. Prueba con otro rubro o con otra palabra.',
              style: const TextStyle(fontSize: 18, color: AppColors.texto),
            ),
          ),
          const SizedBox(height: 12),
          BotonSecundario(texto: 'Quitar filtros', onPressed: _quitarFiltros),
        ],
      );
    } else {
      contenido = Column(
        children: [
          for (var i = 0; i < _puestos.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            TarjetaCasero(
              puesto: _puestos[i],
              nombreMercado:
                  sel == null ? _nombresMercado[_puestos[i].mercadoId] : null,
              onTap: () => _aviso(
                  'El catálogo de ${_puestos[i].nombre} estará disponible pronto.'),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  _titulo(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.texto,
                  ),
                ),
              ),
            ),
            if (_hayFiltros)
              TextButton(
                onPressed: _quitarFiltros,
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: const Text(
                  'Quitar filtros',
                  style: TextStyle(fontSize: 17, color: AppColors.azul),
                ),
              ),
          ],
        ),
        Semantics(
          liveRegion: true, // el lector de pantalla anuncia el nuevo conteo
          child: Text(
            _subtitulo(),
            style: const TextStyle(fontSize: 17, color: AppColors.textoSecundario),
          ),
        ),
        const SizedBox(height: 12),
        contenido,
      ],
    );
  }
}