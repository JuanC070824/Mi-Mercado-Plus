import 'package:flutter/material.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../data/models/direccion.dart';
import '../../../data/models/pedido.dart';
import '../../../data/models/puesto.dart';
import '../../../data/models/usuario.dart';
import '../../../data/repositories/canasta_repository.dart';
import '../../../data/repositories/canasta_api_repository.dart';
import '../../../data/repositories/repositorios_app.dart';
import '../../../data/repositories/pedido_repository.dart';
import '../../../data/repositories/pedido_cliente_api_repository.dart';
import '../../../core/config/api_config.dart';

/// Ejecuta un cambio en la canasta mostrando el error al usuario si falla.
/// Si la canasta es de otro mercado, pregunta antes de vaciarla.
/// Devuelve true si el cambio se hizo.
Future<bool> cambiarCanasta(
  BuildContext context,
  Puesto puesto,
  Future<Object?> Function() accion,
) async {
  final repo = canastaApp;
  final actual = repo.canasta.value;
  if (actual.mercadoId != null && actual.mercadoId != puesto.mercadoId) {
    final seguir = await confirmar(
      context,
      titulo: '¿Empezar una canasta nueva?',
      texto:
          'Tu canasta tiene productos de otro mercado y un repartidor solo '
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

/// Convierte la canasta en un pedido (lo reciben los caseros) y la vacía.
/// Lanza [PedidoException] con un mensaje para el usuario si algo falla.
Future<Pedido> enviarPedido({
  required Usuario usuario,
  required Direccion direccion,
  required MetodoPago metodo,
}) async {
  final repoCanasta = canastaApp;
  final canasta = repoCanasta.canasta.value;
  if (ApiConfig.configurada) {
    final pedido = await PedidoClienteApiRepository.instancia.crear(
      canasta: canasta,
      direccion: direccion,
      metodo: metodo,
      clienteNombre: usuario.nombres,
      celular: usuario.celular,
    );
    if (repoCanasta is CanastaApiRepository) await repoCanasta.cargar();
    return pedido;
  }
  final pedido = await PedidoRepositoryMock.instancia.crearPedido(
    clienteNombre: usuario.nombres,
    clienteCelular: usuario.celular,
    direccion: direccion,
    metodo: metodo,
    puestos: [
      for (final g in canasta.grupos)
        SolicitudPuesto(
          puesto: g.puesto,
          listaMandado: g.listaMandado,
          items: [
            for (final it in g.items)
              SolicitudItem(
                productoId: it.producto.id,
                nombre: it.producto.nombre,
                unidad: it.producto.unidad,
                cantidad: it.cantidad,
                precioUnitario: it.producto.precioUnitario,
              ),
          ],
        ),
    ],
  );
  await repoCanasta.vaciar();
  return pedido;
}
