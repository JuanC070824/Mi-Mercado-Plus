import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/botones_app.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../core/widgets/encabezado_simple.dart';
import '../../../data/models/pedido.dart';
import '../../../data/models/usuario.dart';
import '../../../data/repositories/pedido_repository.dart';

/// R2 · Ruta de recojo: paradas en orden (Preparando → Listo → Recogido),
/// "Recogidos N de M" e "Ir a entregar" bloqueado si falta un puesto.
class RutaScreen extends StatefulWidget {
  const RutaScreen({super.key, required this.usuario});
  final Usuario usuario;

  @override
  State<RutaScreen> createState() => _RutaScreenState();
}

class _RutaScreenState extends State<RutaScreen> {
  final PedidoRepository _repo = PedidoRepositoryMock.instancia;

  Pedido? _pedido;
  bool _cargando = true;
  int? _ocupado; // id de la parada que se está guardando (-1 = salir)

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
    final p = await _repo.entregaEnCurso(widget.usuario.celular);
    if (!mounted) return;
    setState(() {
      _pedido = p;
      _cargando = false;
    });
  }

  Future<void> _recoger(PedidoPuesto pp) async {
    setState(() => _ocupado = pp.id);
    try {
      await _repo.marcarRecogido(pp.id);
      if (mounted) {
        avisar(context, 'Recogiste la bolsa de ${pp.puesto.nombre}.');
      }
    } on PedidoException catch (e) {
      if (mounted) avisar(context, e.mensaje);
    } finally {
      if (mounted) setState(() => _ocupado = null);
    }
  }

  Future<void> _irAEntregar(Pedido p) async {
    setState(() => _ocupado = -1);
    final ok = await _repo.salirAEntregar(p.id);
    if (!mounted) return;
    setState(() => _ocupado = null);
    if (ok) {
      context.push('/repartidor/ruta/entrega');
    } else {
      avisar(context, 'Todavía falta recoger en algún puesto.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          EncabezadoSimple(
            titulo: _pedido == null
                ? 'Mi ruta'
                : 'Ruta para ${_pedido!.clienteNombre}',
            mostrarAtras: false,
          ),
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
        icono: Icons.route_outlined,
        titulo: 'No tienes una entrega en curso',
        texto: 'Acepta un pedido en Inicio para ver tu ruta.',
        textoBoton: 'Ver pedidos',
        alTocar: () => context.go('/repartidor/inicio'),
      );
    }
    final paradas = [...p.puestosActivos]
      ..sort((a, b) => a.parada.compareTo(b.parada));
    final recogidos = paradas
        .where((x) => x.estado == EstadoPedidoPuesto.recogido)
        .length;
    final faltan = recogidos < paradas.length;
    final enCamino = p.estado == EstadoPedido.enCamino;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _MapaSimple(paradas: paradas),
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Text(
            'Recogidos $recogidos de ${paradas.length}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: paradas.isEmpty ? 0 : recogidos / paradas.length,
          minHeight: 10,
          borderRadius: BorderRadius.circular(5),
          color: AppColors.exitoTexto,
          backgroundColor: AppColors.divisor,
          semanticsLabel: 'Avance del recojo',
        ),
        const SizedBox(height: 16),
        for (final pp in paradas) ...[
          _Parada(
            parte: pp,
            cargando: _ocupado == pp.id,
            onRecoger: _ocupado == null && pp.estado == EstadoPedidoPuesto.listo
                ? () => _recoger(pp)
                : null,
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 4),
        BotonSecundario(
          texto: 'Avisar al cliente: estoy recogiendo',
          onPressed: () => avisar(
            context,
            'Le avisamos a ${p.clienteNombre} que estás recogiendo.',
          ),
        ),
        const SizedBox(height: 12),
        if (faltan && !enCamino)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: EtiquetaEstado(
              texto: 'Recoge en todos los puestos para poder ir a entregar',
              icono: Icons.lock_outline,
              tipo: TipoEstado.aviso,
            ),
          ),
        BotonPrincipal(
          texto: enCamino ? 'Continuar con la entrega' : 'Ir a entregar',
          cargando: _ocupado == -1,
          onPressed: (faltan && !enCamino) || _ocupado != null
              ? null
              : () => _irAEntregar(p),
        ),
      ],
    );
  }
}

/// "Mapa" simple: puestos en orden y la casa del cliente al final.
class _MapaSimple extends StatelessWidget {
  const _MapaSimple({required this.paradas});
  final List<PedidoPuesto> paradas;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Ruta: ${paradas.map((p) => p.puesto.nombre).join(', luego ')}, y al final la casa del cliente',
      excludeSemantics: true,
      child: TarjetaApp(
        color: AppColors.azulClaro,
        colorBorde: AppColors.azul,
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          runSpacing: 8,
          children: [
            for (final p in paradas) ...[
              Icon(
                p.estado == EstadoPedidoPuesto.recogido
                    ? Icons.check_circle
                    : Icons.storefront,
                color: p.estado == EstadoPedidoPuesto.recogido
                    ? AppColors.exitoTexto
                    : AppColors.azul,
                size: 32,
              ),
              const Icon(Icons.arrow_forward, color: AppColors.textoSecundario),
            ],
            const Icon(Icons.home, color: AppColors.azul, size: 32),
          ],
        ),
      ),
    );
  }
}

class _Parada extends StatelessWidget {
  const _Parada({
    required this.parte,
    required this.cargando,
    required this.onRecoger,
  });
  final PedidoPuesto parte;
  final bool cargando;
  final VoidCallback? onRecoger;

  @override
  Widget build(BuildContext context) {
    final e = parte.estado;
    final EtiquetaEstado etiqueta = switch (e) {
      EstadoPedidoPuesto.recogido => const EtiquetaEstado(
        texto: 'Recogido',
        icono: Icons.done_all,
        tipo: TipoEstado.exito,
      ),
      EstadoPedidoPuesto.listo => const EtiquetaEstado(
        texto: 'Listo',
        icono: Icons.shopping_bag_outlined,
        tipo: TipoEstado.info,
      ),
      _ => const EtiquetaEstado(
        texto: 'Preparando…',
        icono: Icons.scale_outlined,
        tipo: TipoEstado.aviso,
      ),
    };
    return TarjetaApp(
      colorBorde: e == EstadoPedidoPuesto.listo
          ? AppColors.azul
          : AppColors.borde,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Parada ${parte.parada}: ${parte.puesto.nombre}',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Atiende: ${parte.puesto.casero}',
                  style: const TextStyle(
                    fontSize: 17,
                    color: AppColors.textoSecundario,
                  ),
                ),
                const SizedBox(height: 6),
                etiqueta,
              ],
            ),
          ),
          if (e == EstadoPedidoPuesto.listo) ...[
            const SizedBox(height: 10),
            BotonPrincipal(
              texto: 'Recogí la bolsa',
              cargando: cargando,
              onPressed: onRecoger,
            ),
          ],
        ],
      ),
    );
  }
}
