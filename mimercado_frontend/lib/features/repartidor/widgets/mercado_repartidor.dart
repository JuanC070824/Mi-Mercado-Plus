import 'package:flutter/material.dart';
import '../../../core/widgets/componentes_app.dart';

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
                ? 'Mi mercado asignado'
                : pendiente
                ? 'Mi mercado solicitado'
                : 'Sin mercado autorizado',
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
              ? 'Autorizado para repartir'
              : pendiente
              ? 'Autorización pendiente'
              : 'Aún no tienes un mercado autorizado',
          icono: autorizado ? Icons.verified_outlined : Icons.info_outline,
          tipo: autorizado ? TipoEstado.exito : TipoEstado.aviso,
        ),
        const SizedBox(height: 8),
        Text(
          autorizado
              ? 'Recibirás únicamente pedidos de este mercado.'
              : pendiente
              ? 'La solicitud está registrada. El responsable debe autorizar tu cuenta antes de recibir pedidos.'
              : 'Solicita tu mercado desde Inicio para poder recibir pedidos.',
          style: const TextStyle(fontSize: 18),
        ),
      ],
    );
  }
}
