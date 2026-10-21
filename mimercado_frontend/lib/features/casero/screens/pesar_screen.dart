import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../core/widgets/mensaje_error.dart';
import '../../../data/models/cotizacion.dart';
import '../../../data/models/pedido.dart';
import '../../../data/models/producto.dart';
import '../../../data/models/usuario.dart';
import '../../../data/repositories/pedido_repository.dart';
import '../../../data/repositories/pedidos_vendedor_api_repository.dart';
import '../widgets/alerta_pedido.dart';
import '../widgets/encabezado_pedido_casero.dart';
import '../widgets/resumen_precio_casero.dart';

class PesarScreen extends StatefulWidget {
  const PesarScreen({
    super.key,
    required this.pedidoId,
    required this.usuario,
    this.repository,
  });
  final int pedidoId;
  final Usuario usuario;
  final PedidosVendedorApiRepository? repository;
  @override
  State<PesarScreen> createState() => _PesarScreenState();
}

class _PesarScreenState extends State<PesarScreen> {
  late final PedidosVendedorApiRepository _repo;
  final _form = GlobalKey<FormState>();
  final _nota = TextEditingController();
  final _cantidades = <int, TextEditingController>{};
  final _precios = <int, TextEditingController>{};
  final _reemplazos = <int, TextEditingController>{};
  Pedido? _pedido;
  PedidoPuesto? _parte;
  bool _cargando = true;
  bool _enviando = false;
  bool _finalizado = false;
  String? _errorCarga;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? PedidosVendedorApiRepository.instancia;
    _cargar();
  }

  @override
  void dispose() {
    _nota.dispose();
    for (final c in [
      ..._cantidades.values,
      ..._precios.values,
      ..._reemplazos.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final lista = await _repo.pedidosDePuesto(widget.usuario.puestoId ?? 0);
      if (!mounted) return;
      final pedido = lista.where((p) => p.id == widget.pedidoId).firstOrNull;
      final parte = pedido?.parteDePuesto(widget.usuario.puestoId ?? 0);
      for (final d in parte?.detalles ?? const <PedidoDetalle>[]) {
        _cantidades.putIfAbsent(
          d.id,
          () => TextEditingController(
            text: _entera(d.unidad)
                ? d.cantidadSolicitada.toStringAsFixed(0)
                : d.cantidadSolicitada.toStringAsFixed(3),
          ),
        );
        _precios.putIfAbsent(
          d.id,
          () => TextEditingController(
            text: d.precioEstimadoUnitario.toStringAsFixed(2),
          ),
        );
        if (d.disponibilidad == Disponibilidad.reemplazo) {
          _reemplazos.putIfAbsent(d.id, () => TextEditingController());
        }
      }
      setState(() {
        _pedido = pedido;
        _parte = parte;
        _cargando = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _errorCarga = e is PedidoException
              ? e.mensaje
              : 'No pudimos cargar el pedido. Inténtalo de nuevo.';
        });
      }
    }
  }

  static bool _entera(UnidadMedida unidad) =>
      unidad == UnidadMedida.unidad || unidad == UnidadMedida.atado;
  static double? _numero(String texto) =>
      double.tryParse(texto.trim().replaceAll(',', '.'));
  static String? _validarNumero(
    String? texto, {
    required bool precio,
    bool entera = false,
  }) {
    final valor = (texto ?? '').trim();
    final patron = precio
        ? r'^\d{1,10}([.,]\d{1,2})?$'
        : entera
        ? r'^\d{1,9}$'
        : r'^\d{1,9}([.,]\d{1,3})?$';
    final numero = _numero(valor);
    if (!RegExp(patron).hasMatch(valor) || numero == null || !numero.isFinite) {
      return precio
          ? 'Escribe un precio con hasta 2 decimales.'
          : entera
          ? 'Usa una cantidad entera.'
          : 'Usa hasta 3 decimales para el peso real.';
    }
    if (numero < (precio ? 0.10 : 0.001)) {
      return precio
          ? 'El precio mínimo es S/ 0.10.'
          : 'La cantidad debe ser mayor que cero.';
    }
    return null;
  }

  List<PedidoDetalle> get _aPesar =>
      _parte?.detalles
          .where((d) => d.disponibilidad != Disponibilidad.sinStock)
          .toList() ??
      [];
  bool get _valoresValidos => _aPesar.every(
    (d) =>
        _validarNumero(
              _cantidades[d.id]!.text,
              precio: false,
              entera: _entera(d.unidad),
            ) ==
            null &&
        _validarNumero(_precios[d.id]!.text, precio: true) == null &&
        (!_reemplazos.containsKey(d.id) ||
            (_reemplazos[d.id]!.text.trim().isNotEmpty &&
                _reemplazos[d.id]!.text.trim().length <= 150)),
  );
  List<CotizacionDetalle> get _cotizacion => [
    for (final d in _aPesar)
      CotizacionDetalle(
        pedidoDetalleId: d.id,
        nombreFinal: _reemplazos[d.id]?.text.trim() ?? d.nombre,
        cantidadReal: _numero(_cantidades[d.id]!.text) ?? 0,
        precioUnitario: _numero(_precios[d.id]!.text) ?? 0,
      ),
  ];

  void _volver() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/casero/inicio/pedido/${widget.pedidoId}');
    }
  }

  Future<void> _enviar() async {
    if (_enviando || _finalizado) return;
    final formularioValido = _form.currentState?.validate() ?? false;
    // ListView puede desmontar campos fuera de pantalla: valida también sus datos.
    if (!formularioValido || !_valoresValidos) {
      setState(
        () => _error =
            'Revisa las cantidades, los precios y los nombres de reemplazo antes de enviar.',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    final detalles = List<CotizacionDetalle>.unmodifiable(_cotizacion);
    final nota = _nota.text.trim();
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => Dialog(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: const Text(
                    'Confirmar precio final',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 12),
                for (final d in detalles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${d.nombreFinal}: ${d.cantidadReal.toStringAsFixed(3).replaceFirst(RegExp(r"\.?0+$"), "")} ${_parte!.detalles.firstWhere((p) => p.id == d.pedidoDetalleId).unidad.simbolo} · ${soles(d.subtotal)}',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ResumenPrecioCasero(
                  estimado: _parte!.subtotalEstimado,
                  detalles: detalles,
                ),
                if (nota.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Nota: $nota',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Revisa los datos. El cliente debe aceptar la cotización completa antes de continuar.',
                  style: TextStyle(fontSize: 17),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: _estiloEnviar,
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text(
                    'Confirmar y enviar',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text(
                    'Volver a corregir',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (confirmar != true || !mounted) return;
      await _repo.enviarPrecioFinal(_parte!.id, detalles, nota: nota);
      if (!mounted) return;
      avisar(context, 'Guardaste el precio final de tu puesto.');
      setState(() => _finalizado = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      _volver();
    } on PedidoException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  ButtonStyle get _estiloEnviar => FilledButton.styleFrom(
    backgroundColor: AppColors.azul,
    foregroundColor: AppColors.blanco,
    minimumSize: const Size(48, 56),
    padding: const EdgeInsets.all(16),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_enviando || _finalizado,
    child: Scaffold(
      body: Column(
        children: [
          EncabezadoPedidoCasero(
            titulo: 'Pesar y poner precio',
            subtitulo: _pedido?.codigo,
            habilitado: !_enviando,
          ),
          Expanded(child: _cuerpo()),
        ],
      ),
    ),
  );

  Widget _cuerpo() {
    if (_cargando) return const CargandoApp();
    if (_errorCarga != null) {
      return AvisoPantalla(
        icono: Icons.wifi_off_outlined,
        titulo: 'No pudimos cargar el pesaje',
        texto: _errorCarga,
        esError: true,
        textoBoton: 'Reintentar',
        alTocar: _cargar,
      );
    }
    final parte = _parte;
    if (_pedido == null || parte == null) {
      return const AvisoPantalla(
        icono: Icons.search_off,
        titulo: 'No encontramos este pedido',
      );
    }
    if (parte.estado != EstadoPedidoPuesto.aceptado &&
        parte.estado != EstadoPedidoPuesto.pesando) {
      return AvisoPantalla(
        icono: Icons.info_outline,
        titulo: 'Este pedido ya no permite pesar',
        textoBoton: 'Volver al pedido',
        alTocar: _volver,
      );
    }
    if (parte.detalles.any(
      (d) => d.disponibilidad == Disponibilidad.pendiente,
    )) {
      return AvisoPantalla(
        icono: Icons.fact_check_outlined,
        titulo: 'Falta revisar productos',
        texto: 'Confirma la disponibilidad de cada producto antes de pesar.',
        textoBoton: 'Volver al pedido',
        alTocar: _volver,
      );
    }
    if (_aPesar.isEmpty) {
      return AvisoPantalla(
        icono: Icons.remove_shopping_cart_outlined,
        titulo: 'No tienes productos para pesar',
        textoBoton: 'Rechazar pedido',
        alTocar: () async {
          if (await rechazarConMotivo(context, parte, repository: _repo) &&
              mounted) {
            _volver();
          }
        },
      );
    }
    final sinStock = parte.detalles.where(
      (d) => d.disponibilidad == Disponibilidad.sinStock,
    );
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Registra la cantidad real y el precio por unidad de cada producto. Puedes usar punto o coma para los decimales.',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 12),
          for (final d in _aPesar) ...[
            _producto(d),
            const SizedBox(height: 12),
          ],
          if (sinStock.isNotEmpty) ...[
            EtiquetaEstado(
              texto: 'No se cobra: ${sinStock.map((d) => d.nombre).join(', ')}',
              icono: Icons.remove_shopping_cart_outlined,
              tipo: TipoEstado.error,
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _nota,
            enabled: !_enviando,
            maxLength: 120,
            maxLines: 3,
            style: const TextStyle(fontSize: 18),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Nota para el cliente',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (_valoresValidos)
            ResumenPrecioCasero(
              estimado: parte.subtotalEstimado,
              detalles: _cotizacion,
            )
          else
            const EtiquetaEstado(
              texto:
                  'Completa cantidades, precios y reemplazos para ver el resumen.',
              icono: Icons.info_outline,
              tipo: TipoEstado.aviso,
            ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            MensajeError(_error!),
            const SizedBox(height: 12),
          ],
          if (_enviando)
            Semantics(
              liveRegion: true,
              child: const Text(
                'Confirmando o enviando el precio final…',
                style: TextStyle(fontSize: 18),
              ),
            ),
          FilledButton(
            style: _estiloEnviar,
            onPressed: _enviando ? null : _enviar,
            child: const Text(
              'Enviar precio final',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _producto(PedidoDetalle d) => TarjetaApp(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          d.nombre,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        Text(
          'Pidió ${cantidadConUnidad(d.cantidadSolicitada, d.unidad)} · ${soles(d.precioEstimadoUnitario)} / ${d.unidad.simbolo}',
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.textoSecundario,
          ),
        ),
        if (_reemplazos.containsKey(d.id)) ...[
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey('reemplazo_${d.id}'),
            controller: _reemplazos[d.id],
            enabled: !_enviando,
            maxLength: 150,
            style: const TextStyle(fontSize: 18),
            validator: (v) => (v ?? '').trim().isEmpty
                ? 'Escribe el nombre del reemplazo.'
                : null,
            decoration: const InputDecoration(
              labelText: 'Nombre del reemplazo',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Cantidad real (${d.unidad.simbolo})',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Cantidad real de ${d.nombre} en ${d.unidad.simbolo}',
          child: TextFormField(
            key: ValueKey('cantidad_${d.id}'),
            controller: _cantidades[d.id],
            enabled: !_enviando,
            keyboardType: TextInputType.numberWithOptions(
              decimal: !_entera(d.unidad),
            ),
            style: const TextStyle(fontSize: 20),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (v) =>
                _validarNumero(v, precio: false, entera: _entera(d.unidad)),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              errorMaxLines: 3,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: [
            IconButton.outlined(
              tooltip:
                  'Quitar ${cantidadConUnidad(d.unidad.paso, d.unidad)} de ${d.nombre}',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed:
                  _enviando ||
                      (_numero(_cantidades[d.id]!.text) ?? 0) <= d.unidad.paso
                  ? null
                  : () => _ajustar(d, -d.unidad.paso),
              icon: const Icon(Icons.remove),
            ),
            IconButton.filled(
              tooltip:
                  'Agregar ${cantidadConUnidad(d.unidad.paso, d.unidad)} de ${d.nombre}',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: _enviando ? null : () => _ajustar(d, d.unidad.paso),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Precio por ${d.unidad.simbolo}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Precio por ${d.unidad.simbolo} de ${d.nombre}',
          child: TextFormField(
            key: ValueKey('precio_${d.id}'),
            controller: _precios[d.id],
            enabled: !_enviando,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 20),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (v) => _validarNumero(v, precio: true),
            decoration: const InputDecoration(
              prefixText: 'S/ ',
              border: OutlineInputBorder(),
              errorMaxLines: 3,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    ),
  );

  void _ajustar(PedidoDetalle d, double paso) {
    final actual = _numero(_cantidades[d.id]!.text);
    if (actual == null) return;
    final valor = actual + paso;
    final texto = valor.toStringAsFixed(_entera(d.unidad) ? 0 : 3);
    if (_validarNumero(texto, precio: false, entera: _entera(d.unidad)) !=
        null) {
      return;
    }
    setState(() => _cantidades[d.id]!.text = texto);
  }
}
