import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';
import '../../../core/widgets/botones_app.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../core/widgets/encabezado_simple.dart';
import '../../../data/models/pedido.dart';
import '../../../data/models/repartidor.dart';
import '../../../data/models/usuario.dart';
import '../../../data/repositories/catalogo_repository.dart';
import '../../../data/repositories/pedido_repository.dart';

/// R1 · Inicio del repartidor: disponible, resumen de hoy, movilidad, mercado
/// y pedidos para recoger (con "Aceptar", que hace las veces de R1b).
class RepartidorInicioScreen extends StatefulWidget {
  const RepartidorInicioScreen({super.key, required this.usuario});
  final Usuario usuario;

  @override
  State<RepartidorInicioScreen> createState() => _RepartidorInicioScreenState();
}

class _RepartidorInicioScreenState extends State<RepartidorInicioScreen> {
  final PedidoRepository _repo = PedidoRepositoryMock.instancia;

  /// Interruptor "Disponible" (se recuerda mientras dure la sesión de la app).
  static bool _disponible = true;

  List<Pedido> _paraRecoger = [];
  List<Pedido> _hoy = [];
  Pedido? _enCurso;
  String? _mercado;
  bool _cargando = true;
  int? _aceptando;

  Repartidor? get _yo =>
      PedidoRepositoryMock.repartidorPorCelular(widget.usuario.celular);
  int get _mercadoId => widget.usuario.mercadoId ?? _yo?.mercadoId ?? 1;

  @override
  void initState() {
    super.initState();
    _repo.cambios.addListener(_cargar);
    _cargar();
  }

  @override
  void dispose() {
    _repo.cambios.removeListener(_cargar);
    super.dispose();
  }

  Future<void> _cargar() async {
    final cel = widget.usuario.celular;
    final enCurso = await _repo.entregaEnCurso(cel);
    final lista = await _repo.pedidosParaRepartidor(_mercadoId);
    final hoy = await _repo.entregasDeHoy(cel);
    final mercados = await CatalogoRepositoryMock().mercados();
    if (!mounted) return;
    setState(() {
      _enCurso = enCurso;
      _paraRecoger = lista;
      _hoy = hoy;
      _mercado = mercados
          .where((m) => m.mercado.id == _mercadoId)
          .map((m) => m.mercado.nombre)
          .firstOrNull;
      _cargando = false;
    });
  }

