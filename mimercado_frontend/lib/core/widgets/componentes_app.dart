import 'package:flutter/material.dart';
import '../../data/models/pedido.dart';
import '../theme/app_colors.dart';
import '../utils/formato.dart';
import 'botones_app.dart';
import 'mensaje_error.dart';

// Piezas que se repiten en las pantallas de cliente, casero y repartidor.

/// Tarjeta blanca con borde (radio 18, padding 16).
class TarjetaApp extends StatelessWidget {
  const TarjetaApp({
    super.key,
    required this.child,
    this.color = AppColors.blanco,
    this.colorBorde = AppColors.borde,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final Color color;
  final Color colorBorde;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorBorde, width: 1.5),
      ),
      child: child,
    );
  }
}

enum TipoEstado { exito, aviso, info, error, neutro }

/// Chip de estado: SIEMPRE ícono + texto (WCAG 1.4.1).
class EtiquetaEstado extends StatelessWidget {
  const EtiquetaEstado({
    super.key,
    required this.texto,
    required this.icono,
    this.tipo = TipoEstado.neutro,
  });

  final String texto;
  final IconData icono;
  final TipoEstado tipo;

  (Color, Color) get _colores => switch (tipo) {
        TipoEstado.exito => (AppColors.exitoTexto, AppColors.exitoFondo),
        TipoEstado.aviso => (AppColors.aviso, AppColors.avisoFondo),
        TipoEstado.info => (AppColors.azul, AppColors.azulClaro),
        TipoEstado.error => (AppColors.error, AppColors.errorFondo),
        TipoEstado.neutro => (AppColors.textoSecundario, AppColors.fondo),
      };

  @override
  Widget build(BuildContext context) {
    final (texto_, fondo) = _colores;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: texto_, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 20, color: texto_),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: texto_,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta lista para el estado de UN puesto dentro del pedido.
EtiquetaEstado etiquetaDePuesto(EstadoPedidoPuesto e) {
  final (icono, tipo) = switch (e) {
    EstadoPedidoPuesto.pendiente => (Icons.schedule, TipoEstado.neutro),
    EstadoPedidoPuesto.aceptado => (Icons.thumb_up_alt_outlined, TipoEstado.info),
    EstadoPedidoPuesto.pesando => (Icons.scale_outlined, TipoEstado.aviso),
    EstadoPedidoPuesto.pesado => (Icons.check_circle, TipoEstado.exito),
    EstadoPedidoPuesto.enPreparacion => (Icons.inventory_2_outlined, TipoEstado.info),
    EstadoPedidoPuesto.listo => (Icons.shopping_bag_outlined, TipoEstado.exito),
    EstadoPedidoPuesto.recogido => (Icons.done_all, TipoEstado.exito),
    EstadoPedidoPuesto.rechazado => (Icons.block, TipoEstado.error),
    EstadoPedidoPuesto.cancelado => (Icons.cancel_outlined, TipoEstado.error),
  };
  return EtiquetaEstado(texto: e.etiqueta, icono: icono, tipo: tipo);
}

/// Etiqueta lista para el estado del pedido completo.
EtiquetaEstado etiquetaDePedido(EstadoPedido e) {
  final (icono, tipo) = switch (e) {
    EstadoPedido.pendiente => (Icons.schedule, TipoEstado.neutro),
    EstadoPedido.enPreparacion => (Icons.scale_outlined, TipoEstado.aviso),
    EstadoPedido.esperandoConfirmacion => (Icons.price_check, TipoEstado.aviso),
    EstadoPedido.listoParaRecojo => (Icons.shopping_bag_outlined, TipoEstado.info),
    EstadoPedido.enRecojo => (Icons.directions_walk, TipoEstado.info),
    EstadoPedido.enCamino => (Icons.delivery_dining, TipoEstado.info),
    EstadoPedido.entregado => (Icons.check_circle, TipoEstado.exito),
    EstadoPedido.cancelado => (Icons.cancel_outlined, TipoEstado.error),
  };
  return EtiquetaEstado(texto: e.etiqueta, icono: icono, tipo: tipo);
}

/// Línea de tiempo con la hora de cada paso (historial_estados).
class LineaTiempo extends StatelessWidget {
  const LineaTiempo({super.key, required this.eventos});

