import 'package:flutter/material.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../data/models/puesto.dart';
import '../../../data/repositories/canasta_repository.dart';

/// Ejecuta un cambio en la canasta mostrando el error al usuario si falla.
/// Si la canasta es de otro mercado, pregunta antes de vaciarla.
/// Devuelve true si el cambio se hizo.
Future<bool> cambiarCanasta(
  BuildContext context,
  Puesto puesto,
  Future<Object?> Function() accion,
) async {
  final repo = CanastaRepositoryMock.instancia;
  final actual = repo.canasta.value;
  if (actual.mercadoId != null && actual.mercadoId != puesto.mercadoId) {
    final seguir = await confirmar(
      context,
      titulo: '¿Empezar una canasta nueva?',
      texto: 'Tu canasta tiene productos de otro mercado y un repartidor solo '
          'recoge en un mercado. Si sigues, vaciamos tu canasta y empiezas aquí.',
      textoSi: 'Vaciar y seguir',
    );
    if (!seguir) return false;
    await repo.vaciar();
  }
  try {
    await accion();
    return true;
  } on CanastaException catch (e) {
    if (context.mounted) avisar(context, e.mensaje);
    return false;
  }
}
