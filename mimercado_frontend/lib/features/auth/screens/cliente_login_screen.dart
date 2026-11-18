import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/api_config.dart';
import '../../../data/repositories/auth_api_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/botones_app.dart';
import '../../../core/widgets/campo_texto_app.dart';
import '../../../core/widgets/encabezado_azul.dart';
import '../../../core/widgets/mensaje_error.dart';
import '../../../data/models/rol.dart';
import '../../../data/repositories/auth_repository.dart';

//PANTALLA DE LOGIN (la usan los 3 perfiles: cliente, casero y repartidor)

class ClienteLoginScreen extends StatefulWidget {
  const ClienteLoginScreen({super.key, this.rol = Rol.cliente});

  final Rol rol;

  /// Pantalla a la que entra cada perfil después de iniciar sesión.
  static const inicioPorRol = {
    Rol.cliente: '/inicio',
    Rol.comerciante: '/casero/inicio',
    Rol.repartidor: '/repartidor/inicio',
  };

  static const registroPorRol = {
    Rol.cliente: '/cliente/registro',
    Rol.comerciante: '/casero/registro',
    Rol.repartidor: '/repartidor/registro',
  };

  @override
  State<ClienteLoginScreen> createState() => _ClienteLoginScreenState();
}

class _ClienteLoginScreenState extends State<ClienteLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _celular = TextEditingController();
  final _password = TextEditingController();
  late final LoginRepository _repo;

  bool _cargando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = ApiConfig.configurada || widget.rol == Rol.repartidor
        ? AuthApiRepository.instancia
        : AuthRepositoryMock.instancia;
  }

  @override
  void dispose() {
    _celular.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    if (widget.rol == Rol.repartidor && !ApiConfig.configurada) {
      setState(
        () => _error =
            'No está configurada la conexión al servicio de repartidores. Solicita al responsable iniciar la versión conectada al servidor.',
      );
      return;
    }

    setState(() => _cargando = true);
    final r = await _repo.iniciarSesion(
      celular: _celular.text.trim(),
      password: _password.text,
      rol: widget.rol,
    );
    if (!mounted) return;
    setState(() => _cargando = false);

    if (r.exito) {
      context.go(
        ClienteLoginScreen.inicioPorRol[widget.rol]!,
        extra: r.usuario,
      );
    } else {
      setState(() => _error = r.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const EncabezadoAzul(titulo: 'Iniciar sesión'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _InsigniaPerfil(rol: widget.rol),
                          const SizedBox(height: 20),
                          CampoTextoApp(
                            etiqueta: 'Celular',
                            hint: '9 dígitos',
                            prefijo: '+51 ',
                            controller: _celular,
                            teclado: TextInputType.phone,
                            soloDigitos: true,
                            maxLongitud: 9,
                            mostrarContador: true,
                            icono: Icons.phone_android,
                            autofillHints: const [
                              AutofillHints.telephoneNumberNational,
                            ],
                            validator: Validadores.celular,
                          ),
                          const SizedBox(height: 12),
                          CampoTextoApp(
                            etiqueta: 'Contraseña',
                            controller: _password,
                            esPassword: true,
                            icono: Icons.lock_outline,
                            accion: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onSubmitted: (_) => _ingresar(),
                            validator: (v) => Validadores.requerido(
                              v,
                              campo: 'La contraseña',
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                // TODO: recuperación de contraseña cuando exista en el backend
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Para recuperar tu contraseña, escríbenos desde Soporte.',
                                    ),
                                  ),
                                );
                              },
                              child: const Text(
                                '¿Olvidaste tu contraseña?',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.azul,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_error != null) ...[
                            MensajeError(_error!),
                            const SizedBox(height: 16),
                          ],
                          BotonPrincipal(
                            texto: 'Ingresar',
                            cargando: _cargando,
                            onPressed: _ingresar,
                          ),
                          const SizedBox(height: 24),
                          const _SeparadorTexto('¿Primera vez en MiMercado+?'),
                          const SizedBox(height: 16),
                          BotonSecundario(
                            texto: 'Crear mi cuenta',
                            onPressed: () => context.push(
                              ClienteLoginScreen.registroPorRol[widget.rol]!,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => context.go('/'),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                            child: Text(
                              '¿No eres ${widget.rol.etiqueta.toLowerCase()}? '
                              'Cambiar de perfil',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.azul,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsigniaPerfil extends StatelessWidget {
  const _InsigniaPerfil({required this.rol});

  final Rol rol;

  static const _iconos = {
    Rol.cliente: Icons.shopping_basket_outlined,
    Rol.comerciante: Icons.storefront_outlined,
    Rol.repartidor: Icons.delivery_dining_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.blanco,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.azul, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconos[rol], color: AppColors.azul, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Perfil: ${rol.etiqueta}',
                style: const TextStyle(
                  color: AppColors.azul,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeparadorTexto extends StatelessWidget {
  const _SeparadorTexto(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.textoSecundario)),
        // Flexible: con letra grande el texto baja de línea en vez de desbordar.
        Flexible(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textoSecundario,
              ),
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.textoSecundario)),
      ],
    );
  }
}
