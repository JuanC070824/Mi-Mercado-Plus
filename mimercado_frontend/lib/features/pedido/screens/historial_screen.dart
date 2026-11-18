import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../core/widgets/encabezado_simple.dart';
import '../../../data/models/pedido.dart';
import '../../../data/models/usuario.dart';
import '../../../data/repositories/pedidos_api_repository.dart';

/// C9 · Mis pedidos (historial).
class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key, required this.usuario});
  final Usuario usuario;

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  late Future<List<Pedido>> _pedidos = pedidosApp.pedidosCliente(
    widget.usuario.celular,
  );

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
                  itemBuilder: (context, i) =>
                      _TarjetaHistorial(pedido: lista[i]),
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
  const _TarjetaHistorial({required this.pedido});
  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final p = pedido;
    final total = p.cotizacion?.totalCliente;
    return MergeSemantics(
      child: TarjetaApp(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Mi pedido',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  p.estado == EstadoPedido.cancelado
                      ? soles(0)
                      : soles(total ?? p.totalEstimado),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            Text(
              fechaCorta(p.creadoEn),
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textoSecundario,
              ),
            ),
            Text(
              p.puestos.map((x) => x.puesto.nombre).join(' · '),
              style: const TextStyle(fontSize: 17),
            ),
            const SizedBox(height: 8),
            etiquetaDePedido(p.estado),
          ],
        ),
      ),
    );
  }
}
