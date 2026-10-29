import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';

// Piezas que comparten las vistas y los diálogos del repartidor.

ButtonStyle get estiloBotonRepartidor => FilledButton.styleFrom(
  minimumSize: const Size(48, 56),
  padding: const EdgeInsets.all(16),
  backgroundColor: AppColors.azul,
  foregroundColor: AppColors.blanco,
);

/// Botón azul grande: la acción principal de la vista.
class AccionRepartidor extends StatelessWidget {
  const AccionRepartidor(
    this.texto,
    this.alTocar, {
    super.key,
    this.ocupado = false,
  });
  final String texto;
  final VoidCallback? alTocar;
  final bool ocupado;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: FilledButton(
      style: estiloBotonRepartidor,
      onPressed: ocupado ? null : alTocar,
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

/// Título de bloque, anunciado como encabezado.
class TituloRepartidor extends StatelessWidget {
  const TituloRepartidor(this.texto, {super.key});
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Semantics(
      header: true,
      child: Text(
        texto,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
    ),
  );
}

/// Ganancia del repartidor a partir de los datos del servidor del pedido.
String gananciaDe(Map<String, dynamic> datos) => soles(
  ((datos['ganancia_repartidor_centavos'] as num?) ?? 0).toDouble() / 100,
);

String distanciaDe(Map<String, dynamic> datos) {
  final d = datos['distancia_km'];
  return d is num
      ? 'Distancia aproximada: ${d.toStringAsFixed(1)} km en línea recta'
      : 'Distancia no disponible: consulta la dirección de entrega.';
}
