import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';
import '../../../core/widgets/botones_app.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../core/widgets/deslizar_confirmar.dart';
import '../../../core/widgets/encabezado_simple.dart';
import '../../../core/widgets/mensaje_error.dart';
import '../../../data/models/pedido.dart';
import '../../../data/models/usuario.dart';
import '../../../data/repositories/pedido_repository.dart';
import '../../casero/widgets/llamar_dialog.dart';

/// R3 · Entrega y cobro: cliente, monto a cobrar, "Avisar: llegué" y
/// código de entrega de 4 dígitos para marcar "Entregado".
class EntregaScreen extends StatefulWidget {
  const EntregaScreen({super.key, required this.usuario});
  final Usuario usuario;

  @override
  State<EntregaScreen> createState() => _EntregaScreenState();
}

class _EntregaScreenState extends State<EntregaScreen> {
  final PedidoRepository _repo = PedidoRepositoryMock.instancia;
  final _codigo = TextEditingController();

  Pedido? _pedido;
  bool _cargando = true;
  bool _ocupado = false;
  bool _avisado = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final p = await _repo.entregaEnCurso(widget.usuario.celular);
    if (!mounted) return;
    setState(() {
      _pedido = p;
      _cargando = false;
    });
  }

  Future<void> _avisarLlegada(Pedido p) async {
    await _repo.avisarLlegada(p.id);
    if (!mounted) return;
    setState(() => _avisado = true);
    avisar(context, 'Le avisamos a ${p.clienteNombre} que llegaste.');
  }

  Future<void> _entregar(Pedido p) async {
    if (!RegExp(r'^\d{4}$').hasMatch(_codigo.text.trim())) {
      setState(() => _error = 'El código de entrega tiene 4 números. Pídeselo al cliente.');
      return;
    }
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final ok = await _repo.validarCodigoEntrega(p.id, _codigo.text.trim());
      if (!mounted) return;
      if (!ok) {
        setState(() => _error = 'El código no coincide. Pídeselo de nuevo al cliente.');
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, size: 56, color: AppColors.exitoTexto),
          title: const Text('¡Pedido entregado!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          content: Text('Ganaste ${soles(p.costoEnvio)}. ¡Buen trabajo!',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.azul, minimumSize: const Size(48, 56)),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Volver al inicio', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      );
      if (mounted) context.go('/repartidor/inicio');
    } on PedidoException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const EncabezadoSimple(titulo: 'Entrega y cobro'),
          Expanded(child: _cuerpo()),
        ],
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando) return const CargandoApp();
    final p = _pedido;
    if (p == null) {
      return AvisoPantalla(
        icono: Icons.inventory_2_outlined,
        titulo: 'No tienes una entrega en curso',
        textoBoton: 'Volver al inicio',
        alTocar: () => context.go('/repartidor/inicio'),
      );
    }
    final total = p.cotizacion?.totalCliente ?? p.totalEstimado;
    final yaPago = p.metodoPago == MetodoPago.yape;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        TarjetaApp(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_outline, color: AppColors.azul, size: 30),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(p.clienteNombre,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                  IconButton.outlined(
                    tooltip: 'Llamar a ${p.clienteNombre}',
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    onPressed: () =>
                        mostrarLlamar(context, nombre: p.clienteNombre, celular: p.clienteCelular),
                    icon: const Icon(Icons.call, color: AppColors.azul),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(p.direccion, style: const TextStyle(fontSize: 18)),
              if (p.referencia != null)
                Text('Referencia: ${p.referencia}',
                    style: const TextStyle(fontSize: 17, color: AppColors.textoSecundario)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TarjetaApp(
          color: yaPago ? AppColors.exitoFondo : AppColors.avisoFondo,
          colorBorde: yaPago ? AppColors.exitoTexto : AppColors.aviso,
          child: MergeSemantics(
            child: Column(
              children: [
                Text(yaPago ? 'Ya pagó con Yape' : 'Cobra en ${p.metodoPago.etiqueta.toLowerCase()}',
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                Text(soles(total),
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
                const Text('Precio final aceptado por el cliente',
                    style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        BotonSecundario(
          texto: _avisado ? 'Ya avisaste que llegaste' : 'Avisar: llegué',
          onPressed: _avisado ? null : () => _avisarLlegada(p),
        ),
        const SizedBox(height: 20),
        const TituloSeccion('Código de entrega'),
        const SizedBox(height: 4),
        const Text('Pide al cliente su código de 4 números.', style: TextStyle(fontSize: 17)),
        const SizedBox(height: 8),
        TextField(
          controller: _codigo,
          keyboardType: TextInputType.number,
          maxLength: 4,
          textAlign: TextAlign.center,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 12),
          decoration: const InputDecoration(
            labelText: 'Código del cliente',
            border: OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.borde, width: 1.5),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          MensajeError(_error!),
        ],
        const SizedBox(height: 12),
        DeslizarConfirmar(
          texto: 'Desliza: entregado',
          textoToque: 'O toca aquí: entregado',
          habilitado: !_ocupado,
          onConfirmar: () => _entregar(p),
        ),
      ],
    );
  }
}
