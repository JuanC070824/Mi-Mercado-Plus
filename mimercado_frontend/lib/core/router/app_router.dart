import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/usuario.dart';
import '../../features/auth/screens/bienvenida_screen.dart';
import '../../features/auth/screens/cliente_login_screen.dart';
import '../../features/auth/screens/cliente_registro_screen.dart';
import '../../features/mercado/screens/inicio_screen.dart';
import '../../features/mercado/screens/principal_shell.dart';
import '../../features/mercado/screens/seccion_proxima_screen.dart';
import '../../features/perfil/screens/perfil_screen.dart';

// ESTO ME SIRVE COMO LISTA DE RUTAS
// Por ejemplo, /cliente/login lleva a la pantalla de login

// Recuerda al usuario que entró, porque al cambiar de pestaña el "extra" ya no viaja.
Usuario? _usuarioActual;

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const BienvenidaScreen()),
    GoRoute(
      path: '/cliente/login',
      builder: (context, state) => const ClienteLoginScreen(),
    ),
    GoRoute(
      path: '/cliente/registro',
      builder: (context, state) => const ClienteRegistroScreen(),
    ),

    // Pantallas con menú horizontal inferior: Inicio, Canasta, Mi pedido, Perfil
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          PrincipalShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/inicio',
              // si recargan la página y no hay usuario, vuelven a la bienvenida
              redirect: (context, state) =>
                  (state.extra is Usuario || _usuarioActual != null) ? null : '/',
              builder: (context, state) {
                final extra = state.extra;
                if (extra is Usuario) _usuarioActual = extra;
                return InicioScreen(usuario: _usuarioActual!);
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/canasta',
              builder: (context, state) => const SeccionProximaScreen(
                titulo: 'Mi canasta',
                icono: Icons.shopping_basket_rounded,
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/pedido',
              builder: (context, state) => const SeccionProximaScreen(
                titulo: 'Mi pedido',
                icono: Icons.inventory_2_rounded,
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/perfil',
              redirect: (context, state) => _usuarioActual == null ? '/' : null,
              builder: (context, state) => PerfilScreen(
                usuario: _usuarioActual!,
                onUsuarioActualizado: (u) => _usuarioActual = u,
                onSesionCerrada: () => _usuarioActual = null,
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);