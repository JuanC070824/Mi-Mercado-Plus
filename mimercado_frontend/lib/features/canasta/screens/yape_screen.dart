import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/botones_app.dart';
import '../../../core/widgets/campo_texto_app.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../core/widgets/encabezado_simple.dart';
import '../../../core/widgets/mensaje_error.dart';
import '../../../data/models/direccion.dart';
import '../../../data/models/pedido.dart';
import '../../../data/models/usuario.dart';
import '../../../data/repositories/canasta_repository.dart';
import '../../../data/repositories/pago_repository.dart';
import '../../../data/repositories/pedido_repository.dart';
import '../widgets/acciones_canasta.dart';
import '../widgets/pasos_compra.dart';

/// C4b · Guía de Yape (RF-04) + celular y código de aprobación (pago simulado).
class YapeScreen extends StatefulWidget {
  const YapeScreen({super.key, required this.usuario, required this.direccion});
  final Usuario usuario;
  final Direccion direccion;

  @override
  State<YapeScreen> createState() => _YapeScreenState();
}

class _YapeScreenState extends State<YapeScreen> {
  final PagoRepository _pagos = PagoRepositoryMock.instancia;
  final _form = GlobalKey<FormState>();
  late final _celular = TextEditingController(text: widget.usuario.celular);
  final _codigo = TextEditingController();
  bool _pagando = false;
  String? _error;

  @override
  void dispose() {
    _celular.dispose();
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _pagar() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    setState(() => _pagando = true);
    final monto = CanastaRepositoryMock.instancia.canasta.value.totalEstimado;
    final r = await _pagos.pagarConYape(
      celular: _celular.text.trim(),
      codigo: _codigo.text.trim(),
      monto: monto,
    );
    _codigo.clear(); // el código no se guarda en ningún lado
    if (!mounted) return;
    if (!r.aprobado) {
      // La canasta se mantiene: puede generar otro código y reintentar.
      setState(() {
        _pagando = false;
        _error = r.mensaje;
      });
      return;
    }
    try {
      final pedido = await enviarPedido(
        usuario: widget.usuario,
        direccion: widget.direccion,
        metodo: MetodoPago.yape,
      );
      if (!mounted) return;
      context.go('/canasta/enviado', extra: pedido);
    } on PedidoException catch (e) {
      if (mounted) {
        setState(() {
          _pagando = false;
          _error = e.mensaje;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = CanastaRepositoryMock.instancia.canasta.value.totalEstimado;
    return Scaffold(
      body: Column(
        children: [
          const EncabezadoSimple(titulo: 'Pagar con Yape'),
          Expanded(
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  const PasosCompra(paso: 2),
                  const SizedBox(height: 16),
                  TarjetaApp(
                    color: AppColors.azulClaro,
                    colorBorde: AppColors.azul,
                    child: MergeSemantics(
                      child: Column(
                        children: [
                          const Text('Vas a pagar',
                              style: TextStyle(fontSize: 18)),
                          Text(
                            soles(total),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: AppColors.azul,
                            ),
                          ),
                          const Text(
                            'Si el precio final cambia al pesar, la diferencia '
                            'se arregla al recibir tu pedido.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const TituloSeccion('Así se hace, en 3 pasos'),
                  const SizedBox(height: 8),
                  const _Paso(
                    numero: 1,
                    icono: Icons.phone_iphone,
                    texto: 'Abre tu app Yape y toca "Código de aprobación".',
                  ),
                  const _Paso(
                    numero: 2,
                    icono: Icons.pin_outlined,
                    texto: 'Yape te muestra 6 números. Mira bien cada uno.',
                  ),
                  const _Paso(
                    numero: 3,
                    icono: Icons.edit_outlined,
                    texto: 'Vuelve aquí y escríbelos abajo. Luego toca '
                        '"Confirmar y pagar".',
                  ),
                  const SizedBox(height: 16),
                  CampoTextoApp(
                    etiqueta: 'Celular Yape',
                    hint: '9 dígitos',
                    prefijo: '+51 ',
                    controller: _celular,
                    teclado: TextInputType.phone,
                    soloDigitos: true,
                    maxLongitud: 9,
                    icono: Icons.phone_android,
                    autofillHints: const [AutofillHints.telephoneNumberNational],
                    validator: Validadores.celular,
                  ),
                  const SizedBox(height: 12),
                  CampoTextoApp(
                    etiqueta: 'Código de aprobación (6 números)',
                    controller: _codigo,
                    teclado: TextInputType.number,
                    soloDigitos: true,
                    maxLongitud: 6,
                    mostrarContador: true,
                    icono: Icons.lock_outline,
                    accion: TextInputAction.done,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    onSubmitted: (_) => _pagar(),
                    validator: _pagos.validarCodigoYape,
                  ),
                  const SizedBox(height: 8),
                  const EtiquetaEstado(
                    texto: 'El código vence en pocos minutos. Si vence, genera '
                        'otro en Yape: tu canasta no se pierde.',
                    icono: Icons.timer_outlined,
                    tipo: TipoEstado.aviso,
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    MensajeError(_error!),
                    const SizedBox(height: 12),
                  ],
                  BotonPrincipal(
                    texto: 'Confirmar y pagar',
                    cargando: _pagando,
                    onPressed: _pagar,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({required this.numero, required this.icono, required this.texto});

  final int numero;
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MergeSemantics(
        child: TarjetaApp(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.azul,
                child: Text(
                  '$numero',
                  semanticsLabel: 'Paso $numero',
                  style: const TextStyle(
                    color: AppColors.blanco,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(icono, size: 30, color: AppColors.azul),
              const SizedBox(width: 10),
              Expanded(child: Text(texto, style: const TextStyle(fontSize: 17))),
            ],
          ),
        ),
      ),
    );
  }
}
