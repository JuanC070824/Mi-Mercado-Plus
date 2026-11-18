import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class FormularioMp extends StatelessWidget {
  const FormularioMp({
    super.key,
    required this.publicKey,
    required this.monto,
    required this.alPagar,
  });
  final String publicKey;
  final double monto;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) alPagar;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    icon: const Icon(Icons.credit_card),
    label: const Text('Completar pago aquí'),
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 56),
      textStyle: const TextStyle(fontSize: 19),
    ),
    onPressed: () => showDialog<void>(
      context: context,
      useSafeArea: true,
      builder: (dialogContext) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Paga tu pedido'),
            leading: IconButton(
              tooltip: 'Volver al pedido',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Text(
                    'Total: S/ ${monto.toStringAsFixed(2)} · Pago de prueba',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: _FormularioMpFrame(
                    publicKey: publicKey,
                    monto: monto,
                    alPagar: (datos) async {
                      final result = await alPagar(datos);
                      if (result['approved'] == true && dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                      return result;
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _FormularioMpFrame extends StatefulWidget {
  const _FormularioMpFrame({
    required this.publicKey,
    required this.monto,
    required this.alPagar,
  });
  final String publicKey;
  final double monto;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) alPagar;
  @override
  State<_FormularioMpFrame> createState() => _FormularioMpFrameState();
}

class _FormularioMpFrameState extends State<_FormularioMpFrame> {
  final _session = List.generate(
    24,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  web.HTMLIFrameElement? _frame;
  late final JSFunction _listener;
  bool _enviando = false;
  @override
  void initState() {
    super.initState();
    _listener = ((web.MessageEvent event) {
      _recibir(event);
    }).toJS;
    web.window.addEventListener('message', _listener);
  }

  @override
  void dispose() {
    _enviar('dispose');
    web.window.removeEventListener('message', _listener);
    super.dispose();
  }

  void _enviar(String type, [Map<String, dynamic> extra = const {}]) {
    _frame?.contentWindow?.postMessage(
      jsonEncode({
        'channel': 'mmp-payment',
        'session': _session,
        'type': type,
        ...extra,
      }).toJS,
      web.window.location.origin.toJS,
    );
  }

  Future<void> _recibir(web.MessageEvent event) async {
    if (!mounted ||
        event.origin != web.window.location.origin ||
        event.source != _frame?.contentWindow ||
        event.data == null ||
        !event.data.isA<JSString>())
      return;
    Map<String, dynamic> data;
    try {
      final value = jsonDecode((event.data as JSString).toDart);
      if (value is! Map<String, dynamic>) return;
      data = value;
    } catch (_) {
      return;
    }
    if (data['channel'] != 'mmp-payment' || data['session'] != _session) return;
    if (data['type'] == 'loaded') {
      _enviar('init', {'publicKey': widget.publicKey, 'amount': widget.monto});
    } else if (data['type'] == 'submit' &&
        !_enviando &&
        data['payload'] is Map<String, dynamic>) {
      _enviando = true;
      try {
        final result = await widget.alPagar(
          Map<String, dynamic>.from(data['payload']),
        );
        if (mounted) _enviar('result', result);
      } finally {
        _enviando = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) => HtmlElementView.fromTagName(
    tagName: 'iframe',
    onElementCreated: (element) {
      final frame = element as web.HTMLIFrameElement;
      _frame = frame;
      frame.title = 'Formulario seguro de Mercado Pago';
      frame.style.border = '0';
      frame.style.width = '100%';
      frame.style.height = '100%';
      frame.src = Uri.parse(
        web.document.baseURI,
      ).resolve('mercadopago.html').replace(fragment: _session).toString();
    },
  );
}
