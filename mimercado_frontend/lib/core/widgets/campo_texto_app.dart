import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

class CampoTextoApp extends StatefulWidget {
  const CampoTextoApp({
    super.key,
    required this.etiqueta,
    required this.controller,
    this.hint,
    this.validator,
    this.teclado = TextInputType.text,
    this.maxLongitud,
    this.mostrarContador = false,
    this.soloDigitos = false,
    this.formateadores = const [],
    this.esPassword = false,
    this.soloLectura = false,
    this.autofillHints,
    this.accion = TextInputAction.next,
    this.mayusculas = TextCapitalization.none,
    this.onSubmitted,
    this.icono,
    this.prefijo,
    this.onTap,
  });

  final String etiqueta;
  final TextEditingController controller;
  final String? hint;
  final FormFieldValidator<String>? validator;
  final TextInputType teclado;
  final int? maxLongitud;
  final bool mostrarContador;
  final bool soloDigitos;
  final List<TextInputFormatter> formateadores;
  final bool esPassword;
  final bool soloLectura;
  final Iterable<String>? autofillHints;
  final TextInputAction accion;
  final TextCapitalization mayusculas;
  final ValueChanged<String>? onSubmitted;
  final IconData? icono;
  final String? prefijo;
  final VoidCallback? onTap;

  @override
  State<CampoTextoApp> createState() => _CampoTextoAppState();
}

class _CampoTextoAppState extends State<CampoTextoApp> {
  bool _oculto = true;

  OutlineInputBorder _borde(Color color, [double ancho = 1.5]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide(color: color, width: ancho),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final esValido =
            value.text.isNotEmpty && widget.validator?.call(value.text) == null;

        Widget? sufijo;
        if (widget.onTap != null) {
          sufijo = const Icon(Icons.calendar_month, color: AppColors.azul);
        } else if (widget.esPassword) {
          sufijo = IconButton(
            tooltip: _oculto ? 'Mostrar contraseña' : 'Ocultar contraseña',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: Icon(
              _oculto
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: AppColors.azul,
            ),
            onPressed: () => setState(() => _oculto = !_oculto),
          );
        } else if (widget.soloLectura && value.text.isNotEmpty) {
          sufijo = const Icon(
            Icons.lock_outline,
            color: AppColors.textoSecundario,
            semanticLabel: 'Dato verificado, no se puede editar',
          );
        } else if (esValido) {
          sufijo = const Icon(
            Icons.check_circle,
            color: AppColors.exito,
            semanticLabel: 'Dato correcto',
          );
        }

        return TextFormField(
          controller: widget.controller,
          readOnly: widget.soloLectura || widget.onTap != null,
          onTap: widget.onTap,
          obscureText: widget.esPassword && _oculto,
          keyboardType: widget.teclado,
          textInputAction: widget.accion,
          textCapitalization: widget.mayusculas,
          autofillHints: widget.autofillHints,
          maxLength: widget.maxLongitud,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: widget.validator,
          onFieldSubmitted: widget.onSubmitted,
          inputFormatters: [
            if (widget.soloDigitos) FilteringTextInputFormatter.digitsOnly,
            ...widget.formateadores,
          ],
          style: const TextStyle(fontSize: 20, color: AppColors.texto),
          decoration: InputDecoration(
            labelText: widget.etiqueta,
            hintText: widget.hint,
            prefixText: widget.prefijo,
            prefixStyle: const TextStyle(fontSize: 20, color: AppColors.azul),
            counterText: widget.mostrarContador ? null : '',
            counterStyle: const TextStyle(
              color: AppColors.textoSecundario,
              fontSize: 15,
            ),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            floatingLabelStyle: const TextStyle(
              color: AppColors.azul,
              fontWeight: FontWeight.w700,
              fontSize: 19,
            ),
            hintStyle: const TextStyle(
              color: AppColors.textoSecundario,
              fontSize: 19,
            ),
            filled: true,
            fillColor: widget.soloLectura
                ? const Color(0xFFEFEDE6)
                : AppColors.blanco,
            prefixIcon: widget.icono == null
                ? null
                : Icon(widget.icono, color: AppColors.azul),
            suffixIcon: sufijo,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
            enabledBorder: _borde(AppColors.azul),
            focusedBorder: _borde(AppColors.azul, 3),
            errorBorder: _borde(AppColors.error),
            focusedErrorBorder: _borde(AppColors.error, 3),
            errorStyle: const TextStyle(
              color: AppColors.error,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            errorMaxLines: 3,
          ),
        );
      },
    );
  }
}
