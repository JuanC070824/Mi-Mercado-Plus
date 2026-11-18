import 'package:flutter/material.dart';
import '../../../core/widgets/componentes_app.dart';

import 'package:mimercado_frontend/core/i18n/idioma.dart';

/// Identifica la afiliación de la cuenta, sin confundir solicitud y autorización.
class MercadoRepartidor extends StatelessWidget {
  const MercadoRepartidor({super.key, required this.datos});
  final Map<String, dynamic> datos;

  @override
  Widget build(BuildContext context) {
    final autorizado = datos['autorizado'] == true;
    final pendiente = datos['pendiente'] == true;
    final mercado = datos['mercado'];
    final nombre = autorizado
        ? (mercado is Map ? mercado['nombre']?.toString() : null)
        : datos['mercado_solicitado']?.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            autorizado
                ? tr('Mi mercado asignado')
                : pendiente
                ? tr('Mi mercado solicitado')
                : tr('Sin mercado autorizado'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ),
        if (nombre != null && nombre.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            nombre,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
          ),
        ],
        const SizedBox(height: 8),
        EtiquetaEstado(
          texto: autorizado
              ? tr('Autorizado para repartir')
              : pendiente
              ? tr('Autorización pendiente')
              : tr('Aún no tienes un mercado autorizado'),
          icono: autorizado ? Icons.verified_outlined : Icons.info_outline,
          tipo: autorizado ? TipoEstado.exito : TipoEstado.aviso,
        ),
        const SizedBox(height: 8),
        Text(
          autorizado
              ? tr('Recibirás únicamente pedidos de este mercado.')
              : pendiente
              ? tr(
                  'La solicitud está registrada. El responsable debe autorizar tu cuenta antes de recibir pedidos.',
                )
              : tr(
                  'Solicita tu mercado desde Inicio para poder recibir pedidos.',
                ),
          style: const TextStyle(fontSize: 18),
        ),
      ],
    );
  }
}
