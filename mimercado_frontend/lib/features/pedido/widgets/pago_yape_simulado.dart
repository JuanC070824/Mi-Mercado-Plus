import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';
import '../../../data/models/pedido.dart';
import '../../../data/models/usuario.dart';
import '../../../data/repositories/pedidos_api_repository.dart';
import '../../../data/repositories/pedido_repository.dart';

class PagoYapeSimulado extends StatefulWidget {
  const PagoYapeSimulado({
    super.key,
    required this.pedido,
    required this.usuario,
    this.repository,
  });
  final Pedido pedido;
  final Usuario usuario;
  final PedidosApiRepository? repository;
  @override
  State<PagoYapeSimulado> createState() => _PagoYapeSimuladoState();
}

class _PagoYapeSimuladoState extends State<PagoYapeSimulado> {
  final _form = GlobalKey<FormState>();
  late final _celular = TextEditingController(text: widget.usuario.celular);
  final _codigo = TextEditingController();
  bool _cargando = true, _pagando = false;
  String? _error;
  Map<String, dynamic>? _config;
  PedidosApiRepository get _repo =>
      widget.repository ?? PedidosApiRepository.instancia;
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final c = await _repo.configuracionPago();
      if (mounted) setState(() => _config = c);
    } on PedidoException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _celular.dispose();
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _pagar() async {
    if (_pagando || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _pagando = true;
      _error = null;
    });
    try {
      await _repo.pagarYape(
        widget.pedido.id,
        _celular.text.trim(),
        _codigo.text.trim(),
      );
      if (mounted) {
        avisar(
          context,
          'Pago de prueba confirmado. Tu pedido continuará con el reparto.',
        );
      }
    } on PedidoException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) {
        _codigo.clear();
        setState(() => _pagando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final datos = _repo.datosDe(widget.pedido.id);
    if (datos['pago_aprobado'] == true) {
      return const EtiquetaEstado(
        texto: 'Pago de demostración confirmado. No se movió dinero.',
        icono: Icons.check_circle,
        tipo: TipoEstado.exito,
      );
    }
    if (datos['pago_pendiente'] == true) {
      return const EtiquetaEstado(
        texto:
            'Estamos confirmando tu pago. Actualiza el pedido; no vuelvas a pagar.',
        icono: Icons.hourglass_top,
        tipo: TipoEstado.aviso,
      );
    }
    final listo = _config?['modo'] == 'mock' && _config?['configurado'] == true;
    return TarjetaApp(
      colorBorde: AppColors.azul,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Simular pago con Yape',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            Text(
              soles(widget.pedido.cotizacion?.totalCliente ?? 0),
              style: const TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                color: AppColors.azul,
              ),
            ),
            const Text(
              'Demostración: no abras Yape ni transfieras dinero. No se comprueba una cuenta real.',
              style: TextStyle(fontSize: 17),
            ),
            if (_cargando)
              const LinearProgressIndicator(
                semanticsLabel: 'Preparando el pago',
              ),
            if (!_cargando && !listo)
              const Text(
                'El pago de prueba todavía no está configurado. Consulta con el responsable del proyecto.',
                style: TextStyle(fontSize: 17),
              ),
            if (listo) ...[
              Text(
                '1. Usa un celular ficticio de 9 números que empiece con 9.\n'
                '2. Escribe el código de demostración ${_config?["codigo_demostracion"] ?? "123456"}.\n'
                '3. Confirma para continuar con el reparto.',
                style: const TextStyle(fontSize: 17),
              ),
              const SizedBox(height: 16),
              const Text('Celular de prueba', style: TextStyle(fontSize: 18)),
              TextFormField(
                key: const ValueKey('pago_celular'),
                controller: _celular,
                enabled: !_pagando,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 20),
                maxLength: 9,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) => RegExp(r'^9\d{8}$').hasMatch(v ?? '')
                    ? null
                    : 'Escribe un celular de 9 números que empiece con 9.',
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Celular',
                  errorMaxLines: 4,
                ),
              ),
              const Text(
                'Código de demostración',
                style: TextStyle(fontSize: 18),
              ),
              TextFormField(
                key: const ValueKey('pago_codigo'),
                controller: _codigo,
                enabled: !_pagando,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 20),
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? '')
                    ? null
                    : 'El código tiene 6 números.',
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Código',
                  errorMaxLines: 3,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 56),
                  padding: const EdgeInsets.all(16),
                ),
                onPressed: _pagando ? null : _pagar,
                child: Text(
                  _pagando ? 'Confirmando pago…' : 'Confirmar pago de prueba',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ],
            if (_error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: const TextStyle(fontSize: 18, color: AppColors.error),
                ),
              ),
            if (_config == null && !_cargando)
              TextButton(onPressed: _cargar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
