import 'package:flutter/material.dart';

//SON CONSTANTES DE COLORES, PARA NO TENER QUE ESCRIBIR EL CÓDIGO A CADA RATO
class AppColors {
  static const azul = Color(0xFF1B679B);            // 6:1 sobre blanco, 5,7:1 sobre el fondo
  static const fondo = Color(0xFFFAF8F3);
  static const blanco = Colors.white;
  static const texto = Color(0xFF1E293B);
  static const textoSecundario = Color(0xFF4A5568); // 7:1 sobre el fondo
  static const error = Color(0xFFB3261E);
  static const exito = Color(0xFF1B7F4B);

  static const borde = Color(0xFF8C8C8C);          // 3:1 sobre el fondo (WCAG 1.4.11)
  static const azulClaro = Color(0xFFE3EEF6);
  static const calificacion = Color(0xFF4ADBB5);

  // Estados (siempre con texto + ícono, nunca solo color). Pares de docs/04.
  static const exitoFondo = Color(0xFFDDF7EF); // "Ya pesó", "Lo tengo"
  static const exitoTexto = Color(0xFF16795F);
  static const aviso = Color(0xFF8A5A00); // "Pesando…", precio estimado
  static const avisoFondo = Color(0xFFFFF3D6);
  static const errorFondo = Color(0xFFFDECEA);
  static const divisor = Color(0xFFD5DFE8); // solo separadores decorativos
}