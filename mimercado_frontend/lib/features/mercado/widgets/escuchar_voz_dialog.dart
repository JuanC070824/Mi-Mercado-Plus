import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/voz_service.dart';

import 'package:mimercado_frontend/core/i18n/idioma.dart';

/// "Te escucho…": muestra en vivo lo que entiende y devuelve el texto (null si cancela).
Future<String?> escucharBusqueda(BuildContext context, VozService voz) =>
    showDialog<String>(
      context: context,
      builder: (_) => _EscucharDialog(voz: voz),
    );

class _EscucharDialog extends StatefulWidget {
  const _EscucharDialog({required this.voz});
  final VozService voz;

  @override
  State<_EscucharDialog> createState() => _EscucharDialogState();
}

class _EscucharDialogState extends State<_EscucharDialog> {
  String _texto = '';
  bool _cerrado = false;
  bool _sinAudio = false;

  @override
  void initState() {
    super.initState();
    _escuchar();
  }

  void _escuchar() {
    if (_sinAudio) setState(() => _sinAudio = false);
    widget.voz.escuchar(
      (texto, fin) {
        if (!mounted || _cerrado) return;
        setState(() => _texto = texto);
        if (fin) _cerrar(texto);
      },
      // Silencio, error o micrófono bloqueado: se usa lo entendido o se avisa.
      alTerminar: () {
        if (!mounted || _cerrado) return;
        if (_texto.trim().isNotEmpty) return _cerrar(_texto);
        setState(() => _sinAudio = true);
      },
    );
  }

  void _cerrar(String? resultado) {
    if (_cerrado) return;
    _cerrado = true;
    widget.voz.detener();
    Navigator.of(context).pop(resultado);
  }

  @override
  void dispose() {
    if (!_cerrado) widget.voz.detener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: Icon(
      _sinAudio ? Icons.mic_off : Icons.mic,
      size: 56,
      color: AppColors.azul,
    ),
    title: Text(
      _sinAudio ? tr('No te escuchamos') : tr('Te escucho…'),
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
    ),
    content: Semantics(
      liveRegion: true,
      child: Text(
        _sinAudio
            ? tr('Revisa el permiso del micrófono o escribe tu búsqueda.')
            : _texto.isEmpty
            ? tr('Di el nombre del casero o del puesto.')
            : '“$_texto”',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: _texto.isEmpty || _sinAudio ? 18 : 24,
          fontWeight: _texto.isEmpty || _sinAudio
              ? FontWeight.w400
              : FontWeight.w700,
          color: _texto.isEmpty || _sinAudio
              ? AppColors.textoSecundario
              : AppColors.texto,
        ),
      ),
    ),
    actionsAlignment: MainAxisAlignment.center,
    actionsOverflowDirection: VerticalDirection.down,
    actions: [
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.azul,
          minimumSize: const Size(48, 56),
        ),
        onPressed: _sinAudio
            ? _escuchar
            : _texto.trim().isEmpty
            ? null
            : () => _cerrar(_texto),
        child: Text(
          _sinAudio ? tr('Intentar de nuevo') : tr('Buscar'),
          style: const TextStyle(fontSize: 18),
        ),
      ),
      TextButton(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: () => _cerrar(null),
        child: Text(tr('Cancelar'), style: TextStyle(fontSize: 18)),
      ),
    ],
  );
}
