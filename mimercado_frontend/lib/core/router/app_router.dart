import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/direccion.dart';
import '../../data/models/pedido.dart';
import '../../data/models/rol.dart';
import '../../data/models/usuario.dart';
import '../../data/repositories/canasta_repository.dart';
import '../../features/auth/screens/bienvenida_screen.dart';
import '../../features/auth/screens/cliente_login_screen.dart';
import '../../features/auth/screens/cliente_registro_screen.dart';
import '../../features/canasta/screens/canasta_screen.dart';
import '../../features/canasta/screens/entrega_pago_screen.dart';
import '../../features/canasta/screens/pedido_enviado_screen.dart';
import '../../features/canasta/screens/puesto_screen.dart';
import '../../features/canasta/screens/yape_screen.dart';
import '../../features/casero/screens/casero_inicio_screen.dart';
import '../../features/casero/screens/casero_pedido_screen.dart';
import '../../features/casero/screens/pesar_screen.dart';
import '../../features/mercado/screens/inicio_screen.dart';
import '../../features/mercado/screens/principal_shell.dart';
import '../../features/mercado/screens/seccion_proxima_screen.dart';
import '../../features/pedido/screens/historial_screen.dart';
import '../../features/pedido/screens/mi_pedido_screen.dart';
import '../../features/perfil/screens/perfil_screen.dart';
import '../../features/repartidor/screens/entrega_screen.dart';
import '../../features/repartidor/screens/repartidor_inicio_screen.dart';
import '../../features/repartidor/screens/ruta_screen.dart';
import '../widgets/barra_navegacion_app.dart';

// ESTO ME SIRVE COMO LISTA DE RUTAS
// Por ejemplo, /cliente/login lleva a la pantalla de login

// Recuerda al usuario que entró, porque al cambiar de pestaña el "extra" ya no viaja.
Usuario? _usuarioActual;

/// Guarda al usuario que llega al iniciar sesión y lo devuelve.
Usuario _usuarioDe(GoRouterState state) {
  final extra = state.extra;
  if (extra is Usuario) _usuarioActual = extra;
  return _usuarioActual!;
}

/// Si no hay sesión de ese perfil (ej. recargaron la página), vuelve a la bienvenida.
String? _exigirRol(GoRouterState state, Rol rol) {
  final extra = state.extra;
  final u = extra is Usuario ? extra : _usuarioActual;
  return u?.rol == rol ? null : '/';
}

/// Perfil con cerrar sesión. Lo usan el repartidor y, por ahora, "Mi puesto" del casero.
Widget _perfil(GoRouterState state) => PerfilScreen(
      usuario: _usuarioDe(state),
      onUsuarioActualizado: (u) => _usuarioActual = u,
      onSesionCerrada: _cerrarSesion,
    );

