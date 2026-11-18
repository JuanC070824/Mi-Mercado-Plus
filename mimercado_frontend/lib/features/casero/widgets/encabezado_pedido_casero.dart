import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/soporte_dialog.dart';

/// Cabecera de las tareas del vendedor: las acciones no comprimen el título.
class EncabezadoPedidoCasero extends StatelessWidget {
  const EncabezadoPedidoCasero({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.habilitado = true,
    this.mostrarAtras = true,
  });

  final String titulo;
  final String? subtitulo;
  final bool habilitado;
  final bool mostrarAtras;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: AppColors.azul,
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (mostrarAtras)
                  IconButton(
                    tooltip: 'Volver',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: !habilitado
                        ? null
                        : () => context.canPop()
                              ? context.pop()
                              : context.go('/casero/inicio'),
                    icon: const Icon(Icons.arrow_back, color: AppColors.blanco),
                  ),
                TextButton.icon(
                  onPressed: () => mostrarSoporte(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.blanco,
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.headset_mic_outlined),
                  label: const Text('Soporte', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Semantics(
              header: true,
              child: Text(
                titulo,
                style: const TextStyle(
                  color: AppColors.blanco,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (subtitulo != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitulo!,
                style: const TextStyle(color: AppColors.blanco, fontSize: 16),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
