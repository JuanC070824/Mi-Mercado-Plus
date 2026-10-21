import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/botones_app.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../core/widgets/encabezado_simple.dart';
import '../../../core/widgets/mensaje_error.dart';
import '../../../data/models/canasta.dart';
import '../../../data/models/direccion.dart';
import '../../../data/models/pedido.dart';
import '../../../data/models/usuario.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/auth_api_repository.dart';
import '../../../core/config/api_config.dart';
import '../../../data/repositories/repositorios_app.dart';
import '../../../data/repositories/pedido_repository.dart';
import '../widgets/acciones_canasta.dart';
import '../widgets/opcion_elegible.dart';
import '../widgets/pasos_compra.dart';

/// C4 · Entrega y pago (Paso 2 de 3).
class EntregaPagoScreen extends StatefulWidget {
  const EntregaPagoScreen({super.key, required this.usuario});
  final Usuario usuario;

  @override
  State<EntregaPagoScreen> createState() => _EntregaPagoScreenState();
}

class _EntregaPagoScreenState extends State<EntregaPagoScreen> {
  final AuthRepository _auth = ApiConfig.configurada
      ? AuthApiRepository.instancia
      : AuthRepositoryMock.instancia;

  Direccion? _direccion;
  bool _cargando = true;
  MetodoPago _metodo = MetodoPago.efectivo;
  bool _enviando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarDireccion();
  }

  Future<void> _cargarDireccion() async {
    final d = await _auth.direccionPrincipal(widget.usuario.celular);
    if (!mounted) return;
    setState(() {
      _direccion = d;
      _cargando = false;
    });
  }

  Future<void> _confirmar() async {
    final dir = _direccion;
    if (dir == null) return;
    if (_metodo == MetodoPago.yape && !ApiConfig.configurada) {
      context.push('/canasta/yape', extra: dir); // C4b: guía y pago con Yape
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final pedido = await enviarPedido(
        usuario: widget.usuario,
        direccion: dir,
        metodo: _metodo,
      );
      if (!mounted) return;
      context.go('/canasta/enviado', extra: pedido);
    } on PedidoException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const EncabezadoSimple(titulo: '¿Dónde y cómo te entregamos?'),
          Expanded(
            child: ValueListenableBuilder<Canasta>(
              valueListenable: canastaApp.canasta,
              builder: (context, canasta, _) {
                if (_cargando) return const CargandoApp();
                if (canasta.vacia) {
                  return AvisoPantalla(
                    icono: Icons.shopping_basket_outlined,
                    titulo: 'Tu canasta está vacía',
                    textoBoton: 'Ir al mercado',
                    alTocar: () => context.go('/inicio'),
                  );
                }
                return _contenido(canasta);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _contenido(Canasta c) {
    final dir = _direccion;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const PasosCompra(paso: 2),
        const SizedBox(height: 20),
        const TituloSeccion('Dirección'),
        const SizedBox(height: 8),
        TarjetaApp(
          child: Row(
            children: [
              const Icon(Icons.home_outlined, color: AppColors.azul, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: dir == null
                    ? const Text(
                        'Aún no tienes una dirección. Agrégala en tu perfil.',
                        style: TextStyle(fontSize: 18),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dir.direccion,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (dir.referencia != null)
                            Text(
                              'Referencia: ${dir.referencia}',
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.textoSecundario,
                              ),
                            ),
                        ],
                      ),
              ),
              TextButton(
                onPressed: () => context.go('/perfil'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: Text(
                  dir == null ? 'Agregar' : 'Cambiar',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const TituloSeccion('¿Cuándo?'),
        const SizedBox(height: 8),
        OpcionElegible(
          titulo: 'Lo antes posible',
          detalle: 'Llega en unos 40 minutos',
          icono: Icons.bolt,
          elegida: true,
          onTap: () {},
        ),
        const SizedBox(height: 8),
        const OpcionElegible(
          titulo: 'Programar para más tarde',
          detalle: 'Disponible muy pronto',
          icono: Icons.event_outlined,
          elegida: false,
          onTap: null,
        ),
        const SizedBox(height: 20),
        const TituloSeccion('¿Cómo pagas?'),
        const SizedBox(height: 8),
        for (final m in MetodoPago.values) ...[
          OpcionElegible(
            titulo: m.etiqueta,
            detalle: switch (m) {
              MetodoPago.efectivo => 'Pagas al repartidor cuando llegue',
              MetodoPago.yape => 'Te guiamos paso a paso',
              MetodoPago.plin => 'Pagas al repartidor con Plin cuando llegue',
            },
            icono: switch (m) {
              MetodoPago.efectivo => Icons.payments_outlined,
              MetodoPago.yape => Icons.qr_code_2,
              MetodoPago.plin => Icons.phone_android,
            },
            elegida: _metodo == m,
            onTap: () => setState(() => _metodo = m),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
        const TituloSeccion('Resumen'),
        const SizedBox(height: 8),
        TarjetaApp(
          child: Column(
            children: [
              for (final g in c.grupos)
                FilaMonto(etiqueta: g.puesto.nombre, monto: g.subtotal),
              FilaMonto(etiqueta: 'Envío', monto: c.envio),
              const Divider(color: AppColors.divisor),
              FilaMonto(
                etiqueta: 'Total estimado',
                monto: c.totalEstimado,
                destacado: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_error != null) ...[
          MensajeError(_error!),
          const SizedBox(height: 12),
        ],
        BotonPrincipal(
          texto: _metodo == MetodoPago.yape
              ? 'Continuar con Yape'
              : 'Confirmar pedido',
          cargando: _enviando,
          onPressed: dir == null ? null : _confirmar,
        ),
      ],
    );
  }
}
