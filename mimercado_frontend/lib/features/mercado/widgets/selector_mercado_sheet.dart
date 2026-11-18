import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ubicacion_service.dart';
import '../../../data/models/mercado.dart';
import '../../../data/repositories/catalogo_repository.dart';

class SeleccionMercado {
  const SeleccionMercado(this.item, {this.latitud, this.longitud});

  final MercadoCercano item;
  final double? latitud;
  final double? longitud;

  Mercado get mercado => item.mercado;
}

Future<SeleccionMercado?> mostrarSelectorMercado(
  BuildContext context, {
  required CatalogoRepository repo,
  Mercado? actual,
  double? latitud,
  double? longitud,
  String? mensaje,
}) {
  return showModalBottomSheet<SeleccionMercado>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.fondo,
    constraints: const BoxConstraints(maxWidth: 520),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (_) => _SelectorMercado(
      repo: repo,
      actual: actual,
      latitud: latitud,
      longitud: longitud,
      mensaje: mensaje,
    ),
  );
}

class _SelectorMercado extends StatefulWidget {
  const _SelectorMercado({
    required this.repo,
    this.actual,
    this.latitud,
    this.longitud,
    this.mensaje,
  });

  final CatalogoRepository repo;
  final Mercado? actual;
  final double? latitud;
  final double? longitud;
  final String? mensaje;

  @override
  State<_SelectorMercado> createState() => _SelectorMercadoState();
}

class _SelectorMercadoState extends State<_SelectorMercado> {
  List<MercadoCercano>? _lista;
  double? _lat;
  double? _lon;
  bool _buscandoGps = false;
  String? _aviso;
  bool _avisoEsError = false;

  @override
  void initState() {
    super.initState();
    _lat = widget.latitud;
    _lon = widget.longitud;
    _cargar();
  }

  Future<void> _cargar() async {
    final l = await widget.repo.mercados(latitud: _lat, longitud: _lon);
    if (!mounted) return;
    setState(() => _lista = l);
  }

  Future<void> _usarUbicacion() async {
    setState(() {
      _buscandoGps = true;
      _aviso = null;
    });
    try {
      final u = await UbicacionService.obtener(buscarDireccion: false);
      _lat = u.latitud;
      _lon = u.longitud;
      final l = await widget.repo.mercados(latitud: _lat, longitud: _lon);
      if (!mounted) return;
      setState(() {
        _lista = l;
        _buscandoGps = false;
        _avisoEsError = false;
        _aviso = 'Ordenamos los mercados del más cercano al más lejano.';
      });
    } on UbicacionException catch (e) {
      if (!mounted) return;
      setState(() {
        _buscandoGps = false;
        _avisoEsError = true;
        _aviso = '${e.mensaje} Puedes elegir tu mercado de la lista.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final altoMax = MediaQuery.sizeOf(context).height * 0.85;
    final lista = _lista;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: altoMax),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: const Text(
                  'Elige tu mercado',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.azul,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.mensaje ??
                    'Tu pedido se arma con caseros de un solo mercado.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  color: AppColors.textoSecundario,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _buscandoGps ? null : _usarUbicacion,
                  icon: _buscandoGps
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: AppColors.azul,
                            semanticsLabel: 'Buscando ubicación',
                          ),
                        )
                      : const Icon(Icons.my_location),
                  label: Text(
                    _buscandoGps
                        ? 'Buscando tu ubicación…'
                        : (_lat == null
                              ? 'Usar mi ubicación'
                              : 'Actualizar mi ubicación'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.azul,
                    disabledForegroundColor: AppColors.azul,
                    side: const BorderSide(color: AppColors.azul, width: 2),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              if (_aviso != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _Aviso(texto: _aviso!, esError: _avisoEsError),
                ),
              const SizedBox(height: 16),
              if (lista == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Cargando mercados',
                    ),
                  ),
                )
              else
                for (var i = 0; i < lista.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _FilaMercado(
                    item: lista[i],
                    esMasCercano: i == 0 && lista[i].distanciaKm != null,
                    seleccionado: lista[i].mercado.id == widget.actual?.id,
                    onTap: () => Navigator.of(context).pop(
                      SeleccionMercado(lista[i], latitud: _lat, longitud: _lon),
                    ),
                  ),
                ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(fontSize: 18, color: AppColors.azul),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaMercado extends StatelessWidget {
  const _FilaMercado({
    required this.item,
    required this.esMasCercano,
    required this.seleccionado,
    required this.onTap,
  });

  final MercadoCercano item;
  final bool esMasCercano;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = item.mercado;
    final detalle = [
      m.distrito,
      item.distanciaTexto,
    ].whereType<String>().join(' · ');

    return Semantics(
      button: true,
      selected: seleccionado,
      onTap: onTap,
      excludeSemantics: true,
      label:
          '${m.nombre}. $detalle'
          '${esMasCercano ? '. El más cercano' : ''}'
          '${seleccionado ? '. Seleccionado' : ''}',
      child: Material(
        color: seleccionado ? AppColors.azulClaro : AppColors.blanco,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: seleccionado ? AppColors.azul : AppColors.borde,
            width: seleccionado ? 3 : 1.5,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.storefront_outlined,
                    color: AppColors.azul,
                    size: 32,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          m.nombre,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.texto,
                          ),
                        ),
                        if (detalle.isNotEmpty)
                          Text(
                            detalle,
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.textoSecundario,
                            ),
                          ),
                        if (esMasCercano)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.azul,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Text(
                                'Más cercano',
                                style: TextStyle(
                                  color: AppColors.blanco,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (seleccionado)
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.azul,
                      size: 28,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto, required this.esError});
  final String texto;
  final bool esError;

  @override
  Widget build(BuildContext context) {
    final color = esError ? AppColors.error : AppColors.exito;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            esError ? Icons.error_outline : Icons.check_circle,
            color: color,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
