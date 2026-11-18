import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../core/widgets/soporte_dialog.dart';
import '../../../data/models/pedido.dart';
import '../../../data/models/usuario.dart';
import '../../../data/repositories/pedidos_vendedor_api_repository.dart';
import '../../../data/repositories/pedido_repository.dart';
import '../widgets/tarjeta_pedido_casero.dart';

/// V6 · Mis pedidos del casero: Nuevos / En curso / Entregados.
class MisPedidosCaseroScreen extends StatefulWidget {
  const MisPedidosCaseroScreen({
    super.key,
    required this.usuario,
    this.repository,
  });
  final Usuario usuario;
  final PedidosVendedorApiRepository? repository;

  @override
  State<MisPedidosCaseroScreen> createState() => _MisPedidosCaseroScreenState();
}

class _MisPedidosCaseroScreenState extends State<MisPedidosCaseroScreen> {
  late final PedidosVendedorApiRepository _repo;
  List<Pedido> _lista = [];
  bool _cargando = true;
  String? _error;

  int get _puestoId => widget.usuario.puestoId ?? 0;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? PedidosVendedorApiRepository.instancia;
    _repo.cambios.addListener(_cargar);
    _cargar();
  }

  @override
  void dispose() {
    _repo.cambios.removeListener(_cargar);
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await _repo.pedidosDePuesto(_puestoId);
      if (!mounted) return;
      setState(() {
        _lista = lista
            .where((p) => p.parteDePuesto(_puestoId) != null)
            .toList();
        _cargando = false;
      });
    } on PedidoException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.mensaje;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar tus pedidos. Inténtalo de nuevo.';
        _cargando = false;
      });
    }
  }

  PedidoPuesto _parte(Pedido p) => p.parteDePuesto(_puestoId)!;

  @override
  Widget build(BuildContext context) {
    final nuevos = [
      for (final p in _lista)
        if (_parte(p).estado == EstadoPedidoPuesto.pendiente) p,
    ];
    final entregados = [
      for (final p in _lista)
        if (_parte(p).estado == EstadoPedidoPuesto.recogido) p,
    ];
    final enCurso = [
      for (final p in _lista)
        if (!_parte(p).estado.descartado &&
            _parte(p).estado != EstadoPedidoPuesto.pendiente &&
            _parte(p).estado != EstadoPedidoPuesto.recogido &&
            p.estado.activo)
          p,
    ];

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: Column(
          children: [
            const _EncabezadoPedidos(),
            Material(
              color: AppColors.blanco,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.blanco,
                unselectedLabelColor: AppColors.textoSecundario,
                indicator: BoxDecoration(
                  color: AppColors.azul,
                  borderRadius: BorderRadius.circular(28),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 6,
                ),
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
                unselectedLabelStyle: const TextStyle(fontSize: 17),
                tabs: [
                  Tab(height: 64, text: 'Nuevos (${nuevos.length})'),
                  Tab(height: 64, text: 'En curso (${enCurso.length})'),
                  Tab(height: 64, text: 'Entregados (${entregados.length})'),
                ],
              ),
            ),
            Expanded(
              child: _cargando
                  ? const CargandoApp()
                  : _error != null
                  ? AvisoPantalla(
                      icono: Icons.wifi_off_outlined,
                      titulo: 'No pudimos cargar tus pedidos',
                      texto: _error,
                      esError: true,
                      textoBoton: 'Reintentar',
                      alTocar: _cargar,
                    )
                  : TabBarView(
                      children: [
                        _listaPedidos(nuevos, 'No tienes pedidos nuevos.'),
                        _listaPedidos(enCurso, 'No tienes pedidos en curso.'),
                        _listaPedidos(
                          entregados,
                          'Aún no entregas bolsas al repartidor.',
                          entregados: true,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listaPedidos(
    List<Pedido> pedidos,
    String vacio, {
    bool entregados = false,
  }) {
    if (pedidos.isEmpty) {
      return AvisoPantalla(
        icono: Icons.inbox_outlined,
        titulo: vacio,
        textoBoton: 'Actualizar',
        alTocar: _cargar,
      );
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: pedidos.length + (entregados ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, indice) {
          if (entregados && indice == 0) {
            return const Text(
              'Bolsas entregadas al repartidor. La entrega al cliente se confirma después.',
              style: TextStyle(fontSize: 16, color: AppColors.textoSecundario),
            );
          }
          final i = indice - (entregados ? 1 : 0);
          return TarjetaPedidoCasero(
            pedido: pedidos[i],
            parte: _parte(pedidos[i]),
            onTap: () => context.push('/casero/inicio/pedido/${pedidos[i].id}'),
          );
        },
      ),
    );
  }
}

class _EncabezadoPedidos extends StatelessWidget {
  const _EncabezadoPedidos();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.azul,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Semantics(
                header: true,
                child: const Text(
                  'Mis pedidos',
                  style: TextStyle(
                    color: AppColors.blanco,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => mostrarSoporte(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.blanco,
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.headset_mic_outlined),
                label: const Text('Soporte', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