void _cerrarSesion() {
  _usuarioActual = null;
  CanastaRepositoryMock.instancia.vaciar(); // la canasta no pasa al siguiente usuario
}

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
              routes: [
                // C2 · Puesto (dentro de Inicio para que siga el menú inferior)
                GoRoute(
                  path: 'puesto/:id',
                  builder: (context, state) => PuestoScreen(
                    puestoId: int.parse(state.pathParameters['id']!),
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/canasta',
              builder: (context, state) => const CanastaScreen(),
              routes: [
                // C4 · Entrega y pago → C4b Yape → C4c ¡Pedido enviado!
                GoRoute(
                  path: 'entrega',
                  redirect: (context, state) => _usuarioActual == null ? '/' : null,
                  builder: (context, state) =>
                      EntregaPagoScreen(usuario: _usuarioActual!),
                ),
                GoRoute(
                  path: 'yape',
                  redirect: (context, state) =>
                      (_usuarioActual == null || state.extra is! Direccion)
                          ? '/canasta'
                          : null,
                  builder: (context, state) => YapeScreen(
                    usuario: _usuarioActual!,
                    direccion: state.extra! as Direccion,
                  ),
                ),
                GoRoute(
                  path: 'enviado',
                  builder: (context, state) => PedidoEnviadoScreen(
                    pedido: state.extra is Pedido ? state.extra! as Pedido : null,
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/pedido',
              redirect: (context, state) => _usuarioActual == null ? '/' : null,
              builder: (context, state) => MiPedidoScreen(usuario: _usuarioActual!),
              routes: [
                // C9 · Mis pedidos (historial)
                GoRoute(
                  path: 'historial',
                  builder: (context, state) => HistorialScreen(usuario: _usuarioActual!),
                ),
              ],
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
                onSesionCerrada: _cerrarSesion,
              ),
            ),
          ],
        ),
      ],
    ),

    // ---------------- Casero (comerciante) ----------------
    GoRoute(
      path: '/casero/login',
      builder: (context, state) =>
          const ClienteLoginScreen(rol: Rol.comerciante),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => PrincipalShell(
        navigationShell: navigationShell,
        items: itemsCasero,
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/casero/inicio',
              redirect: (context, state) => _exigirRol(state, Rol.comerciante),
              builder: (context, state) =>
                  CaseroInicioScreen(usuario: _usuarioDe(state)),
              routes: [
                GoRoute(
                  path: 'pedido/:id',
                  builder: (context, state) => CaseroPedidoScreen(
                    pedidoId: int.parse(state.pathParameters['id']!),
                    usuario: _usuarioDe(state),
                  ),
                  routes: [
                    // V3 · Pesar y poner precio
                    GoRoute(
                      path: 'pesar',
                      builder: (context, state) => PesarScreen(
                        pedidoId: int.parse(state.pathParameters['id']!),
                        usuario: _usuarioDe(state),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/casero/pedidos',
              redirect: (context, state) => _exigirRol(state, Rol.comerciante),
              builder: (context, state) => const SeccionProximaScreen(
                titulo: 'Mis pedidos',
                icono: Icons.receipt_long_rounded,
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/casero/catalogo',
              redirect: (context, state) => _exigirRol(state, Rol.comerciante),
              builder: (context, state) => const SeccionProximaScreen(
                titulo: 'Mi catálogo',
                icono: Icons.inventory_2_rounded,
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/casero/puesto',
              redirect: (context, state) => _exigirRol(state, Rol.comerciante),
              // TODO(V8): reemplazar por "Mi puesto" (ganancias, comisión, horario).
              builder: (context, state) => _perfil(state),
            ),
          ],
        ),
      ],
    ),

    // ---------------- Repartidor ----------------
    GoRoute(
      path: '/repartidor/login',
      builder: (context, state) =>
          const ClienteLoginScreen(rol: Rol.repartidor),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => PrincipalShell(
        navigationShell: navigationShell,
        items: itemsRepartidor,
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/repartidor/inicio',
              redirect: (context, state) => _exigirRol(state, Rol.repartidor),
              builder: (context, state) =>
                  RepartidorInicioScreen(usuario: _usuarioDe(state)),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/repartidor/ruta',
              redirect: (context, state) => _exigirRol(state, Rol.repartidor),
              builder: (context, state) => RutaScreen(usuario: _usuarioDe(state)),
              routes: [
                // R3 · Entrega y cobro
                GoRoute(
                  path: 'entrega',
                  builder: (context, state) =>
                      EntregaScreen(usuario: _usuarioDe(state)),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/repartidor/ganancias',
              redirect: (context, state) => _exigirRol(state, Rol.repartidor),
              builder: (context, state) => const SeccionProximaScreen(
                titulo: 'Ganancias',
                icono: Icons.payments_rounded,
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/repartidor/perfil',
              redirect: (context, state) => _exigirRol(state, Rol.repartidor),
              builder: (context, state) => _perfil(state),
            ),
          ],
        ),
      ],
    ),
  ],
);
