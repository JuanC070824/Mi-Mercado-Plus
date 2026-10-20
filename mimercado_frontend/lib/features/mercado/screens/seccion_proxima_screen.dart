import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/encabezado_azul.dart';

/// Pantalla provisional para Canasta, Mi pedido y Perfil mientras se construyen.
/// Reemplázala por la pantalla real en app_router.dart.
class SeccionProximaScreen extends StatelessWidget {
  const SeccionProximaScreen({
    super.key,
    required this.titulo,
    required this.icono,
  });

  final String titulo;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          EncabezadoAzul(titulo: titulo, mostrarAtras: false),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: AppColors.azulClaro,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.azul, width: 2),
                      ),
                      child: Icon(icono, size: 48, color: AppColors.azul),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Esta sección estará disponible pronto.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.texto,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
