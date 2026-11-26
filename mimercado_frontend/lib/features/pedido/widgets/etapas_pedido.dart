import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../data/models/cotizacion.dart';
import '../../../data/models/pedido.dart';

import 'package:mimercado_frontend/core/i18n/idioma.dart';

/// Etapas del pedido con íconos grandes: la persona ve qué ya pasó, en qué paso
/// está ahora y qué falta. El paso de pago solo aparece si paga en línea.
class EtapasPedido extends StatelessWidget {
  const EtapasPedido({
    super.key,
    required this.pedido,
    required this.pagoEnLinea,
    required this.pagado,
  });

  final Pedido pedido;
  final bool pagoEnLinea;
  final bool pagado;

  @override
  Widget build(BuildContext context) {
    final etapas = <(IconData, String)>[
      (Icons.send_rounded, tr('Pedido enviado')),
      (Icons.scale_outlined, tr('Caseros pesan y dan el precio')),
      if (pagoEnLinea) (Icons.credit_card, tr('Pagas tu pedido')),
      (Icons.delivery_dining, tr('Recojo y camino a tu casa')),
      (Icons.home_rounded, tr('Entregado')),
    ];
    final actual = _etapaActual(etapas.length);
    return TarjetaApp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, (icono, texto)) in etapas.indexed)
            _Etapa(
              icono: icono,
              texto: texto,
              estado: i < actual
                  ? _EstadoEtapa.hecha
                  : i == actual
                  ? _EstadoEtapa.ahora
                  : _EstadoEtapa.falta,
              ultima: i == etapas.length - 1,
              numero: i + 1,
              total: etapas.length,
            ),
        ],
      ),
    );
  }

  int _etapaActual(int total) {
    if (pedido.estado == EstadoPedido.entregado) return total; // todo hecho
    final aceptado = pedido.cotizacion?.estado == EstadoCotizacion.aceptada;
    if (!aceptado) return 1;
    if (pagoEnLinea && !pagado) return 2;
    return total - 2; // recojo y camino
  }
}

enum _EstadoEtapa { hecha, ahora, falta }

class _Etapa extends StatelessWidget {
  const _Etapa({
    required this.icono,
    required this.texto,
    required this.estado,
    required this.ultima,
    required this.numero,
    required this.total,
  });

  final IconData icono;
  final String texto;
  final _EstadoEtapa estado;
  final bool ultima;
  final int numero;
  final int total;

  @override
  Widget build(BuildContext context) {
    final (fondo, color) = switch (estado) {
      _EstadoEtapa.hecha => (AppColors.exitoFondo, AppColors.exitoTexto),
      _EstadoEtapa.ahora => (AppColors.azul, AppColors.blanco),
      _EstadoEtapa.falta => (AppColors.fondo, AppColors.textoSecundario),
    };
    final estadoTexto = switch (estado) {
      _EstadoEtapa.hecha => tr('listo'),
      _EstadoEtapa.ahora => tr('ahora'),
      _EstadoEtapa.falta => tr('falta'),
    };
    return Semantics(
      label: tr('Paso {0} de {1}: {2}, {3}', [
        numero,
        total,
        texto,
        estadoTexto,
      ]),
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: fondo,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: estado == _EstadoEtapa.falta
                          ? AppColors.borde
                          : color,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    estado == _EstadoEtapa.hecha ? Icons.check : icono,
                    color: estado == _EstadoEtapa.falta
                        ? AppColors.textoSecundario
                        : color,
                    size: 26,
                  ),
                ),
                if (!ultima)
                  Expanded(
                    child: Container(
                      width: 3,
                      constraints: const BoxConstraints(minHeight: 12),
                      color: estado == _EstadoEtapa.hecha
                          ? AppColors.exitoTexto
                          : AppColors.divisor,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 10, bottom: ultima ? 0 : 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        texto,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: estado == _EstadoEtapa.ahora
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: estado == _EstadoEtapa.falta
                              ? AppColors.textoSecundario
                              : AppColors.texto,
                        ),
                      ),
                    ),
                    if (estado == _EstadoEtapa.ahora)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.azulClaro,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          tr('ESTÁS AQUÍ'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppColors.azul,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
