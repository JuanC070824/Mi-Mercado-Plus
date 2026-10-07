import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/rol.dart';
import '../widgets/rol_button.dart';
import 'package:go_router/go_router.dart';

//PANTALLA DE BIENVENIDA INICIAL

class BienvenidaScreen extends StatelessWidget {
  const BienvenidaScreen({super.key});

  static const _avatares = {
    Rol.cliente: 'assets/images/avatar_cliente.png',
    Rol.repartidor: 'assets/images/avatar_repartidor.png',
    Rol.comerciante: 'assets/images/avatar_comerciante.png',
  };

void _elegirRol(BuildContext context, Rol rol) {
  switch (rol) {
    case Rol.cliente:
      context.push('/cliente/login');
    case Rol.repartidor:
    case Rol.comerciante:
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('El acceso para ${rol.etiqueta} estará disponible pronto.'),
        ),
      );
  }
}

  @override
  Widget build(BuildContext context) {
    final sinAnimacion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(   // evita desbordes con texto grande
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Portada(estatica: sinAnimacion),
                  const SizedBox(height: 24),
                  const Text(
                    'Del mercado a tu puerta. Fresco, rápido y sin vueltas',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.azul,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Semantics(
                    header: true,
                    child: const Text(
                      'Soy:',
                      style: TextStyle(
                        color: AppColors.azul,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final rol in Rol.values)
                        Expanded(
                          child: RolButton(
                            etiqueta: rol.etiqueta,
                            imagen: _avatares[rol]!,
                            onTap: () => _elegirRol(context, rol),
                          ),
                        ),
                    ],
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

class _Portada extends StatelessWidget {
  const _Portada({required this.estatica});
  final bool estatica;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.85,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Image.asset(
                estatica
                    ? 'assets/images/fondo_mercado.png'
                    : 'assets/images/fondo_mercado.gif',
                fit: BoxFit.cover,
                excludeFromSemantics: true,   // es decorativo
                errorBuilder: (context, error, stack) => Container(
                  color: AppColors.azul.withValues(alpha: 0.15),
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }
}