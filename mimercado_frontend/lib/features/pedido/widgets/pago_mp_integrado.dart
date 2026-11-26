import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../data/models/pedido.dart';
import '../../../data/repositories/mercadopago_api_repository.dart';
import '../../../data/repositories/pedido_repository.dart';
import 'formulario_mp.dart';

import 'package:mimercado_frontend/core/i18n/idioma.dart';

class PagoMpIntegrado extends StatefulWidget {
  const PagoMpIntegrado({
    super.key,
    required this.pedido,
    required this.repository,
    this.alConfirmarPago,
  });
  final Pedido pedido;
  final MercadoPagoApiRepository repository;
  final VoidCallback? alConfirmarPago;
  @override
  State<PagoMpIntegrado> createState() => _PagoMpIntegradoState();
}

class _PagoMpIntegradoState extends State<PagoMpIntegrado> {
  Map<String, dynamic>? _config, _estado;
  bool _cargando = true,
      _enviando = false,
      _verificando = false,
      _avisado = false;
  String? _error;
  Timer? _timer;
  int _versionFormulario = 0;
  bool get _pagado => _estado?['pago_interno_aprobado'] == true;
  bool get _devuelto =>
      const {'refunded', 'charged_back'}.contains(_estado?['estado']) ||
      _estado?['detalle'] == 'partially_refunded';
  bool get _pendiente =>
      const {
        'created',
        'processing',
        'action_required',
        'processed',
      }.contains(_estado?['estado']) &&
      !_pagado &&
      !_devuelto;
  bool get _configurado =>
      _config?['configurado'] == true &&
      _config?['entorno'] == 'prueba' &&
      _config?['integrado_configurado'] == true;
  @override
  void initState() {
    super.initState();
    _cargar();
    // Con un pago en curso se consulta cada 5 s: la aprobación aparece casi al
    // instante en vez de esperar hasta 15 s.
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted &&
          _pendiente &&
          !_enviando &&
          !_verificando &&
          TickerMode.valuesOf(context).enabled)
        _verificar();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _actualizar(Map<String, dynamic> datos) {
    if (!mounted) return;
    setState(() => _estado = datos);
    if (_pagado && !_avisado) {
      _avisado = true;
      widget.alConfirmarPago?.call();
    }
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final config = await widget.repository.configuracion();
      if (!mounted) return;
      setState(() => _config = config);
      if (_configurado)
        _actualizar(await widget.repository.confirmar(widget.pedido.id));
    } catch (error) {
      if (mounted) setState(() => _error = _mensajeError(error));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _mensajeError(Object error) => error is PedidoException
      ? error.mensaje
      : tr(
          'No pudimos consultar Mercado Pago. Verifica el estado antes de volver a pagar.',
        );
  Future<void> _verificar() async {
    if (_verificando || _enviando) return;
    setState(() => _verificando = true);
    try {
      _actualizar(await widget.repository.confirmar(widget.pedido.id));
      if (mounted) setState(() => _error = null);
    } catch (error) {
      if (mounted) setState(() => _error = _mensajeError(error));
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  Future<Map<String, dynamic>> _pagar(Map<String, dynamic> datos) async {
    if (_enviando ||
        _verificando ||
        _pendiente ||
        _pagado ||
        _devuelto ||
        _estado == null) {
      return {
        'approved': false,
        'retry': false,
        'message': tr('Ya hay un pago en proceso. Verifica su estado.'),
      };
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      _actualizar(
        await widget.repository.pagarIntegrado(widget.pedido.id, datos),
      );
      return {
        'approved': _pagado,
        'retry': !_pendiente && !_pagado,
        'message': _pagado ? tr('Pago confirmado.') : _textoEstado,
      };
    } catch (error) {
      // Un timeout no equivale a un rechazo: consultar y bloquear otro cobro.
      try {
        _actualizar(await widget.repository.confirmar(widget.pedido.id));
      } catch (_) {
        if (mounted) setState(() => _estado = {'estado': 'processing'});
      }
      final mensaje = _pagado ? 'Pago confirmado.' : _mensajeError(error);
      if (mounted) setState(() => _error = _pagado ? null : mensaje);
      return {
        'approved': _pagado,
        'retry': !_pendiente && !_pagado,
        'message': mensaje,
      };
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _cancelarIntento() async {
    if (_enviando || _verificando) return;
    setState(() {
      _verificando = true;
      _error = null;
    });
    try {
      _actualizar(await widget.repository.cancelarIntento(widget.pedido.id));
      if (mounted && !_pendiente && !_pagado)
        setState(() => _versionFormulario++);
    } catch (error) {
      if (mounted) setState(() => _error = _mensajeError(error));
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  String get _textoEstado {
    if (_devuelto)
      return tr(
        'El pago tiene una devolución o contracargo. Requiere revisión.',
      );
    if (_pagado)
      return tr(
        'Pago confirmado. Tu pedido continúa con la preparación y el reparto.',
      );
    if (_pendiente)
      return tr(
        'Estamos verificando un pago iniciado. No vuelvas a pagar; consulta su estado.',
      );
    return switch (_estado?['estado']) {
      'failed' => tr(
        'El pago fue rechazado. Puedes revisar los datos y volver a intentarlo.',
      ),
      'canceled' || 'expired' => tr('El intento anterior se canceló o venció.'),
      'refunded' || 'charged_back' => tr(
        'El pago fue devuelto o tiene un contracargo. Requiere revisión.',
      ),
      _ => tr('Completa el formulario aquí para pagar tu pedido.'),
    };
  }

  @override
  Widget build(BuildContext context) => TarjetaApp(
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
        Text(tr('Demostración académica · sin dinero real')),
        const SizedBox(height: 12),
        if (_cargando || _enviando || _verificando)
          const LinearProgressIndicator(),
        if (!_cargando && !_configurado) ...[
          Text(
            tr(
              'El pago en línea no está disponible por ahora. Inténtalo más tarde.',
            ),
          ),
          TextButton(onPressed: _cargar, child: Text(tr('Volver a intentar'))),
        ],
        if (_configurado && !_cargando) ...[
          Semantics(
            liveRegion: true,
            child: Text(_textoEstado, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 12),
          if (_estado != null &&
              !_devuelto &&
              !_pagado &&
              !_pendiente &&
              !const {'refunded', 'charged_back'}.contains(_estado?['estado']))
            FormularioMp(
              key: ValueKey(_versionFormulario),
              publicKey: _config!['public_key'] as String,
              monto: widget.pedido.cotizacion?.totalCliente ?? 0,
              alPagar: _pagar,
            ),
          if (!_pagado)
            TextButton(
              onPressed: _enviando || _verificando
                  ? null
                  : () async {
                      await _verificar();
                      if (mounted && !_pendiente && !_pagado)
                        setState(() => _versionFormulario++);
                    },
              child: Text(tr('Verificar estado del pago')),
            ),
          if (!_pagado &&
              const {
                'created',
                'action_required',
              }.contains(_estado?['estado'])) ...[
            Text(
              tr(
                'Puedes cancelar este intento pendiente para usar un nuevo formulario. Tu pedido se conserva.',
              ),
            ),
            TextButton(
              onPressed: _enviando || _verificando ? null : _cancelarIntento,
              child: Text(tr('Cancelar este intento de pago')),
            ),
          ],
        ],
        if (_error != null)
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 17),
            ),
          ),
      ],
    ),
  );
}
