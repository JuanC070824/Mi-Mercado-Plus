import 'dart:async';
import 'package:flutter/foundation.dart';
import 'pago_mp_integrado.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../data/models/pedido.dart';
import '../../../data/repositories/mercadopago_api_repository.dart';
import '../../../data/repositories/pedido_repository.dart';

import 'package:mimercado_frontend/core/i18n/idioma.dart';

class PagoMercadoPagoPruebas extends StatefulWidget {
  const PagoMercadoPagoPruebas({
    super.key,
    required this.pedido,
    this.repository,
    this.abrirCheckout,
    this.alConfirmarPago,
  });

  static const habilitado = bool.fromEnvironment(
    'MERCADOPAGO_PRUEBAS',
    defaultValue: true,
  );
  final Pedido pedido;
  final MercadoPagoApiRepository? repository;
  final Future<bool> Function(Uri)? abrirCheckout;
  final VoidCallback? alConfirmarPago;

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
  bool _confirmacionNotificada = false;

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
    if (kIsWeb && widget.abrirCheckout == null) return;
    WidgetsBinding.instance.addObserver(this);
    // Solo consulta con un checkout abierto y sin resultado final.
    _refresco = Timer.periodic(const Duration(seconds: 5), (_) {
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
          () => _error = tr(
            'No pudimos completar la consulta. Inténtalo de nuevo.',
          ),
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
      _notificarConfirmacion(estado);
      if (mounted && !_terminal) await _prepararDatos();
    }
  });

  Future<void> _consultar() => _hacer(() async {
    final estado = await _repo.confirmar(widget.pedido.id);
    if (mounted) setState(() => _estado = estado);
    _notificarConfirmacion(estado);
  });

  void _notificarConfirmacion(Map<String, dynamic> estado) {
    if (mounted &&
        estado['pago_interno_aprobado'] == true &&
        !_confirmacionNotificada) {
      _confirmacionNotificada = true;
      widget.alConfirmarPago?.call();
    }
  }

  Future<void> _preparar() => _hacer(_prepararDatos);

  Future<void> _prepararDatos() async {
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
    _notificarConfirmacion(datos);
  }

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
        throw PedidoException(
          tr(
            'El navegador no pudo abrir el checkout. Copia el enlace y ábrelo en una ventana de incógnito.',
          ),
        );
      }
    });
  }

  String get _mensaje {
    if (_aprobado && _estado?['pago_interno_aprobado'] == true) {
      return tr(
        'Pago confirmado. Continuamos con la preparación y el reparto de tu pedido.',
      );
    }
    if (_aprobado) {
      return tr(
        'Pago aprobado en Mercado Pago. Consulta de nuevo para completar su registro interno; no vuelvas a pagar.',
      );
    }
    return switch (_estado?['estado']) {
      'created' => tr(
        'El importe final está listo. Completa el pago para continuar con el reparto.',
      ),
      'processing' || 'action_required' => tr(
        'El pago requiere confirmación o una acción en Mercado Pago. Consulta su estado antes de volver a intentarlo.',
      ),
      'failed' => tr(
        'El pago fue rechazado. Revisa el resultado en Mercado Pago.',
      ),
      'canceled' || 'expired' => tr(
        'El pago se canceló o venció. Revisa el resultado en Mercado Pago.',
      ),
      'refunded' || 'charged_back' => tr(
        'El pago tiene una devolución o contracargo y no se considera aprobado.',
      ),
      'processed' => tr(
        'El importe todavía no está completamente acreditado. Revisa el resultado en Mercado Pago.',
      ),
      'sin_iniciar' => tr('Completa el pago del precio final para continuar.'),
      _ => tr(
        'Consulta el estado para comprobar el resultado en Mercado Pago.',
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb && widget.abrirCheckout == null) {
      return PagoMpIntegrado(
        pedido: widget.pedido,
        repository: _repo,
        alConfirmarPago: widget.alConfirmarPago,
      );
    }
    final estilo = FilledButton.styleFrom(
      minimumSize: const Size(48, 56),
      padding: const EdgeInsets.all(16),
    );
    return TarjetaApp(
      colorBorde: AppColors.azul,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('Paga con Mercado Pago'),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          Text(
            soles(widget.pedido.cotizacion?.totalCliente ?? 0),
            style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
          ),
          Text(
            tr('Demostración académica · sin dinero real'),
            style: TextStyle(fontSize: 17),
          ),
          const SizedBox(height: 12),
          if (_ocupado)
            LinearProgressIndicator(
              semanticsLabel: tr('Consultando Mercado Pago'),
            ),
          if (_config != null && !_listo)
            Text(
              tr(
                'El pago en línea no está disponible en este momento. Inténtalo de nuevo.',
              ),
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
                    ? tr('Continuar al pago')
                    : tr('Pagar {0}', [
                        soles(widget.pedido.cotizacion?.totalCliente ?? 0),
                      ]),
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
                        avisar(context, tr('Enlace de pago copiado.'));
                      }
                    },
              child: Text(tr('Copiar enlace de pago')),
            ),
          if (_listo)
            TextButton(
              onPressed: _ocupado ? null : _consultar,
              child: Text(tr('Ya pagué, verificar')),
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
              child: Text(tr('Reintentar')),
            ),
        ],
      ),
    );
  }
}