  final List<EventoEstado> eventos;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < eventos.length; i++)
          MergeSemantics(
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      horaCorta(eventos[i].hora),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textoSecundario,
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      Icon(
                        i == eventos.length - 1
                            ? Icons.radio_button_checked
                            : Icons.check_circle,
                        size: 20,
                        color: i == eventos.length - 1
                            ? AppColors.azul
                            : AppColors.exitoTexto,
                      ),
                      if (i < eventos.length - 1)
                        const Expanded(
                          child: VerticalDivider(
                            width: 20,
                            thickness: 2,
                            color: AppColors.borde,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(
                        eventos[i].texto,
                        style: TextStyle(
                          fontSize: 17,
                          color: AppColors.texto,
                          fontWeight: i == eventos.length - 1
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Fila "Productos ........ S/ 41.00".
class FilaMonto extends StatelessWidget {
  const FilaMonto({
    super.key,
    required this.etiqueta,
    required this.monto,
    this.destacado = false,
  });

  final String etiqueta;
  final double monto;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      fontSize: destacado ? 22 : 18,
      fontWeight: destacado ? FontWeight.w800 : FontWeight.w500,
      color: AppColors.texto,
    );
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(etiqueta, style: estilo)),
            Text(soles(monto), style: estilo),
          ],
        ),
      ),
    );
  }
}

/// Título de sección (22 sp, anunciado como encabezado).
class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.texto, {super.key});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.texto,
        ),
      ),
    );
  }
}

/// Estado de carga centrado.
class CargandoApp extends StatelessWidget {
  const CargandoApp({super.key, this.texto = 'Cargando…'});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(semanticsLabel: texto),
            const SizedBox(height: 16),
            Text(texto, style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

/// Estado vacío o de error, con un botón opcional.
class AvisoPantalla extends StatelessWidget {
  const AvisoPantalla({
    super.key,
    required this.icono,
    required this.titulo,
    this.texto,
    this.textoBoton,
    this.alTocar,
    this.esError = false,
  });

  final IconData icono;
  final String titulo;
  final String? texto;
  final String? textoBoton;
  final VoidCallback? alTocar;
  final bool esError;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: esError ? AppColors.errorFondo : AppColors.azulClaro,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: esError ? AppColors.error : AppColors.azul,
                    width: 2,
                  ),
                ),
                child: Icon(
                  icono,
                  size: 48,
                  color: esError ? AppColors.error : AppColors.azul,
                ),
              ),
              const SizedBox(height: 20),
              Semantics(
                liveRegion: true,
                child: Text(
                  titulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.texto,
                  ),
                ),
              ),
              if (texto != null) ...[
                const SizedBox(height: 8),
                esError
                    ? MensajeError(texto!)
                    : Text(
                        texto!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          color: AppColors.textoSecundario,
                        ),
                      ),
              ],
              if (textoBoton != null && alTocar != null) ...[
                const SizedBox(height: 24),
                BotonPrincipal(texto: textoBoton!, onPressed: alTocar),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Muestra un aviso abajo (SnackBar) con letra grande.
void avisar(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(texto, style: const TextStyle(fontSize: 18))),
    );
}

/// Pide confirmación antes de algo que no se puede deshacer (WCAG 2.5.2).
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String texto,
  required String textoSi,
  String textoNo = 'No, volver',
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      content: Text(texto, style: const TextStyle(fontSize: 18)),
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(textoNo, style: const TextStyle(fontSize: 18)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            backgroundColor: AppColors.error,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(textoSi, style: const TextStyle(fontSize: 18)),
        ),
      ],
    ),
  );
  return r ?? false;
}
