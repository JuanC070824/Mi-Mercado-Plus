import 'package:go_router/go_router.dart';
import '../../data/models/usuario.dart';
import '../../features/auth/screens/bienvenida_screen.dart';
import '../../features/auth/screens/cliente_login_screen.dart';
import '../../features/auth/screens/cliente_registro_screen.dart';
import '../../features/mercado/screens/inicio_screen.dart';

// ESTO ME SIRVE COMO LISTA DE RUTAS
// Por ejemplo, /cliente/login lleva a la pantalla de login

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
    GoRoute(
      path: '/inicio',
      builder: (context, state) {
        final usuario = state.extra;
        if (usuario is Usuario) return InicioScreen(usuario: usuario);
        return const BienvenidaScreen(); // si recargan la página, vuelven al inicio
      },
    ),
  ],
);