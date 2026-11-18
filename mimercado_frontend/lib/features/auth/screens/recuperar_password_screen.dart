import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/api_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/botones_app.dart';
import '../../../core/widgets/campo_texto_app.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../core/widgets/encabezado_azul.dart';
import '../../../core/widgets/mensaje_error.dart';
import '../../../data/models/rol.dart';
import '../../../data/repositories/auth_api_repository.dart';
import '../widgets/requisitos_password.dart';

/// RF-04 en dos pasos: 1) celular + DNI del titular, 2) código y nueva contraseña.
class RecuperarPasswordScreen extends StatefulWidget {
  const RecuperarPasswordScreen({
    super.key,
    this.rol = Rol.cliente,
    this.repository,
  });

  final Rol rol;
  final AuthApiRepository? repository;

  static const loginPorRol = {
    Rol.cliente: '/cliente/login',
    Rol.comerciante: '/casero/login',
    Rol.repartidor: '/repartidor/login',
    Rol.administrador: '/admin/login',
  };

  @override
  State<RecuperarPasswordScreen> createState() =>
      _RecuperarPasswordScreenState();
}

class _RecuperarPasswordScreenState extends State<RecuperarPasswordScreen> {
  final _formIdentidad = GlobalKey<FormState>();
  final _formClave = GlobalKey<FormState>();
  final _celular = TextEditingController();
  final _dni = TextEditingController();
  final _codigo = TextEditingController();
  final _password = TextEditingController();
  final _confirmacion = TextEditingController();
  late final _repo = widget.repository ?? AuthApiRepository.instancia;

  bool _enCodigo = false, _cargando = false;
  String? _error, _codigoDemostracion;

  @override
  void dispose() {
    for (final c in [_celular, _dni, _codigo, _password, _confirmacion]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _sinServidor => widget.repository == null && !ApiConfig.configurada;

  Future<void> _pedirCodigo() async {
    setState(() => _error = null);
    if (!_formIdentidad.currentState!.validate()) return;
    if (_sinServidor) {
      setState(
        () => _error = 'Recuperar la contraseña necesita conexión al servidor.',
      );
      return;
    }
    setState(() => _cargando = true);
    final r = await _repo.solicitarRecuperacion(
      celular: _celular.text.trim(),
      dni: _dni.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _cargando = false;
      if (r.exito) {
        _enCodigo = true;
        _codigoDemostracion = r.codigoDemostracion;
      } else {
        _error = r.mensaje;
      }
    });
  }

  Future<void> _cambiar() async {
    setState(() => _error = null);
    if (!_formClave.currentState!.validate()) return;
    setState(() => _cargando = true);
    final r = await _repo.restablecerPassword(
      celular: _celular.text.trim(),
      codigo: _codigo.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    setState(() => _cargando = false);
    if (!r.exito) {
      setState(() => _error = r.mensaje);
      return;
    }
    avisar(context, r.mensaje);
    context.go(RecuperarPasswordScreen.loginPorRol[widget.rol]!);
  }

  void _volverAlPaso1() => setState(() {
    _enCodigo = false;
    _error = null;
    _codigo.clear();
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const EncabezadoAzul(titulo: 'Recuperar contraseña'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: _enCodigo ? _pasoClave() : _pasoIdentidad(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pasoIdentidad() => Form(
    key: _formIdentidad,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Paso('Paso 1 de 2'),
        const Text(
          'Escribe tu celular y tu DNI. Revisaremos que la cuenta sea tuya.',
          style: TextStyle(fontSize: 18),
        ),
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
          validator: Validadores.celular,
        ),
        const SizedBox(height: 12),
        CampoTextoApp(
          etiqueta: 'DNI',
          hint: '8 dígitos',
          controller: _dni,
          teclado: TextInputType.number,
          soloDigitos: true,
          maxLongitud: 8,
          mostrarContador: true,
          icono: Icons.badge_outlined,
          accion: TextInputAction.done,
          onSubmitted: (_) => _pedirCodigo(),
          validator: Validadores.dni,
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          MensajeError(_error!),
          const SizedBox(height: 16),
        ],
        BotonPrincipal(
          texto: 'Continuar',
          cargando: _cargando,
          onPressed: _pedirCodigo,
        ),
      ],
    ),
  );

  Widget _pasoClave() => Form(
    key: _formClave,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Paso('Paso 2 de 2'),
        if (_codigoDemostracion case final codigo?) ...[
          TarjetaApp(
            color: AppColors.azulClaro,
            colorBorde: AppColors.azul,
            child: Semantics(
              liveRegion: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tu código (modo demostración)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    codigo,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 6,
                      color: AppColors.azul,
                    ),
                  ),
                  const Text(
                    'En la versión final te llegará por SMS.',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textoSecundario,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        CampoTextoApp(
          etiqueta: 'Código de 6 números',
          controller: _codigo,
          teclado: TextInputType.number,
          soloDigitos: true,
          maxLongitud: 6,
          icono: Icons.pin_outlined,
          validator: (v) => RegExp(r'^\d{6}$').hasMatch(v?.trim() ?? '')
              ? null
              : 'Escribe los 6 números del código',
        ),
        const SizedBox(height: 12),
        CampoTextoApp(
          etiqueta: 'Nueva contraseña',
          controller: _password,
          esPassword: true,
          icono: Icons.lock_outline,
          autofillHints: const [AutofillHints.newPassword],
          validator: Validadores.password,
        ),
        const SizedBox(height: 8),
        RequisitosPassword(controller: _password),
        const SizedBox(height: 12),
        CampoTextoApp(
          etiqueta: 'Repite la contraseña',
          controller: _confirmacion,
          esPassword: true,
          icono: Icons.lock_outline,
          accion: TextInputAction.done,
          onSubmitted: (_) => _cambiar(),
          validator: (v) => Validadores.confirmacion(v, _password.text),
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          MensajeError(_error!),
          const SizedBox(height: 16),
        ],
        BotonPrincipal(
          texto: 'Cambiar contraseña',
          cargando: _cargando,
          onPressed: _cambiar,
        ),
        const SizedBox(height: 8),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: _cargando ? null : _volverAlPaso1,
          child: const Text(
            'Pedir otro código',
            style: TextStyle(fontSize: 16, color: AppColors.azul),
          ),
        ),
      ],
    ),
  );
}

class _Paso extends StatelessWidget {
  const _Paso(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      texto,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textoSecundario,
      ),
    ),
  );
}
