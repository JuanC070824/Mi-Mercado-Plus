import 'package:flutter/material.dart';
import '../../../core/state/accesibilidad_state.dart';
import '../../../core/theme/app_colors.dart';

class EncabezadoInicio extends StatelessWidget {
  const EncabezadoInicio({
    super.key,
    required this.nombre,
    required this.controlador,
    required this.busquedaBloqueada,
    required this.onTapBusquedaBloqueada,
    required this.onCambio,
    required this.onLimpiar,
    required this.onVoz,
    required this.onSoporte,
  });

  final String nombre;
  final TextEditingController controlador;
  final bool busquedaBloqueada; // true mientras no hay mercado elegido
  final VoidCallback onTapBusquedaBloqueada;
  final ValueChanged<String> onCambio;
  final VoidCallback onLimpiar;
  final VoidCallback onVoz;
  final VoidCallback onSoporte;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.azul,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      const _BotonLetra(),
                      const Spacer(),
                      TextButton(
                        onPressed: onSoporte,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.blanco,
                          minimumSize: const Size(48, 48),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Soporte',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.headset_mic_outlined, size: 26),
                          ],
                        ),
                      ),
                    ],
                  ),
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: AppColors.fondo,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Transform.translate(
                        offset: const Offset(0, 0),
                        child: Transform.scale(
                          scale: 1.6,
                          child: Image.asset(
                            'assets/images/logo_mimercado.png',
                            fit: BoxFit.contain,
                            semanticLabel: 'Logo de MiMercado+',
                            errorBuilder: (context, error, stack) => const Icon(
                              Icons.storefront,
                              size: 48,
                              color: AppColors.azul,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.center,
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Hola, $nombre!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.blanco,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controlador,
                    builder: (context, value, _) {
                      return TextField(
                        controller: controlador,
                        readOnly: busquedaBloqueada,
                        onTap: busquedaBloqueada ? onTapBusquedaBloqueada : null,
                        onChanged: onCambio,
                        textInputAction: TextInputAction.search,
                        style: const TextStyle(fontSize: 20, color: AppColors.texto),
                        decoration: InputDecoration(
                          hintText: 'Busca a tu casero',
                          hintStyle: const TextStyle(
                            fontSize: 20,
                            color: AppColors.textoSecundario,
                          ),
                          filled: true,
                          fillColor: AppColors.fondo,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 18,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(32),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(32),
                            borderSide: const BorderSide(
                              color: Color(0xFFFFD166), // anillo de foco visible sobre el azul
                              width: 3,
                            ),
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (value.text.isNotEmpty)
                                IconButton(
                                  tooltip: 'Borrar búsqueda',
                                  constraints: const BoxConstraints(
                                      minWidth: 48, minHeight: 48),
                                  icon: const Icon(Icons.close, color: AppColors.azul),
                                  onPressed: onLimpiar,
                                ),
                              IconButton(
                                tooltip: 'Buscar por voz',
                                constraints: const BoxConstraints(
                                    minWidth: 48, minHeight: 48),
                                icon: const Icon(Icons.mic,
                                    size: 28, color: AppColors.azul),
                                onPressed: onVoz,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Aa Letra": alterna el tamaño de letra de toda la app.
/// Activo = fondo crema + texto azul + check (no depende solo del color).
class _BotonLetra extends StatelessWidget {
  const _BotonLetra();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AccesibilidadState.letraGrande,
      builder: (context, grande, _) {
        final texto = grande ? AppColors.azul : AppColors.blanco;
        return Semantics(
          button: true,
          toggled: grande,
          label: 'Letra grande',
          onTap: AccesibilidadState.alternarLetra,
          excludeSemantics: true,
          child: Material(
            color: grande ? AppColors.fondo : Colors.transparent,
            shape: const StadiumBorder(
              side: BorderSide(color: AppColors.fondo, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: AccesibilidadState.alternarLetra,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Aa',
                        style: TextStyle(
                          color: texto,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Letra',
                        style: TextStyle(
                          color: texto,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (grande) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.check_circle,
                            color: AppColors.azul, size: 22),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}