  Future<void> _aceptar(Pedido p) async {
    setState(() => _aceptando = p.id);
    try {
      await _repo.aceptarEntrega(p.id, widget.usuario.celular);
      if (!mounted) return;
      avisar(context, 'Tomaste el pedido #${p.codigoCorto}. ¡A recoger!');
      context.go('/repartidor/ruta');
    } on PedidoException catch (e) {
      if (mounted) avisar(context, e.mensaje);
    } finally {
      if (mounted) setState(() => _aceptando = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.usuario.nombres.split(' ').first;
    return Scaffold(
      body: Column(
        children: [
          EncabezadoSimple(
            titulo: '¡Hola, $nombre!',
            subtitulo: _mercado,
            mostrarAtras: false,
          ),
          Expanded(
            child: _cargando
                ? const CargandoApp()
                : RefreshIndicator(onRefresh: _cargar, child: _lista()),
          ),
        ],
      ),
    );
  }

  Widget _lista() {
    final yo = _yo;
    final ganado = _hoy.fold(0.0, (s, p) => s + p.costoEnvio);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        TarjetaApp(
          color: _disponible ? AppColors.exitoFondo : AppColors.fondo,
          colorBorde: _disponible ? AppColors.exitoTexto : AppColors.borde,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _disponible,
              onChanged: (v) => setState(() => _disponible = v),
              secondary: Icon(
                _disponible ? Icons.check_circle : Icons.pause_circle_outline,
                size: 32,
                color: _disponible
                    ? AppColors.exitoTexto
                    : AppColors.textoSecundario,
              ),
              title: Text(
                _disponible ? 'Disponible' : 'No disponible',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                _disponible
                    ? 'Te llegan pedidos de tu mercado'
                    : 'No te llegarán pedidos',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _Dato(
                icono: Icons.done_all,
                valor: '${_hoy.length}',
                texto: 'entregas hoy',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Dato(
                icono: Icons.payments_outlined,
                valor: soles(ganado),
                texto: 'ganado hoy',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (yo != null)
          TarjetaApp(
            child: Row(
              children: [
                Icon(
                  yo.movilidad == Movilidad.carretilla
                      ? Icons.shopping_cart_outlined
                      : Icons.electric_rickshaw,
                  color: AppColors.azul,
                  size: 32,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MergeSemantics(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Movilidad registrada',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textoSecundario,
                          ),
                        ),
                        Text(
                          yo.movilidadTexto,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '★ ${yo.calificacion.toStringAsFixed(1)} · Autorizado en ${_mercado ?? 'tu mercado'}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        if (_enCurso != null) ...[
          TarjetaApp(
            color: AppColors.azulClaro,
            colorBorde: AppColors.azul,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tienes la entrega #${_enCurso!.codigoCorto} en curso',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                BotonPrincipal(
                  texto: 'Ir a mi ruta',
                  onPressed: () => context.go('/repartidor/ruta'),
                ),
              ],
            ),
          ),
        ] else if (!_disponible)
          const AvisoPantalla(
            icono: Icons.pause_circle_outline,
            titulo: 'Estás como no disponible',
            texto: 'Activa "Disponible" para ver pedidos.',
          )
        else ...[
          TituloSeccion('Pedidos para recoger (${_paraRecoger.length})'),
          const SizedBox(height: 8),
          if (_paraRecoger.isEmpty)
            const TarjetaApp(
              child: Text(
                'Por ahora no hay pedidos listos. Te avisamos cuando haya uno.',
                style: TextStyle(fontSize: 18),
              ),
            ),
          for (final p in _paraRecoger) ...[
            _TarjetaPedido(
              pedido: p,
              cargando: _aceptando == p.id,
              onAceptar: _aceptando == null ? () => _aceptar(p) : null,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.valor, required this.texto});
  final IconData icono;
  final String valor;
  final String texto;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: TarjetaApp(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: AppColors.azul, size: 28),
          Text(
            valor,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          Text(
            texto,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textoSecundario,
            ),
          ),
        ],
      ),
    ),
  );
}

/// R1b · Pedido para recoger: puestos en orden, dirección y ganancia.
class _TarjetaPedido extends StatelessWidget {
  const _TarjetaPedido({
    required this.pedido,
    required this.cargando,
    required this.onAceptar,
  });
  final Pedido pedido;
  final bool cargando;
  final VoidCallback? onAceptar;

  @override
  Widget build(BuildContext context) {
    final puestos = pedido.puestosActivos;
    return TarjetaApp(
      colorBorde: AppColors.azul,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '#${pedido.codigoCorto} · recojo en ${puestos.length} '
            '${puestos.length == 1 ? 'puesto' : 'puestos'}',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          for (final pp in puestos)
            Text(
              '${pp.parada}. ${pp.puesto.nombre}',
              style: const TextStyle(fontSize: 17),
            ),
          const SizedBox(height: 4),
          Text(
            'Entregar en: ${pedido.direccion}',
            style: const TextStyle(
              fontSize: 17,
              color: AppColors.textoSecundario,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              EtiquetaEstado(
                texto: 'Ganas ${soles(pedido.costoEnvio)}',
                icono: Icons.payments_outlined,
                tipo: TipoEstado.exito,
              ),
              etiquetaDePedido(pedido.estado),
            ],
          ),
          const SizedBox(height: 12),
          BotonPrincipal(
            texto: 'Aceptar pedido',
            cargando: cargando,
            onPressed: onAceptar,
          ),
        ],
      ),
    );
  }
}
