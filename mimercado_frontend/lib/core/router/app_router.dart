import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/direccion.dart';
import '../../data/models/pedido.dart';
import '../../data/models/rol.dart';
import '../../data/models/usuario.dart';
import '../../data/repositories/repositorios_app.dart';
import '../../features/auth/screens/bienvenida_screen.dart';
import '../../features/auth/screens/cliente_login_screen.dart';
import '../../features/auth/screens/cliente_registro_screen.dart';
import '../../features/canasta/screens/canasta_screen.dart';
import '../../features/canasta/screens/entrega_pago_screen.dart';
import '../../features/canasta/screens/pedido_enviado_screen.dart';
import '../../features/canasta/screens/puesto_screen.dart';
import '../../features/canasta/screens/yape_screen.dart';
import '../../features/casero/screens/casero_inicio_screen.dart';
import '../../features/casero/screens/catalogo_casero_screen.dart';
import '../../features/casero/screens/mis_pedidos_casero_screen.dart';
import '../../features/casero/screens/mi_puesto_screen.dart';
import '../../features/casero/screens/casero_pedido_screen.dart';
import '../../features/casero/screens/pesar_screen.dart';
import '../../features/mercado/screens/inicio_screen.dart';
import '../../features/mercado/screens/principal_shell.dart';
import '../../features/pedido/screens/historial_screen.dart';
import '../../features/pedido/screens/mi_pedido_screen.dart';
import '../../features/perfil/screens/perfil_screen.dart';
import '../widgets/barra_navegacion_app.dart';
import '../state/sesion_state.dart';
import '../state/preferencias_vendedor_state.dart';
import '../../data/repositories/pedidos_api_repository.dart';
import '../../features/repartidor/screens/repartidor_operaciones_screen.dart';

// ESTO ME SIRVE COMO LISTA DE RUTAS
// Por ejemplo, /cliente/login lleva a la pantalla de login

// Recuerda al usuario que entró, porque al cambiar de pestaña el "extra" ya no viaja.
Usuario? _usuarioActual;
Usuario? _ultimoUsuarioExtra;

/// Guarda al usuario que llega al iniciar sesión y lo devuelve.
Usuario _usuarioDe(GoRouterState state) {
  final extra = state.extra;
  if (extra is Usuario && !identical(extra, _ultimoUsuarioExtra)) {
    _ultimoUsuarioExtra = extra;
    _usuarioActual = extra;
    if (extra.rol == Rol.comerciante || extra.rol == Rol.repartidor) {
      // El cambio de escala reconstruye un ancestro del router.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (identical(extra, _ultimoUsuarioExtra)) {
          PreferenciasVendedorState.aplicar(_usuarioActual!);
        }
      });
    }
  }
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
  mostrarDireccion: _usuarioDe(state).rol == Rol.cliente,
  onUsuarioActualizado: (u) => _usuarioActual = u,
  onSesionCerrada: _cerrarSesion,
);

void _cerrarSesion() {
  PedidosApiRepository.instancia.limpiar();
  _ultimoUsuarioExtra = null;
  PreferenciasVendedorState.limpiar();
  _usuarioActual = null;
  SesionState.cerrar();
  canastaApp.vaciar(); // la canasta no pasa al siguiente usuario
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
                  (state.extra is Usuario || _usuarioActual != null)
                  ? null
                  : '/',
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
                  redirect: (context, state) =>
                      _usuarioActual == null ? '/' : null,
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
                    pedido: state.extra is Pedido
                        ? state.extra! as Pedido
                        : null,
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
              builder: (context, state) =>
                  MiPedidoScreen(usuario: _usuarioActual!),
              routes: [
                // C9 · Mis pedidos (historial)
                GoRoute(
                  path: 'historial',
                  builder: (context, state) =>
                      HistorialScreen(usuario: _usuarioActual!),
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
    GoRoute(
      path: '/casero/registro',
      builder: (context, state) =>
          const ClienteRegistroScreen(rol: Rol.comerciante),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          PrincipalShell(navigationShell: navigationShell, items: itemsCasero),
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
              builder: (context, state) =>
                  MisPedidosCaseroScreen(usuario: _usuarioDe(state)),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/casero/catalogo',
              redirect: (context, state) => _exigirRol(state, Rol.comerciante),
              builder: (context, state) =>
                  CatalogoCaseroScreen(usuario: _usuarioDe(state)),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/casero/puesto',
              redirect: (context, state) => _exigirRol(state, Rol.comerciante),
              builder: (context, state) => MiPuestoScreen(
                usuario: _usuarioDe(state),
                onUsuarioActualizado: (u) {
                  _usuarioActual = _usuarioActual!.copyWith(
                    letraGrande: u.letraGrande,
                    sonido: u.sonido,
                    vibracion: u.vibracion,
                  );
                  PreferenciasVendedorState.aplicar(_usuarioActual!);
                },
                onPuestoGuardado: (puesto) {
                  _usuarioActual = _usuarioActual!.copyWith(
                    puestoId: puesto.id,
                    mercadoId: puesto.mercado.id,
                  );
                },
              ),
              routes: [
                GoRoute(
                  path: 'perfil',
                  builder: (context, state) => PerfilScreen(
                    usuario: _usuarioDe(state),
                    mostrarDireccion: false,
                    mostrarAtras: true,
                    onUsuarioActualizado: (u) => _usuarioActual = u,
                    onSesionCerrada: _cerrarSesion,
                  ),
                ),
              ],
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
    GoRoute(
      path: '/repartidor/registro',
      builder: (context, state) =>
          const ClienteRegistroScreen(rol: Rol.repartidor),
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
                  RepartidorOperacionesScreen(usuario: _usuarioDe(state)),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/repartidor/ruta',
              redirect: (context, state) => _exigirRol(state, Rol.repartidor),
              builder: (context, state) => RepartidorOperacionesScreen(
                usuario: _usuarioDe(state),
                vista: 'ruta',
              ),
              routes: [
                // R3 · Entrega y cobro
                GoRoute(
                  path: 'entrega',
                  builder: (context, state) => RepartidorOperacionesScreen(
                    usuario: _usuarioDe(state),
                    vista: 'entrega',
                  ),
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
              builder: (context, state) => RepartidorOperacionesScreen(
                usuario: _usuarioDe(state),
                vista: 'ganancias',
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
