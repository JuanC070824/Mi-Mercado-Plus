import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ubicacion_service.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/botones_app.dart';
import '../../../core/widgets/campo_texto_app.dart';
import '../../../core/widgets/encabezado_azul.dart';
import '../../../core/widgets/mensaje_error.dart';
import '../../../data/models/direccion.dart';
import '../../../data/models/rol.dart';
import '../../../data/models/usuario.dart';
import '../../../data/repositories/auth_api_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/dni_repository.dart';
import '../widgets/requisitos_password.dart';

enum _EstadoDni { inicial, buscando, encontrado, noEncontrado, falloServicio }

enum _EstadoUbicacion { inicial, buscando, listo, error }

class ClienteRegistroScreen extends StatefulWidget {
  const ClienteRegistroScreen({super.key, this.rol = Rol.cliente});

  final Rol rol;

  static const inicioPorRol = {
    Rol.cliente: '/inicio',
    Rol.comerciante: '/casero/inicio',
    Rol.repartidor: '/repartidor/inicio',
  };

  @override
  State<ClienteRegistroScreen> createState() => _ClienteRegistroScreenState();
}

class _ClienteRegistroScreenState extends State<ClienteRegistroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dni = TextEditingController();
  final _nombres = TextEditingController();
  final _paterno = TextEditingController();
  final _materno = TextEditingController();
  final _nacimiento = TextEditingController();
  final _celular = TextEditingController();
  final _correo = TextEditingController();
  final _password = TextEditingController();
  final _confirmar = TextEditingController();
  final _direccion = TextEditingController();
  final _referencia = TextEditingController();

  late final RegistroRepository _repo;
  late final DniRepository _dniRepo;

  // Consulta de DNI
  _EstadoDni _estadoDni = _EstadoDni.inicial;
  String? _dniConsultado;
  String? _dniToken;
  int _consultaId = 0;

  // Ubicación
  _EstadoUbicacion _estadoUbicacion = _EstadoUbicacion.inicial;
  String? _mensajeUbicacion;
  double? _latitud;
  double? _longitud;

  // Preferencias (valores por defecto = los de la tabla usuarios)
  bool _letraGrande = false;
  bool _sonido = true;
  bool _vibracion = true;

  bool _cargando = false;
  String? _error;

  /// La identidad siempre proviene de JSON.pe; no se edita manualmente.
  bool get _bloqueado => true;

  @override
  void initState() {
    super.initState();
    _repo = AuthApiRepository.instancia;
    _dniRepo = DniApiRepository.instancia;
    _dni.addListener(_alCambiarDni);
  }

  @override
  void dispose() {
    _dni.removeListener(_alCambiarDni);
    for (final c in [
      _dni,
      _nombres,
      _paterno,
      _materno,
      _nacimiento,
      _celular,
      _correo,
      _password,
      _confirmar,
      _direccion,
      _referencia,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------- DNI ----------

  void _alCambiarDni() {
    final dni = _dni.text;
    if (dni.length == 8) {
      if (dni != _dniConsultado) _consultarDni(dni);
    } else if (_dniConsultado != null || _estadoDni != _EstadoDni.inicial) {
      _reiniciarDni();
    }
  }

  void _reiniciarDni() {
    _consultaId++; // descarta cualquier consulta en curso
    setState(() {
      _nombres.clear();
      _paterno.clear();
      _materno.clear();
      _dniConsultado = null;
      _dniToken = null;
      _estadoDni = _EstadoDni.inicial;
    });
  }

  Future<void> _consultarDni(String dni) async {
    final id = ++_consultaId;
    setState(() {
      _dniConsultado = dni;
      _estadoDni = _EstadoDni.buscando;
      _nombres.clear();
      _paterno.clear();
      _materno.clear();
    });

    final r = await _dniRepo.consultar(dni);
    if (!mounted || id != _consultaId) return; // el usuario ya cambió el DNI

    setState(() {
      switch (r.estado) {
        case EstadoConsulta.encontrado:
          final d = r.datos!;
          _nombres.text = d.nombres;
          _paterno.text = d.apellidoPaterno;
          _materno.text = d.apellidoMaterno;
          _dniToken = d.registroToken;
          _estadoDni = _EstadoDni.encontrado;
        case EstadoConsulta.noEncontrado:
          _dniToken = null;
          _estadoDni = _EstadoDni.noEncontrado;
        case EstadoConsulta.falloServicio:
          _dniToken = null;
          _estadoDni = _EstadoDni.falloServicio;
      }
    });
  }

  String? _validarDni(String? v) {
    final base = Validadores.dni(v);
    if (base != null) return base;
    if (_estadoDni == _EstadoDni.noEncontrado) {
      return 'No encontramos este DNI. Revisa los 8 números.';
    }
    if (_estadoDni != _EstadoDni.encontrado || _dniToken == null) {
      return 'Es necesario validar el DNI antes de crear la cuenta.';
    }
    return null;
  }

  String? _validarNombre(String? v, String campo, {bool opcional = false}) {
    final vacio = (v ?? '').trim().isEmpty;
    if (vacio && _bloqueado) {
      return opcional ? null : 'Se completa solo al escribir tu DNI';
    }
    return Validadores.nombre(v, campo: campo, opcional: opcional);
  }

  // ---------- Ubicación ----------

  Future<void> _usarUbicacion() async {
    setState(() {
      _estadoUbicacion = _EstadoUbicacion.buscando;
      _mensajeUbicacion = null;
    });
    try {
      final u = await UbicacionService.obtener();
      if (!mounted) return;
      setState(() {
        _latitud = u.latitud;
        _longitud = u.longitud;
        if (u.direccion != null) _direccion.text = u.direccion!;
        _estadoUbicacion = _EstadoUbicacion.listo;
        _mensajeUbicacion = u.direccion != null
            ? 'Encontramos tu ubicación. Revisa la dirección y corrígela si hace falta.'
            : 'Guardamos tu ubicación, pero no pudimos obtener la calle. Escríbela tú.';
      });
    } on UbicacionException catch (e) {
      if (!mounted) return;
      setState(() {
        _estadoUbicacion = _EstadoUbicacion.error;
        _mensajeUbicacion = e.mensaje;
      });
    }
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final actual = Validadores.parseFecha(_nacimiento.text);
    final f = await showDatePicker(
      context: context,
      initialDate: actual ?? DateTime(hoy.year - 30, hoy.month, hoy.day),
      firstDate: DateTime(1900),
      lastDate: hoy,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Elige tu fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (f == null) return;
    _nacimiento.text =
        '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
  }
  // ---------- Envío ----------

  String? _vacioANulo(String s) => s.trim().isEmpty ? null : s.trim();

  /// Lleva la pantalla al primer campo con error (WCAG 3.3.1).
  void _irAlPrimerError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FormFieldState<dynamic>? primero;
      void visitar(Element el) {
        if (primero != null) return;
        if (el is StatefulElement) {
          final s = el.state;
          if (s is FormFieldState && s.hasError) {
            primero = s;
            return;
          }
        }
        el.visitChildren(visitar);
      }

      (_formKey.currentContext as Element?)?.visitChildren(visitar);
      final ctx = primero?.context;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          alignment: 0.2,
        );
      }
    });
  }

  Future<void> _registrar() async {
    setState(() => _error = null);

    if (_estadoDni == _EstadoDni.buscando) {
      setState(
        () => _error =
            'Espera un momento: estamos buscando tus datos con tu DNI.',
      );
      return;
    }
    if (!_formKey.currentState!.validate()) {
      setState(
        () => _error = 'Revisa los campos marcados en rojo para continuar.',
      );
      _irAlPrimerError();
      return;
    }

    setState(() => _cargando = true);
    final dir = _direccion.text.trim();
    final r = await _repo.registrarUsuario(
      dni: _dni.text,
      dniToken: _dniToken!,
      usuario: Usuario(
        nombres: _nombres.text.trim(),
        apellidoPaterno: _paterno.text.trim(),
        apellidoMaterno: _vacioANulo(_materno.text),
        celular: _celular.text.trim(),
        correo: _vacioANulo(_correo.text),
        fechaNacimiento: Validadores.parseFecha(_nacimiento.text.trim()),
        letraGrande: _letraGrande,
        sonido: _sonido,
        vibracion: _vibracion,
        rol: widget.rol,
      ),
      password: _password.text,
      direccion: widget.rol != Rol.cliente || dir.isEmpty
          ? null
          : Direccion(
              direccion: dir,
              referencia: _vacioANulo(_referencia.text),
              latitud: _latitud,
              longitud: _longitud,
            ),
    );
    if (!mounted) return;
    setState(() => _cargando = false);

    if (r.exito) {
      context.go(
        ClienteRegistroScreen.inicioPorRol[widget.rol]!,
        extra: r.usuario,
      );
    } else {
      setState(() => _error = r.mensaje);
    }
  }

  // ---------- Interfaz ----------

  Widget _estadoDniWidget() {
    switch (_estadoDni) {
      case _EstadoDni.inicial:
        return const SizedBox.shrink();
      case _EstadoDni.buscando:
        return const _MensajeEstado(
          texto: 'Buscando tus datos…',
          color: AppColors.azul,
          cargando: true,
        );
      case _EstadoDni.encontrado:
        return const _MensajeEstado(
          texto: 'Datos encontrados. Verifica que sean los tuyos.',
          color: AppColors.exito,
          icono: Icons.check_circle,
        );
      case _EstadoDni.noEncontrado:
        return const _MensajeEstado(
          texto: 'No encontramos este DNI. Revisa los 8 números.',
          color: AppColors.error,
          icono: Icons.error_outline,
        );
      case _EstadoDni.falloServicio:
        return _MensajeEstado(
          texto: 'No pudimos consultar tu DNI ahora. Reintenta para continuar.',
          color: AppColors.texto,
          icono: Icons.info_outline,
          accion: TextButton(
            onPressed: () {
              final d = _dni.text;
              _dniConsultado = null;
              _consultarDni(d);
            },
            child: const Text(
              'Reintentar',
              style: TextStyle(fontSize: 18, color: AppColors.azul),
            ),
          ),
        );
    }
  }

  Widget _botonUbicacion() {
    final buscando = _estadoUbicacion == _EstadoUbicacion.buscando;
    return SizedBox(
      height: 56,
      child: OutlinedButton.icon(
        onPressed: buscando ? null : _usarUbicacion,
        icon: buscando
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.azul,
                  semanticsLabel: 'Buscando ubicación',
                ),
              )
            : const Icon(Icons.my_location),
        label: Text(
          buscando ? 'Buscando tu ubicación…' : 'Usar mi ubicación actual',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.azul,
          disabledForegroundColor: AppColors.azul,
          side: const BorderSide(color: AppColors.azul, width: 2),
          shape: const StadiumBorder(),
        ),
      ),
    );
  }

  Widget _estadoUbicacionWidget() {
    if (_mensajeUbicacion == null) return const SizedBox.shrink();
    final ok = _estadoUbicacion == _EstadoUbicacion.listo;
    return _MensajeEstado(
      texto: _mensajeUbicacion!,
      color: ok ? AppColors.exito : AppColors.error,
      icono: ok ? Icons.check_circle : Icons.error_outline,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          EncabezadoAzul(titulo: 'Registro de ${widget.rol.etiqueta}'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Los campos que no dicen "opcional" son obligatorios.',
                            style: TextStyle(
                              fontSize: 17,
                              color: AppColors.textoSecundario,
                            ),
                          ),
                          const SizedBox(height: 20),

                          const _TituloSeccion(
                            'Mis datos',
                            Icons.badge_outlined,
                          ),
                          const SizedBox(height: 16),
                          CampoTextoApp(
                            etiqueta: 'DNI',
                            hint: '8 dígitos',
                            controller: _dni,
                            teclado: TextInputType.number,
                            soloDigitos: true,
                            maxLongitud: 8,
                            mostrarContador: true,
                            icono: Icons.credit_card,
                            validator: _validarDni,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: _estadoDniWidget(),
                          ),
                          const SizedBox(height: 12),
                          CampoTextoApp(
                            etiqueta: 'Nombres',
                            hint: 'Se completa con tu DNI',
                            controller: _nombres,
                            soloLectura: _bloqueado,
                            mayusculas: TextCapitalization.words,
                            validator: (v) => _validarNombre(v, 'El nombre'),
                          ),
                          const SizedBox(height: 12),
                          CampoTextoApp(
                            etiqueta: 'Apellido paterno',
                            hint: 'Se completa con tu DNI',
                            controller: _paterno,
                            soloLectura: _bloqueado,
                            mayusculas: TextCapitalization.words,
                            validator: (v) =>
                                _validarNombre(v, 'El apellido paterno'),
                          ),
                          const SizedBox(height: 12),
                          CampoTextoApp(
                            etiqueta: 'Apellido materno',
                            hint: 'Se completa con tu DNI',
                            controller: _materno,
                            soloLectura: _bloqueado,
                            mayusculas: TextCapitalization.words,
                            validator: (v) => _validarNombre(
                              v,
                              'El apellido materno',
                              opcional: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          CampoTextoApp(
                            etiqueta: 'Fecha de nacimiento (opcional)',
                            hint: 'Toca para elegir la fecha',
                            controller: _nacimiento,
                            icono: Icons.cake_outlined,
                            onTap: _elegirFecha,
                            validator: Validadores.fechaNacimiento,
                          ),

                          const SizedBox(height: 28),
                          const _TituloSeccion('Mi acceso', Icons.lock_outline),
                          const SizedBox(height: 16),
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
                            etiqueta: 'Correo (opcional)',
                            hint: 'nombre@correo.com',
                            controller: _correo,
                            teclado: TextInputType.emailAddress,
                            maxLongitud: 254,
                            icono: Icons.mail_outline,
                            autofillHints: const [AutofillHints.email],
                            validator: Validadores.correo,
                          ),
                          const SizedBox(height: 12),
                          CampoTextoApp(
                            etiqueta: 'Contraseña',
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
                            etiqueta: 'Repite tu contraseña',
                            controller: _confirmar,
                            esPassword: true,
                            icono: Icons.lock_outline,
                            validator: (v) =>
                                Validadores.confirmacion(v, _password.text),
                          ),

                          if (widget.rol == Rol.cliente) ...[
                            const SizedBox(height: 28),
                            const _TituloSeccion(
                              'Dónde te entregamos (opcional)',
                              Icons.home_outlined,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Puedes completarlo ahora o más tarde, desde Mi perfil.',
                              style: TextStyle(
                                fontSize: 17,
                                color: AppColors.textoSecundario,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _botonUbicacion(),
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _estadoUbicacionWidget(),
                            ),
                            const SizedBox(height: 16),
                            CampoTextoApp(
                              etiqueta: 'Dirección principal',
                              hint: 'Av. Principal 123, Surquillo',
                              controller: _direccion,
                              icono: Icons.home_outlined,
                              autofillHints: const [
                                AutofillHints.fullStreetAddress,
                              ],
                              validator: Validadores.direccionOpcional,
                            ),
                            const SizedBox(height: 12),
                            CampoTextoApp(
                              etiqueta: 'Referencia (opcional)',
                              hint: 'Cerca a la juguería',
                              controller: _referencia,
                              icono: Icons.edit_location_alt_outlined,
                              accion: TextInputAction.done,
                            ),
                          ],

                          const SizedBox(height: 28),
                          const _TituloSeccion(
                            'Cómo quiero usar la app',
                            Icons.tune,
                          ),
                          const SizedBox(height: 12),
                          _tarjetaPreferencias(),

                          const SizedBox(height: 24),
                          _casillaTerminos(),

                          const SizedBox(height: 16),
                          if (_error != null) ...[
                            MensajeError(_error!),
                            const SizedBox(height: 16),
                          ],
                          BotonPrincipal(
                            texto: 'Crear mi cuenta',
                            cargando: _cargando,
                            onPressed: _registrar,
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => context.canPop()
                                ? context.pop()
                                : context.go(
                                    widget.rol == Rol.cliente
                                        ? '/cliente/login'
                                        : widget.rol == Rol.comerciante
                                        ? '/casero/login'
                                        : '/repartidor/login',
                                  ),
                            child: const Text(
                              '¿Ya tienes cuenta? Iniciar sesión',
                              style: TextStyle(
                                fontSize: 18,
                                color: AppColors.azul,
                              ),
                            ),
                          ),
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

  Widget _tarjetaPreferencias() {
    const titulo = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: AppColors.texto,
    );
    const detalle = TextStyle(fontSize: 17, color: AppColors.textoSecundario);

    return Material(
      color: AppColors.blanco,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.azul, width: 1.5),
      ),
      child: Column(
        children: [
          SwitchListTile(
            value: _letraGrande,
            onChanged: (v) => setState(() => _letraGrande = v),
            title: const Text('Letra grande', style: titulo),
            subtitle: const Text('Textos más fáciles de leer', style: detalle),
          ),
          const Divider(height: 1),
          SwitchListTile(
            value: _sonido,
            onChanged: (v) => setState(() => _sonido = v),
            title: const Text('Sonido', style: titulo),
            subtitle: const Text('Avisos con sonido', style: detalle),
          ),
          const Divider(height: 1),
          SwitchListTile(
            value: _vibracion,
            onChanged: (v) => setState(() => _vibracion = v),
            title: const Text('Vibración', style: titulo),
            subtitle: const Text('Avisos con vibración', style: detalle),
          ),
        ],
      ),
    );
  }

  Widget _casillaTerminos() {
    return FormField<bool>(
      initialValue: false,
      validator: (v) =>
          (v ?? false) ? null : 'Debes aceptar para poder crear tu cuenta',
      builder: (campo) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              value: campo.value ?? false,
              onChanged: (v) => campo.didChange(v),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              side: const BorderSide(color: AppColors.azul, width: 2),
              title: const Text(
                'Acepto los términos de uso y el tratamiento de mis datos personales.',
                style: TextStyle(fontSize: 18, color: AppColors.texto),
              ),
            ),
            if (campo.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 2),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 20,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        campo.errorText!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion(this.texto, this.icono);
  final String texto;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Row(
        children: [
          Icon(icono, color: AppColors.azul, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                color: AppColors.azul,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mensaje de estado con ícono + texto (nunca solo color) que los lectores
/// de pantalla anuncian al aparecer.
class _MensajeEstado extends StatelessWidget {
  const _MensajeEstado({
    required this.texto,
    required this.color,
    this.icono,
    this.cargando = false,
    this.accion,
  });

  final String texto;
  final Color color;
  final IconData? icono;
  final bool cargando;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cargando)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: color,
                    semanticsLabel: 'Cargando',
                  ),
                )
              else
                Icon(icono, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  texto,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          ?accion,
        ],
      ),
    );
  }
}
