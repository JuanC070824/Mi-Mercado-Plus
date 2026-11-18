import 'package:flutter/material.dart';

import 'package:mimercado_frontend/core/i18n/idioma.dart';

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
  Widget build(BuildContext context) => Text(
    tr(
      'El formulario integrado está disponible en la versión web de MiMercado+.',
    ),
  );
}
