import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// "Desliza para confirmar" con alternativa de UN toque (WCAG 2.5.1 / 2.5.7):
/// el botón de abajo hace lo mismo, y el lector de pantalla lo anuncia como botón.
class DeslizarConfirmar extends StatefulWidget {
  const DeslizarConfirmar({
    super.key,
    required this.texto,
    required this.textoToque,
    required this.onConfirmar,
    this.habilitado = true,
  });

  final String texto; // "Desliza: ya empaqueté"
  final String textoToque; // "O toca aquí para confirmar"
  final VoidCallback onConfirmar;
  final bool habilitado;

  @override
  State<DeslizarConfirmar> createState() => _DeslizarConfirmarState();
}

class _DeslizarConfirmarState extends State<DeslizarConfirmar> {
  static const _tamano = 56.0;
  double _x = 0;

  void _soltar(double ancho) {
    final max = ancho - _tamano - 8;
    if (_x >= max * 0.8 && widget.habilitado) {
      setState(() => _x = 0); // vuelve al inicio por si hay que reintentar
      widget.onConfirmar();
    } else {
      setState(() => _x = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: LayoutBuilder(
            builder: (context, c) {
              final max = c.maxWidth - _tamano - 8;
              return Container(
                height: _tamano + 8,
                decoration: BoxDecoration(
                  color: widget.habilitado ? AppColors.azulClaro : AppColors.fondo,
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: AppColors.azul, width: 2),
                ),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(left: _tamano + 8, right: 12),
                        child: Text(
                          widget.texto,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.azul,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 4 + _x,
                      child: GestureDetector(
                        onHorizontalDragUpdate: widget.habilitado
                            ? (d) => setState(() => _x = (_x + d.delta.dx).clamp(0, max))
                            : null,
                        onHorizontalDragEnd: (_) => _soltar(c.maxWidth),
                        child: const CircleAvatar(
                          radius: _tamano / 2,
                          backgroundColor: AppColors.azul,
                          child: Icon(Icons.chevron_right, color: AppColors.blanco, size: 36),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: widget.habilitado ? widget.onConfirmar : null,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          icon: const Icon(Icons.touch_app_outlined),
          label: Text(widget.textoToque, style: const TextStyle(fontSize: 18)),
        ),
      ],
    );
  }
}
