import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import 'soporte_dialog.dart';

/// Franja azul compacta para las pantallas internas: volver, título y Soporte.
/// (EncabezadoAzul, con el logo grande, queda para login, registro y relleno).
class EncabezadoSimple extends StatelessWidget {
  const EncabezadoSimple({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.mostrarAtras = true,
    this.alVolver,
  });

  final String titulo;
  final String? subtitulo;
  final bool mostrarAtras;
  final VoidCallback? alVolver; // por defecto: pop, o Inicio si no hay a dónde volver

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.azul,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (mostrarAtras)
                IconButton(
                  tooltip: 'Volver',
                  iconSize: 28,
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: const Icon(Icons.arrow_back, color: AppColors.blanco),
                  onPressed: alVolver ??
                      () => context.canPop() ? context.pop() : context.go('/'),
                )
              else
                const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      if (subtitulo != null)
                        Text(
                          subtitulo!,
                          style: const TextStyle(
                            color: AppColors.blanco,
                            fontSize: 16,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => mostrarSoporte(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.blanco,
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.headset_mic_outlined),
                label: const Text(
                  'Soporte',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
