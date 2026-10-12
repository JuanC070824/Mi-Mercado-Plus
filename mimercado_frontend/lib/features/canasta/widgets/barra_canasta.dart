import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';
import '../../../data/models/canasta.dart';
import '../../../data/repositories/canasta_repository.dart';

/// Barra fija "Tu canasta · S/ X · Ver canasta". No se muestra si está vacía.
class BarraCanasta extends StatelessWidget {
  const BarraCanasta({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Canasta>(
      valueListenable: CanastaRepositoryMock.instancia.canasta,
      builder: (context, canasta, _) {
        if (canasta.vacia) return const SizedBox.shrink();
        final n = canasta.cantidadProductos;
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.blanco,
            border: Border(top: BorderSide(color: AppColors.borde, width: 1.5)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tu canasta · $n ${n == 1 ? 'producto' : 'productos'}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textoSecundario,
                          ),
                        ),
                        Text(
                          soles(canasta.totalProductos),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.texto,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => context.go('/canasta'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.azul,
                    minimumSize: const Size(48, 56),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.shopping_basket_rounded),
                  label: const Text(
                    'Ver canasta',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
