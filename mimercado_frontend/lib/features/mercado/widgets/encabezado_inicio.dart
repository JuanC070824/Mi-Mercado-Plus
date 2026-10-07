import 'package:flutter/material.dart';
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
    required this.onPerfil,
  });

  final String nombre;
  final TextEditingController controlador;
  final bool busquedaBloqueada; // true mientras no hay mercado elegido
  final VoidCallback onTapBusquedaBloqueada;
  final ValueChanged<String> onCambio;
  final VoidCallback onLimpiar;
  final VoidCallback onVoz;
  final VoidCallback onSoporte;
  final VoidCallback onPerfil;

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
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
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
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.headset_mic_outlined, size: 26),
                        ],
                      ),
                    ),
                  ),
                  // Pega aquí el mismo CircleAvatar que ajustaste en encabezado_azul.dart.
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
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            'Hola, $nombre!',
                            style: const TextStyle(
                              color: AppColors.blanco,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Semantics(
                        button: true,
                        label: 'Mi perfil',
                        onTap: onPerfil,
                        excludeSemantics: true,
                        child: Material(
                          color: AppColors.fondo,
                          shape: const StadiumBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: onPerfil,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.account_circle_outlined,
                                      size: 36, color: AppColors.azul),
                                  SizedBox(width: 8),
                                  Text(
                                    'Mi perfil',
                                    style: TextStyle(
                                      color: AppColors.azul,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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