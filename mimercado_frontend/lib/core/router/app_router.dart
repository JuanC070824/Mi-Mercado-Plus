import 'package:go_router/go_router.dart';
import '../../features/auth/screens/bienvenida_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',   // la pantalla inicial es la bienvenida
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const BienvenidaScreen(),
    ),
  ],
);