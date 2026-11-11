import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/voz_service.dart';

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

  @override
  void initState() {
    super.initState();
    widget.voz.escuchar((texto, fin) {
      if (!mounted || _cerrado) return;
      setState(() => _texto = texto);
      if (fin) _cerrar(texto);
    });
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
    icon: const Icon(Icons.mic, size: 56, color: AppColors.azul),
    title: const Text(
      'Te escucho…',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
    ),
    content: Semantics(
      liveRegion: true,
      child: Text(
        _texto.isEmpty ? 'Di el nombre del casero o del puesto.' : '“$_texto”',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: _texto.isEmpty ? 18 : 24,
          fontWeight: _texto.isEmpty ? FontWeight.w400 : FontWeight.w700,
          color: _texto.isEmpty ? AppColors.textoSecundario : AppColors.texto,
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
        onPressed: _texto.trim().isEmpty ? null : () => _cerrar(_texto),
        child: const Text('Buscar', style: TextStyle(fontSize: 18)),
      ),
      TextButton(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: () => _cerrar(null),
        child: const Text('Cancelar', style: TextStyle(fontSize: 18)),
      ),
    ],
  );
}
