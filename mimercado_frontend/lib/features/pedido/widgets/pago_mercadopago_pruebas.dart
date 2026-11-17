import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../data/models/pedido.dart';
import '../../../data/repositories/mercadopago_api_repository.dart';
import '../../../data/repositories/pedido_repository.dart';

class PagoMercadoPagoPruebas extends StatefulWidget {
  const PagoMercadoPagoPruebas({
    super.key,
    required this.pedido,
    this.repository,
    this.abrirCheckout,
  });

  static const habilitado = bool.fromEnvironment('MERCADOPAGO_PRUEBAS');
  final Pedido pedido;
  final MercadoPagoApiRepository? repository;
  final Future<bool> Function(Uri)? abrirCheckout;

  @override
  State<PagoMercadoPagoPruebas> createState() => _PagoMercadoPagoPruebasState();
}

class _PagoMercadoPagoPruebasState extends State<PagoMercadoPagoPruebas>
    with WidgetsBindingObserver {
  late final _repo = widget.repository ?? MercadoPagoApiRepository();
  Map<String, dynamic>? _config, _estado;
  Uri? _checkout;
  bool _ocupado = false;
  String? _error;
  Timer? _refresco;

  bool get _listo =>
      _config?['configurado'] == true && _config?['entorno'] == 'prueba';
  bool get _aprobado => _estado?['aprobado_en_proveedor'] == true;
  bool get _terminal =>
      _aprobado ||
      const {
        'processed',
        'failed',
        'canceled',
        'expired',
        'refunded',
        'charged_back',
      }.contains(_estado?['estado']) ||
      _estado?['detalle'] == 'partially_refunded';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresco = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted &&
          _checkout != null &&
          !_terminal &&
          _listo &&
          !_ocupado &&
          TickerMode.valuesOf(context).enabled &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _consultar();
      }
    });
    _cargar();
  }

  @override
  void dispose() {
    _refresco?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        TickerMode.valuesOf(context).enabled &&
        _listo &&
        !_ocupado) {
      _consultar();
    }
  }

  Future<void> _hacer(Future<void> Function() accion) async {
    if (_ocupado) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await accion();
    } on PedidoException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'No pudimos completar la consulta. Inténtalo de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _cargar() => _hacer(() async {
    final config = await _repo.configuracion();
    if (!mounted) return;
    setState(() => _config = config);
    if (_listo) {
      final estado = await _repo.confirmar(widget.pedido.id);
      if (mounted) setState(() => _estado = estado);
    }
  });

  Future<void> _consultar() => _hacer(() async {
    final estado = await _repo.confirmar(widget.pedido.id);
    if (mounted) setState(() => _estado = estado);
  });

  Future<void> _preparar() => _hacer(() async {
    final datos = await _repo.crearCheckout(widget.pedido.id);
    final link = datos['checkout_url'];
    final uri = link == null
        ? null
        : MercadoPagoApiRepository.validarCheckout(link);
    if (mounted) {
      setState(() {
        _estado = datos;
        _checkout = uri;
      });
    }
  });

  // Un segundo clic explícito abre el enlace ya creado. Evita que el navegador
  // bloquee una ventana nueva por esperar primero una respuesta HTTP.
  Future<void> _abrir() async {
    final uri = _checkout;
    if (uri == null || _ocupado) return;
    await _hacer(() async {
      final abierto =
          await (widget.abrirCheckout?.call(uri) ??
              launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
                webOnlyWindowName: '_blank',
              ));
      if (!abierto) {
        throw const PedidoException(
          'El navegador no pudo abrir el checkout. Copia el enlace y ábrelo en una ventana de incógnito.',
        );
      }
    });
  }

  String get _mensaje {
    if (_aprobado && _estado?['pago_interno_aprobado'] == true) {
      return 'Pago de prueba confirmado y registrado. El pedido puede continuar con el repartidor cuando las bolsas estén preparadas.';
    }
    if (_aprobado) {
      return 'Pago aprobado en Mercado Pago. Consulta de nuevo para completar su registro interno; no vuelvas a pagar.';
    }
    return switch (_estado?['estado']) {
      'created' =>
        'Checkout preparado. Completa el pago de prueba y vuelve a esta pestaña para consultar el resultado.',
      'processing' || 'action_required' =>
        'El pago requiere confirmación o una acción en Mercado Pago. Consulta su estado antes de volver a intentarlo.',
      'failed' =>
        'Mercado Pago rechazó la prueba. Puedes revisar el detalle en su panel.',
      'canceled' || 'expired' =>
        'La prueba se canceló o venció. Revisa el panel de Mercado Pago.',
      'refunded' || 'charged_back' =>
        'La prueba tiene una devolución o contracargo. No se considera aprobada.',
      'processed' =>
        'La order se procesó, pero no está íntegramente acreditada. Revisa el panel de Mercado Pago.',
      'sin_iniciar' =>
        'Todavía no has iniciado una prueba para este precio final.',
      _ => 'Consulta el estado para comprobar el resultado en Mercado Pago.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final estilo = FilledButton.styleFrom(
      minimumSize: const Size(48, 56),
      padding: const EdgeInsets.all(16),
    );
    return TarjetaApp(
      colorBorde: AppColors.azul,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Mercado Pago de prueba',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          Text(
            soles(widget.pedido.cotizacion?.totalCliente ?? 0),
            style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
          ),
          const Text(
            'Usa únicamente la cuenta compradora, las tarjetas y los datos de prueba de Mercado Pago. Al verificar la aprobación se registra el pago y continúa el reparto.',
            style: TextStyle(fontSize: 17),
          ),
          const SizedBox(height: 12),
          if (_ocupado)
            const LinearProgressIndicator(
              semanticsLabel: 'Consultando Mercado Pago',
            ),
          if (_config != null && !_listo)
            const Text(
              'La prueba está desactivada o falta configurar sus credenciales en el servidor.',
              style: TextStyle(fontSize: 17),
            ),
          if (_estado != null)
            Semantics(
              liveRegion: true,
              child: Text(_mensaje, style: const TextStyle(fontSize: 18)),
            ),
          if (_listo && _estado != null && !_terminal) ...[
            const SizedBox(height: 12),
            FilledButton(
              style: estilo,
              onPressed: _ocupado
                  ? null
                  : (_checkout == null ? _preparar : _abrir),
              child: Text(
                _checkout == null
                    ? 'Preparar pago de prueba'
                    : 'Abrir Mercado Pago',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ],
          if (_checkout != null && !_terminal)
            TextButton(
              onPressed: _ocupado
                  ? null
                  : () async {
                      await Clipboard.setData(
                        ClipboardData(text: _checkout.toString()),
                      );
                      if (context.mounted) {
                        avisar(
                          context,
                          'Enlace copiado. Ábrelo en una ventana de incógnito.',
                        );
                      }
                    },
              child: const Text('Copiar enlace de prueba'),
            ),
          if (_listo)
            TextButton(
              onPressed: _ocupado ? null : _consultar,
              child: const Text('Consultar estado del pago'),
            ),
          if (_error != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: const TextStyle(fontSize: 18, color: AppColors.error),
              ),
            ),
          if (_config == null || !_listo)
            TextButton(
              onPressed: _ocupado ? null : _cargar,
              child: const Text('Reintentar configuración'),
            ),
        ],
      ),
    );
  }
}
