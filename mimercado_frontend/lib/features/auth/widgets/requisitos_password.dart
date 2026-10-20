import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';

//ESTOS WIDGETS SOLO LOS USA LA CARPETA AUTH, NO SON COMO LOS QUE SE VEN EN LA CARPETA CORE QUE ES GENERAL

class RequisitosPassword extends StatelessWidget {
  const RequisitosPassword({super.key, required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final p = value.text;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Requisito('Mínimo 8 caracteres', Validadores.tieneMinimo(p)),
            _Requisito('Al menos una letra', Validadores.tieneLetra(p)),
            _Requisito('Al menos un número', Validadores.tieneNumero(p)),
          ],
        );
      },
    );
  }
}

class _Requisito extends StatelessWidget {
  const _Requisito(this.texto, this.cumplido);
  final String texto;
  final bool cumplido;

  @override
  Widget build(BuildContext context) {
    final color = cumplido ? AppColors.exito : AppColors.textoSecundario;
    return Semantics(
      label: '$texto: ${cumplido ? 'cumplido' : 'pendiente'}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Icon(
                cumplido ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 20,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(texto, style: TextStyle(fontSize: 17, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
