import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/api_config.dart';
import '../../../core/state/accesibilidad_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ubicacion_service.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/botones_app.dart';
import '../../../core/widgets/soporte_dialog.dart';
import '../../../core/widgets/campo_texto_app.dart';
import '../../../core/widgets/mensaje_error.dart';
import '../../../data/models/direccion.dart';
import '../../../data/models/usuario.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/auth_api_repository.dart';

enum _EstadoUbicacion { inicial, buscando, listo, error }

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({
    super.key,
    required this.usuario,
    required this.onUsuarioActualizado,
    required this.onSesionCerrada,
    this.mostrarDireccion = true,
    this.mostrarAtras = false,
  });

  final Usuario usuario;

  /// Se llama al guardar cambios (el router actualiza al usuario de la sesión).
  final ValueChanged<Usuario> onUsuarioActualizado;

  /// Se llama al confirmar "Cerrar sesión" (el router olvida al usuario).
  final VoidCallback onSesionCerrada;
  final bool mostrarDireccion;
  final bool mostrarAtras;

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  late final AuthRepository _repo;
  final _formKey = GlobalKey<FormState>();

  // Solo lectura
  late final TextEditingController _ctrlNombres;
  late final TextEditingController _ctrlPaterno;
  late final TextEditingController _ctrlMaterno;

  // Editables
  late final TextEditingController _ctrlCelular;
  late final TextEditingController _ctrlCorreo;
  final _ctrlDireccion = TextEditingController();
  final _ctrlReferencia = TextEditingController();

  // Últimos valores guardados (para saber si hay cambios sin guardar)
  late String _gCelular;
  late String _gCorreo;
  String _gDireccion = '';
  String _gReferencia = '';

  // Dirección
  String _etiqueta = 'Casa';
  bool _cargandoDir = true;
  double? _latitud;
  double? _longitud;
  String _textoConCoordenadas = ''; // texto al que pertenecen las coordenadas
  _EstadoUbicacion _estadoUbicacion = _EstadoUbicacion.inicial;
  String? _mensajeUbicacion;

  bool _guardando = false;
  String? _errorGuardar;

  late bool _sonido;
  late bool _vibracion;

  @override
  void initState() {
    super.initState();
    _repo = ApiConfig.configurada
        ? AuthApiRepository.instancia
        : AuthRepositoryMock.instancia;
    final u = widget.usuario;
    _ctrlNombres = TextEditingController(text: u.nombres);
    _ctrlPaterno = TextEditingController(text: u.apellidoPaterno ?? '');
    _ctrlMaterno = TextEditingController(text: u.apellidoMaterno ?? '');
    _ctrlCelular = TextEditingController(text: u.celular);
    _ctrlCorreo = TextEditingController(text: u.correo ?? '');
    _gCelular = u.celular;
    _gCorreo = u.correo ?? '';
    _sonido = u.sonido;
    _vibracion = u.vibracion;
    if (widget.mostrarDireccion) {
      _cargarDireccion();
    } else {
      _cargandoDir = false;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _ctrlNombres,
      _ctrlPaterno,
      _ctrlMaterno,
      _ctrlCelular,
      _ctrlCorreo,
      _ctrlDireccion,
      _ctrlReferencia,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------- Datos ----------

  Future<void> _cargarDireccion() async {
    final d = await _repo.direccionPrincipal(_gCelular);
    if (!mounted) return;
    setState(() {
      _cargandoDir = false;
      if (d != null) {
        _etiqueta = d.etiqueta;
        _latitud = d.latitud;
        _longitud = d.longitud;
        _gDireccion = d.direccion;
        _gReferencia = d.referencia ?? '';
        _textoConCoordenadas = d.direccion;
        _ctrlDireccion.text = d.direccion;
        _ctrlReferencia.text = _gReferencia;
      }
    });
  }

  bool get _hayCambios =>
      _ctrlCelular.text.trim() != _gCelular ||
      _ctrlCorreo.text.trim() != _gCorreo ||
      (widget.mostrarDireccion &&
          (_ctrlDireccion.text.trim() != _gDireccion ||
              _ctrlReferencia.text.trim() != _gReferencia));

  String? _vacioANulo(String s) => s.trim().isEmpty ? null : s.trim();

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto, style: const TextStyle(fontSize: 18))),
    );
  }

  String? _validarDireccion(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) {
      return _gDireccion.isNotEmpty
          ? 'La dirección no puede quedar vacía. Escribe otra o usa tu ubicación.'
          : null;
    }
    return Validadores.direccionOpcional(t);
  }

  String? _validarReferencia(String? v) {
    if ((v ?? '').trim().isNotEmpty && _ctrlDireccion.text.trim().isEmpty) {
      return 'Primero escribe tu dirección.';
    }
    return null;
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
        if (u.direccion != null) _ctrlDireccion.text = u.direccion!;
        _textoConCoordenadas = _ctrlDireccion.text.trim();
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

  // ---------- Guardar cambios ----------

  Future<void> _guardarCambios() async {
    setState(() => _errorGuardar = null);
    if (!_formKey.currentState!.validate()) {
      setState(
        () => _errorGuardar =
            'Revisa los campos marcados en rojo para continuar.',
      );
      return;
    }

    final cambiaCelular = _ctrlCelular.text.trim() != _gCelular;
    final passwordActual = cambiaCelular ? await _pedirPasswordActual() : null;
    if (cambiaCelular && passwordActual == null) return;

    final texto = widget.mostrarDireccion ? _ctrlDireccion.text.trim() : '';
    // Si el usuario cambió la dirección a mano, las coordenadas ya no valen.
    final coordenadasVigentes = texto == _textoConCoordenadas;
    final Direccion? nueva = !widget.mostrarDireccion || texto.isEmpty
        ? null
        : Direccion(
            etiqueta: _etiqueta,
            direccion: texto,
            referencia: _vacioANulo(_ctrlReferencia.text),
            latitud: coordenadasVigentes ? _latitud : null,
            longitud: coordenadasVigentes ? _longitud : null,
          );

    setState(() => _guardando = true);
    try {
      final r = await _repo.actualizarPerfil(
        celularActual: _gCelular,
        celular: _ctrlCelular.text.trim(),
        correo: _vacioANulo(_ctrlCorreo.text),
        direccion: nueva,
        passwordActual: passwordActual,
      );
      if (!mounted) return;
      if (!r.exito) {
        setState(() {
          _guardando = false;
          _errorGuardar = r.mensaje;
        });
        return;
      }
      final u = r.usuario!;
      widget.onUsuarioActualizado(u);
      FocusScope.of(context).unfocus();
      setState(() {
        _guardando = false;
        _gCelular = u.celular;
        _gCorreo = u.correo ?? '';
        _gDireccion = texto;
        _gReferencia = _ctrlReferencia.text.trim();
        _ctrlCelular.text = _gCelular;
        _ctrlCorreo.text = _gCorreo;
        _ctrlDireccion.text = texto;
        _ctrlReferencia.text = _gReferencia;
        if (!coordenadasVigentes) {
          _latitud = null;
          _longitud = null;
        }
        _textoConCoordenadas = texto;
        _estadoUbicacion = _EstadoUbicacion.inicial;
        _mensajeUbicacion = null;
      });
      _aviso('Cambios guardados.');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _errorGuardar = 'No pudimos guardar tus cambios. Inténtalo de nuevo.';
      });
    }
  }

  Future<String?> _pedirPasswordActual() async {
    final controller = TextEditingController();
    String? error;
    final resultado = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Confirma el cambio de celular'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Usarás el nuevo número para iniciar sesión. Escribe tu contraseña actual para continuar.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña actual',
                  errorText: error,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  if (controller.text.isEmpty) {
                    setDialogState(
                      () => error = 'Escribe tu contraseña actual.',
                    );
                  } else {
                    Navigator.of(dialogContext).pop(controller.text);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.isEmpty) {
                  setDialogState(() => error = 'Escribe tu contraseña actual.');
                } else {
                  Navigator.of(dialogContext).pop(controller.text);
                }
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return resultado;
  }

  Future<void> _guardarPreferencias() async {
    try {
      await _repo.guardarPreferencias(
        celular: _gCelular,
        sonido: _sonido,
        vibracion: _vibracion,
      );
    } catch (_) {
      if (!mounted) return;
      _aviso('No pudimos guardar tus preferencias.');
    }
  }

  void _cambiarSonido(bool v) {
    setState(() => _sonido = v);
    _guardarPreferencias();
  }

  void _cambiarVibracion(bool v) {
    setState(() => _vibracion = v);
    _guardarPreferencias();
  }

  // ---------- Cerrar sesión (con confirmación) ----------

  Future<void> _confirmarCierre() async {
    final confirmo = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.fondo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text(
          '¿Seguro que quieres cerrar sesión?',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.texto,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Saldrás de tu cuenta y tendrás que ingresar de nuevo con tu '
              'celular y tu contraseña.',
              style: TextStyle(fontSize: 18, color: AppColors.texto),
            ),
            const SizedBox(height: 20),
            BotonSecundario(
              texto: 'Cancelar',
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: AppColors.blanco,
                  shape: const StadiumBorder(),
                ),
                child: const Text(
                  'Sí, cerrar sesión',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmo != true || !mounted) return;
    AccesibilidadState.letraGrande.value =
        false; // la letra grande es de la sesión
    widget.onSesionCerrada();
    context.go('/');
  }

  // ---------- Interfaz ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _EncabezadoPerfil(
            onSoporte: () => mostrarSoporte(context),
            mostrarAtras: widget.mostrarAtras,
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _seccionInformacion(),
                              const SizedBox(height: 28),
                              if (widget.mostrarDireccion) _seccionDireccion(),
                              _zonaGuardar(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        _seccionPreferencias(),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton(
                            onPressed: _confirmarCierre,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(
                                color: AppColors.error,
                                width: 2,
                              ),
                              shape: const StadiumBorder(),
                            ),
                            child: const Text(
                              'Cerrar sesión',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
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
        ],
      ),
    );
  }

  Widget _seccionInformacion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TituloSeccion('Mi información', Icons.badge_outlined),
        const SizedBox(height: 4),
        const Text(
          'Tu nombre es el que viene en tu DNI. Si hay un error, escribe a Soporte.',
          style: TextStyle(fontSize: 17, color: AppColors.textoSecundario),
        ),
        const SizedBox(height: 14),
        CampoTextoApp(
          etiqueta: 'Nombres',
          controller: _ctrlNombres,
          soloLectura: true,
        ),
        const SizedBox(height: 14),
        CampoTextoApp(
          etiqueta: 'Apellido paterno',
          controller: _ctrlPaterno,
          hint: 'No registrado',
          soloLectura: true,
        ),
        const SizedBox(height: 14),
        CampoTextoApp(
          etiqueta: 'Apellido materno',
          controller: _ctrlMaterno,
          hint: 'No registrado',
          soloLectura: true,
        ),
        const SizedBox(height: 14),
        CampoTextoApp(
          etiqueta: 'Celular',
          hint: '9 dígitos',
          prefijo: '+51 ',
          controller: _ctrlCelular,
          teclado: TextInputType.phone,
          soloDigitos: true,
          maxLongitud: 9,
          mostrarContador: true,
          icono: Icons.phone_android,
          validator: Validadores.celular,
        ),
        const SizedBox(height: 14),
        CampoTextoApp(
          etiqueta: 'Correo (opcional)',
          hint: 'nombre@correo.com',
          controller: _ctrlCorreo,
          teclado: TextInputType.emailAddress,
          maxLongitud: 254,
          icono: Icons.mail_outline,
          validator: Validadores.correo,
        ),
      ],
    );
  }

  Widget _seccionDireccion() {
    final Widget contenido;
    if (_cargandoDir) {
      contenido = const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(
            semanticsLabel: 'Cargando dirección',
          ),
        ),
      );
    } else {
      contenido = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _EtiquetaDireccion(_etiqueta),
          ),
          const SizedBox(height: 12),
          _botonUbicacion(),
          if (_mensajeUbicacion != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _MensajeEstado(
                texto: _mensajeUbicacion!,
                ok: _estadoUbicacion == _EstadoUbicacion.listo,
              ),
            ),
          const SizedBox(height: 14),
          CampoTextoApp(
            etiqueta: 'Dirección principal',
            hint: 'Av. Principal 123, Surquillo',
            controller: _ctrlDireccion,
            icono: Icons.home_outlined,
            validator: _validarDireccion,
          ),
          const SizedBox(height: 14),
          CampoTextoApp(
            etiqueta: 'Referencia (opcional)',
            hint: 'Ej.: portón verde, cerca a la juguería',
            controller: _ctrlReferencia,
            maxLongitud: 120,
            mostrarContador: true,
            icono: Icons.edit_location_alt_outlined,
            accion: TextInputAction.done,
            validator: _validarReferencia,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TituloSeccion('Dirección', Icons.home_outlined),
        const SizedBox(height: 12),
        contenido,
      ],
    );
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

  /// El botón aparece solo cuando hay cambios sin guardar.
  Widget _zonaGuardar() {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _ctrlCelular,
        _ctrlCorreo,
        _ctrlDireccion,
        _ctrlReferencia,
      ]),
      builder: (context, _) {
        if (!_hayCambios) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorGuardar != null) ...[
                MensajeError(_errorGuardar!),
                const SizedBox(height: 12),
              ],
              BotonPrincipal(
                texto: 'Guardar cambios',
                cargando: _guardando,
                onPressed: _guardarCambios,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _seccionPreferencias() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TituloSeccion('Preferencias', Icons.tune),
        const SizedBox(height: 12),
        ValueListenableBuilder<bool>(
          valueListenable: AccesibilidadState.letraGrande,
          builder: (context, grande, _) => _FilaPreferencia(
            titulo: 'Letra grande',
            icono: Icons.format_size,
            valor: grande,
            onChanged: (_) => AccesibilidadState.alternarLetra(),
          ),
        ),
        const SizedBox(height: 12),
        _FilaPreferencia(
          titulo: 'Sonido',
          icono: Icons.volume_up_outlined,
          valor: _sonido,
          onChanged: _cambiarSonido,
        ),
        const SizedBox(height: 12),
        _FilaPreferencia(
          titulo: 'Vibración',
          icono: Icons.vibration,
          valor: _vibracion,
          onChanged: _cambiarVibracion,
        ),
      ],
    );
  }
}

