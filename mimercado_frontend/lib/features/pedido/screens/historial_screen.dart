import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/api_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../core/widgets/encabezado_simple.dart';
import '../../../data/models/pedido.dart';
import '../../../data/models/usuario.dart';
import '../../../data/repositories/canasta_api_repository.dart';
import '../../../data/repositories/canasta_repository.dart';
import '../../../data/repositories/pedidos_api_repository.dart';

/// C9 · Mis pedidos (historial).
class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key, required this.usuario, this.canasta});
  final Usuario usuario;
  final CanastaApiRepository? canasta;

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  late Future<List<Pedido>> _pedidos = pedidosApp.pedidosCliente(
    widget.usuario.celular,
  );
  int? _repitiendo;

  /// "Volver a pedir" solo existe con servidor: arma la canasta en el backend.
  bool get _puedeRepetir => widget.canasta != null || ApiConfig.configurada;

  Future<void> _volverAPedir(Pedido pedido) async {
    setState(() => _repitiendo = pedido.id);
    try {
      final omitidos = await (widget.canasta ?? CanastaApiRepository.instancia)
          .volverAPedir(pedido.id);
      if (!mounted) return;
      avisar(
        context,
        omitidos.isEmpty
            ? 'Listo, pusimos tus productos en la canasta.'
            : 'Pusimos lo disponible. No hay: ${omitidos.join(', ')}.',
      );
      context.go('/canasta');
    } on CanastaException catch (e) {
      if (mounted) avisar(context, e.mensaje);
    } finally {
      if (mounted) setState(() => _repitiendo = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const EncabezadoSimple(titulo: 'Mis pedidos'),
          Expanded(
            child: FutureBuilder<List<Pedido>>(
              future: _pedidos,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const CargandoApp(texto: 'Cargando tus pedidos…');
                }
                if (snap.hasError) {
                  return AvisoPantalla(
                    icono: Icons.wifi_off,
                    titulo: 'No pudimos cargar tus pedidos',
                    esError: true,
                    textoBoton: 'Reintentar',
                    alTocar: () => setState(() {
                      _pedidos = pedidosApp.pedidosCliente(
                        widget.usuario.celular,
                      );
                    }),
                  );
                }
                final lista = snap.data!;
                if (lista.isEmpty) {
                  return const AvisoPantalla(
                    icono: Icons.receipt_long_outlined,
                    titulo: 'Aún no tienes pedidos',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  itemCount: lista.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _TarjetaHistorial(
                    pedido: lista[i],
                    repitiendo: _repitiendo == lista[i].id,
                    alRepetir:
                        _puedeRepetir &&
                            _repitiendo == null &&
                            lista[i].estado == EstadoPedido.entregado
                        ? () => _volverAPedir(lista[i])
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaHistorial extends StatelessWidget {
  const _TarjetaHistorial({
    required this.pedido,
    this.alRepetir,
    this.repitiendo = false,
  });
  final Pedido pedido;
  final VoidCallback? alRepetir;
  final bool repitiendo;

  @override
  Widget build(BuildContext context) {
    final p = pedido;
    final total = p.cotizacion?.totalCliente;
    return TarjetaApp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MergeSemantics(child: _datos(p, total)),
          if (alRepetir != null || repitiendo) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: AppColors.azul,
                side: const BorderSide(color: AppColors.azul, width: 1.5),
              ),
              onPressed: repitiendo ? null : alRepetir,
              icon: repitiendo
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(Icons.replay),
              label: const Text(
                'Volver a pedir',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _datos(Pedido p, double? total) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Mi pedido',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            p.estado == EstadoPedido.cancelado
                ? soles(0)
                : soles(total ?? p.totalEstimado),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ],
      ),
      Text(
        fechaCorta(p.creadoEn),
        style: const TextStyle(fontSize: 16, color: AppColors.textoSecundario),
      ),
      Text(
        p.puestos.map((x) => x.puesto.nombre).join(' · '),
        style: const TextStyle(fontSize: 17),
      ),
      const SizedBox(height: 8),
      etiquetaDePedido(p.estado),
    ],
  );
}
