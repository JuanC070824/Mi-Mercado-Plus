import 'package:flutter/material.dart';
import '../../../core/state/preferencias_vendedor_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../data/models/usuario.dart';
import '../../../data/repositories/auth_api_repository.dart';

class PreferenciasVendedor extends StatefulWidget {
  const PreferenciasVendedor({
    super.key,
    required this.usuario,
    this.onActualizado,
    this.repository,
  });
  final Usuario usuario;
  final ValueChanged<Usuario>? onActualizado;
  final AuthApiRepository? repository;
  @override
  State<PreferenciasVendedor> createState() => _PreferenciasVendedorState();
}

class _PreferenciasVendedorState extends State<PreferenciasVendedor> {
  late Usuario _usuario;
  bool _cargando = true;
  bool _cargadas = false;
  bool _guardando = false;
  String? _error;
  AuthApiRepository get _repo =>
      widget.repository ?? AuthApiRepository.instancia;
  @override
  void initState() {
    super.initState();
    _usuario = PreferenciasVendedorState.de(widget.usuario);
    PreferenciasVendedorState.cambios.addListener(_sincronizar);
    _cargar();
  }

  void _sincronizar() {
    if (mounted && _cargadas) {
      setState(() => _usuario = PreferenciasVendedorState.de(widget.usuario));
    }
  }

  @override
  void dispose() {
    PreferenciasVendedorState.cambios.removeListener(_sincronizar);
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final usuario = await _repo.preferenciasVendedor(_usuario);
      if (!mounted) return;
      _aplicar(usuario);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No pudimos cargar tus preferencias.');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _aplicar(Usuario u) {
    setState(() {
      _usuario = u;
      _cargadas = true;
    });
    PreferenciasVendedorState.aplicar(u);
    widget.onActualizado?.call(u);
  }

  Future<void> _guardar(Usuario nuevo) async {
    if (_guardando || _cargando) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final usuario = await _repo.preferenciasVendedor(nuevo, guardar: true);
      if (!mounted) return;
      _aplicar(usuario);
      avisar(context, 'Preferencias guardadas en tu cuenta.');
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No pudimos guardar el cambio. Se conserva tu configuración anterior.',
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => TarjetaApp(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Cómo te avisamos y cómo lees',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Los cambios se guardan en tu cuenta. El sonido y la vibración dependen de tu dispositivo y sus permisos.',
          style: TextStyle(fontSize: 16),
        ),
        if (_cargando)
          const Padding(
            padding: EdgeInsets.all(12),
            child: LinearProgressIndicator(
              semanticsLabel: 'Cargando preferencias',
            ),
          ),
        _opcion(
          'Letra grande',
          'Amplía la letra sin reducir el tamaño elegido en tu dispositivo.',
          Icons.format_size,
          _usuario.letraGrande,
          (v) => _guardar(_usuario.copyWith(letraGrande: v)),
        ),
        _opcion(
          'Sonido de pedidos',
          'Aviso sonoro al abrir un pedido nuevo.',
          Icons.volume_up_outlined,
          _usuario.sonido,
          (v) => _guardar(_usuario.copyWith(sonido: v)),
        ),
        _opcion(
          'Vibración de pedidos',
          'Aviso con vibración cuando el dispositivo lo permita.',
          Icons.vibration,
          _usuario.vibracion,
          (v) => _guardar(_usuario.copyWith(vibracion: v)),
        ),
        if (_guardando)
          Semantics(
            liveRegion: true,
            child: const Text(
              'Guardando preferencias…',
              style: TextStyle(fontSize: 18),
            ),
          ),
        if (_error != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: const TextStyle(fontSize: 17, color: AppColors.error),
            ),
          ),
          if (!_guardando)
            TextButton(
              onPressed: _cargar,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text('Volver a cargar preferencias'),
            ),
        ],
      ],
    ),
  );
  Widget _opcion(
    String titulo,
    String detalle,
    IconData icono,
    bool valor,
    ValueChanged<bool> cambiar,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: AppColors.azul),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                titulo,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              label: titulo,
              child: Switch(
                value: valor,
                onChanged: _cargando || _guardando || !_cargadas
                    ? null
                    : cambiar,
              ),
            ),
          ],
        ),
        Text(
          detalle,
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.textoSecundario,
          ),
        ),
      ],
    ),
  );
}
