import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../core/widgets/encabezado_simple.dart';
import '../../../data/models/pedido.dart';
import '../../../data/models/usuario.dart';
import '../../../data/repositories/pedido_repository.dart';
import 'casero_inicio_screen.dart';

/// V6 · Mis pedidos del casero: Nuevos / En curso / Entregados.
class MisPedidosCaseroScreen extends StatefulWidget {
  const MisPedidosCaseroScreen({super.key, required this.usuario});
  final Usuario usuario;

  @override
  State<MisPedidosCaseroScreen> createState() => _MisPedidosCaseroScreenState();
}

class _MisPedidosCaseroScreenState extends State<MisPedidosCaseroScreen> {
  final PedidoRepository _repo = PedidoRepositoryMock.instancia;
  List<Pedido> _lista = [];
  bool _cargando = true;

  int get _puestoId => widget.usuario.puestoId ?? 1;

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
    final l = await _repo.pedidosDePuesto(_puestoId);
    if (!mounted) return;
    setState(() {
      _lista = l;
      _cargando = false;
    });
  }

  PedidoPuesto _parte(Pedido p) => p.parteDePuesto(_puestoId)!;

  @override
  Widget build(BuildContext context) {
    final nuevos = [for (final p in _lista) if (_parte(p).estado == EstadoPedidoPuesto.pendiente) p];
    final entregados = [for (final p in _lista) if (_parte(p).estado == EstadoPedidoPuesto.recogido) p];
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
            const EncabezadoSimple(titulo: 'Mis pedidos', mostrarAtras: false),
            Material(
              color: AppColors.blanco,
              child: TabBar(
                labelColor: AppColors.azul,
                unselectedLabelColor: AppColors.textoSecundario,
                indicatorColor: AppColors.azul,
                indicatorWeight: 4,
                labelStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                unselectedLabelStyle: const TextStyle(fontSize: 17),
                tabs: [
                  Tab(height: 56, text: 'Nuevos (${nuevos.length})'),
                  Tab(height: 56, text: 'En curso (${enCurso.length})'),
                  Tab(height: 56, text: 'Entregados (${entregados.length})'),
                ],
              ),
            ),
            Expanded(
              child: _cargando
                  ? const CargandoApp()
                  : TabBarView(
                      children: [
                        _listaPedidos(nuevos, 'No tienes pedidos nuevos.'),
                        _listaPedidos(enCurso, 'No tienes pedidos en curso.'),
                        _listaPedidos(entregados, 'Aún no entregas pedidos.'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listaPedidos(List<Pedido> pedidos, String vacio) {
    if (pedidos.isEmpty) {
      return AvisoPantalla(icono: Icons.inbox_outlined, titulo: vacio);
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: pedidos.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) => TarjetaPedidoCasero(
          pedido: pedidos[i],
          parte: _parte(pedidos[i]),
          onTap: () => context.push('/casero/inicio/pedido/${pedidos[i].id}'),
        ),
      ),
    );
  }
}