/// Franja azul con el ícono de perfil, igual que EncabezadoAzul pero sin flecha
/// (el perfil es una pestaña del menú inferior).
class _EncabezadoPerfil extends StatelessWidget {
  const _EncabezadoPerfil({
    required this.onSoporte,
    required this.mostrarAtras,
  });

  final VoidCallback onSoporte;
  final bool mostrarAtras;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.azul,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
          child: Column(
            children: [
              Row(
                children: [
                  if (mostrarAtras)
                    IconButton(
                      tooltip: 'Volver a Mi puesto',
                      onPressed: () => context.pop(),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppColors.blanco,
                      ),
                    ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onSoporte,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(
                      Icons.headset_mic_outlined,
                      color: AppColors.blanco,
                    ),
                    label: const Text(
                      'Soporte',
                      style: TextStyle(
                        color: AppColors.blanco,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const CircleAvatar(
                radius: 60,
                backgroundColor: AppColors.fondo,
                child: Icon(
                  Icons.account_circle_outlined,
                  size: 96,
                  color: AppColors.azul,
                  semanticLabel: 'Ícono de perfil',
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                header: true,
                child: const Text(
                  'Mi Perfil',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.blanco,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion(this.texto, this.icono);

  final String texto;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Semantics(
            header: true,
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.azul,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icono, color: AppColors.azul, size: 28),
      ],
    );
  }
}

class _EtiquetaDireccion extends StatelessWidget {
  const _EtiquetaDireccion(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: const BoxDecoration(
        color: AppColors.azul,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          color: AppColors.blanco,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Mensaje con ícono + texto (nunca solo color) que el lector de pantalla anuncia.
class _MensajeEstado extends StatelessWidget {
  const _MensajeEstado({required this.texto, required this.ok});

  final String texto;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.exito : AppColors.error;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.error_outline,
            color: color,
            size: 24,
          ),
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
    );
  }
}

/// Fila con interruptor. Dice "Activada / Desactivada" con texto, no solo con color.
class _FilaPreferencia extends StatelessWidget {
  const _FilaPreferencia({
    required this.titulo,
    required this.icono,
    required this.valor,
    required this.onChanged,
  });

  final String titulo;
  final IconData icono;
  final bool valor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: valor,
      label: titulo,
      onTap: () => onChanged(!valor),
      excludeSemantics: true,
      child: Material(
        color: AppColors.blanco,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(
            color: valor ? AppColors.azul : AppColors.borde,
            width: valor ? 2 : 1.5,
          ),
        ),
        child: InkWell(
          onTap: () => onChanged(!valor),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 68),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(
                children: [
                  Icon(icono, color: AppColors.azul, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          titulo,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.texto,
                          ),
                        ),
                        Text(
                          valor ? 'Activada' : 'Desactivada',
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: valor,
                    onChanged: onChanged,
                    activeTrackColor: AppColors.azul,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
