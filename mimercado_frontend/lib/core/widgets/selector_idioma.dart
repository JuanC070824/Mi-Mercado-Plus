import 'package:flutter/material.dart';

import '../i18n/idioma.dart';
import '../theme/app_colors.dart';
import 'componentes_app.dart';

/// Abre la lista de idiomas: Español, Quechua y Aymara.
Future<void> elegirIdioma(BuildContext context) async {
  final elegido = await showModalBottomSheet<Idioma>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                tr('Idioma'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.texto,
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final i in Idioma.values) ...[
              _OpcionIdioma(
                idioma: i,
                elegido: i == IdiomaState.actual.value,
                onTap: () => Navigator.pop(ctx, i),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    ),
  );
  if (elegido != null && elegido != IdiomaState.actual.value) {
    await IdiomaState.cambiar(elegido);
  }
}

class _OpcionIdioma extends StatelessWidget {
  const _OpcionIdioma({
    required this.idioma,
    required this.elegido,
    required this.onTap,
  });

  final Idioma idioma;
  final bool elegido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: elegido,
      button: true,
      child: Material(
        color: elegido ? AppColors.azulClaro : AppColors.blanco,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: elegido ? AppColors.azul : AppColors.borde,
            width: elegido ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      idioma.nombre,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: elegido ? FontWeight.w800 : FontWeight.w600,
                        color: AppColors.texto,
                      ),
                    ),
                  ),
                  if (elegido)
                    const Icon(Icons.check_circle, color: AppColors.azul),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón compacto para la bienvenida: ícono de idioma + idioma actual.
class BotonIdioma extends StatelessWidget {
  const BotonIdioma({super.key});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: AppColors.azul,
        side: const BorderSide(color: AppColors.azul),
        shape: const StadiumBorder(),
      ),
      onPressed: () => elegirIdioma(context),
      icon: const Icon(Icons.translate),
      label: Text(
        IdiomaState.actual.value.nombre,
        semanticsLabel: tr('Idioma: {0}. Toca para cambiarlo', [
          IdiomaState.actual.value.nombre,
        ]),
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Fila para Perfil, con el mismo aspecto que las demás preferencias.
class FilaIdioma extends StatelessWidget {
  const FilaIdioma({super.key});

  @override
  Widget build(BuildContext context) {
    return TarjetaApp(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => elegirIdioma(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              const Icon(Icons.translate, color: AppColors.azul),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr('Idioma'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.texto,
                  ),
                ),
              ),
              Text(
                IdiomaState.actual.value.nombre,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.azul,
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.azul),
            ],
          ),
        ),
      ),
    );
  }
}
