import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';
import '../../../core/widgets/botones_app.dart';
import '../../../core/widgets/encabezado_simple.dart';
import '../../../data/models/pedido.dart';
import '../widgets/pasos_compra.dart';

import 'package:mimercado_frontend/core/i18n/idioma.dart';

/// C4c · ¡Pedido enviado!
class PedidoEnviadoScreen extends StatelessWidget {
  const PedidoEnviadoScreen({super.key, this.pedido});
  final Pedido? pedido;

  @override
  Widget build(BuildContext context) {
    final p = pedido;
    return Scaffold(
      body: Column(
        children: [
          EncabezadoSimple(titulo: tr('¡Listo!'), mostrarAtras: false),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
                const PasosCompra(paso: 3),
                const SizedBox(height: 32),
                Icon(
                  Icons.check_circle,
                  size: 110,
                  color: AppColors.exitoTexto,
                  semanticLabel: tr('Hecho'),
                ),
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    tr('¡Pedido enviado!'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  p == null
                      ? tr('Tus caseros ya recibieron tu pedido.')
                      : tr(
                          'Tu pedido ya llegó a tus caseros. Te avisamos cuando pesen y tengan el precio final.',
                        ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),
                if (p != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    tr('Total estimado: {0} · {1}', [
                      soles(p.totalEstimado),
                      p.metodoPago.etiqueta,
                    ]),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      color: AppColors.textoSecundario,
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                BotonPrincipal(
                  texto: tr('Ver mi pedido'),
                  onPressed: () => context.go('/pedido'),
                ),
                const SizedBox(height: 12),
                BotonSecundario(
                  texto: tr('Seguir comprando'),
                  onPressed: () => context.go('/inicio'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
