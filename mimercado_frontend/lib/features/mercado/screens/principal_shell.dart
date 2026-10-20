import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/barra_navegacion_app.dart';

/// Marco que mantiene visible el menú inferior en Inicio, Canasta, Mi pedido y Perfil.
/// Cada sección conserva su estado al cambiar de pestaña.
/// El casero y el repartidor lo usan con sus propios [items].
class PrincipalShell extends StatelessWidget {
  const PrincipalShell({super.key, required this.navigationShell, this.items});

  final StatefulNavigationShell navigationShell;
  final List<ItemNavegacion>? items; // null = menú del cliente

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BarraNavegacionApp(
        items: items ?? itemsCliente,
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
