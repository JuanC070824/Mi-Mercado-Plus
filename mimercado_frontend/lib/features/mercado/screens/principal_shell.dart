import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/barra_navegacion_app.dart';

/// Marco que mantiene visible el menú inferior en Inicio, Canasta, Mi pedido y Perfil.
/// Cada sección conserva su estado al cambiar de pestaña.
class PrincipalShell extends StatelessWidget {
  const PrincipalShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BarraNavegacionApp(
        indiceActual: navigationShell.currentIndex,
        onSeleccion: (i) => navigationShell.goBranch(
          i,
          // tocar la pestaña activa vuelve a su pantalla raíz
          initialLocation: i == navigationShell.currentIndex,
        ),
      ),
    );
  }
}