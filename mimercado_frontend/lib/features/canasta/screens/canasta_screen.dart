import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formato.dart';
import '../../../core/widgets/botones_app.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../core/widgets/control_cantidad.dart';
import '../../../core/widgets/encabezado_simple.dart';
import '../../../data/models/canasta.dart';
import '../../../data/repositories/canasta_repository.dart';
import '../../../data/repositories/repositorios_app.dart';
import '../widgets/acciones_canasta.dart';
import '../widgets/pasos_compra.dart';

import 'package:mimercado_frontend/core/i18n/idioma.dart';

/// C3 · Canasta por puesto (+ C3b lista de mandado). Paso 1 de 3.
class CanastaScreen extends StatefulWidget {
  const CanastaScreen({super.key});

  @override
  State<CanastaScreen> createState() => _CanastaScreenState();
}

class _CanastaScreenState extends State<CanastaScreen> {
  final CanastaRepository _repo = canastaApp;
  bool _ocupado = false;

  Future<void> _cambiar(
    GrupoPuesto g,
    Future<Object?> Function() accion,
  ) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    await cambiarCanasta(context, g.puesto, accion);
    if (mounted) setState(() => _ocupado = false);
  }

  /// Quita el producto y ofrece «Deshacer» unos segundos: el botón es grande
  /// y puede tocarse sin querer.
  Future<void> _quitar(GrupoPuesto g, ItemCanasta it) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    final ok = await cambiarCanasta(
      context,
      g.puesto,
      () => _repo.quitar(it.producto.id),
    );
    if (mounted) setState(() => _ocupado = false);
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          // Botón propio: el de SnackBarAction es pequeño para adultos mayores.
          content: Row(
            children: [
              Expanded(
                child: Text(
                  tr('Quitaste {0}.', [it.producto.nombre]),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.azulClaro,
                  minimumSize: const Size(96, 48),
                ),
                onPressed: () async {
                  messenger.hideCurrentSnackBar();
                  try {
                    await _repo.cambiarCantidad(
                      g.puesto,
                      it.producto,
                      it.cantidad,
                    );
                  } on CanastaException catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          e.mensaje,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    );
                  }
                },
                child: Text(
                  tr('Deshacer'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Future<void> _vaciar() async {
    final ok = await confirmar(
      context,
      titulo: tr('¿Vaciar tu canasta?'),
      texto: tr('Se quitarán todos los productos y las listas de mandado.'),
      textoSi: tr('Sí, vaciar'),
    );
    if (!ok) return;
    await _repo.vaciar();
    if (mounted) avisar(context, tr('Tu canasta quedó vacía.'));
  }

  Future<void> _editarLista(GrupoPuesto g) async {
    final texto = await mostrarListaMandado(context, g);
    if (texto == null || !mounted) return;
    try {
      await _repo.guardarListaMandado(g.puesto.id, texto);
      if (mounted) {
        avisar(
          context,
          texto.trim().isEmpty
              ? tr('Borraste la lista de mandado.')
              : tr('Lista de mandado guardada.'),
        );
      }
    } on CanastaException catch (e) {
      if (mounted) avisar(context, e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          EncabezadoSimple(titulo: tr('Mi canasta'), mostrarAtras: false),
          Expanded(
            child: ValueListenableBuilder<Canasta>(
              valueListenable: _repo.canasta,
              builder: (context, canasta, _) {
                if (canasta.vacia) {
                  return AvisoPantalla(
                    icono: Icons.shopping_basket_outlined,
                    titulo: tr('Tu canasta está vacía'),
                    texto: tr('Elige un casero y agrega lo que necesitas.'),
                    textoBoton: tr('Ir al mercado'),
                    alTocar: () => context.go('/inicio'),
                  );
                }
                return _lista(canasta);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _lista(Canasta c) {
    final n = c.grupos.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const PasosCompra(paso: 1),
        const SizedBox(height: 16),
        EtiquetaEstado(
          texto: n == 1
              ? tr('Un repartidor recoge en tu puesto')
              : tr('Un solo repartidor recoge en tus {0} puestos', [n]),
          icono: Icons.delivery_dining,
          tipo: TipoEstado.info,
        ),
        const SizedBox(height: 16),
        for (final g in c.grupos) ...[
          _GrupoPuesto(
            grupo: g,
            habilitado: !_ocupado,
            onSumar: (it) =>
                _cambiar(g, () => _repo.agregar(g.puesto, it.producto)),
            onRestar: (it) => _cambiar(g, () => _repo.restar(it.producto)),
            onQuitar: (it) => _quitar(g, it),
            onLista: () => _editarLista(g),
            onAgregarMas: () => context.go('/inicio/puesto/${g.puesto.id}'),
          ),
          const SizedBox(height: 16),
        ],
        TarjetaApp(
          color: AppColors.avisoFondo,
          colorBorde: AppColors.aviso,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.scale_outlined, color: AppColors.aviso),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr(
                    'Precio estimado. Cada casero pesa tus productos y te confirma el precio final antes de que salga tu pedido.',
                  ),
                  style: TextStyle(fontSize: 17, color: AppColors.texto),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TarjetaApp(
          child: Column(
            children: [
              FilaMonto(etiqueta: tr('Productos'), monto: c.totalProductos),
              FilaMonto(etiqueta: tr('Envío'), monto: c.envio),
              const Divider(color: AppColors.divisor),
              FilaMonto(
                etiqueta: tr('Total estimado'),
                monto: c.totalEstimado,
                destacado: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        BotonPrincipal(
          texto: tr('Continuar'),
          onPressed: _ocupado ? null : () => context.push('/canasta/entrega'),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: _vaciar,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              minimumSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.delete_outline),
            label: Text(tr('Vaciar canasta'), style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    );
  }
}

class _GrupoPuesto extends StatelessWidget {
  const _GrupoPuesto({
    required this.grupo,
    required this.habilitado,
    required this.onSumar,
    required this.onRestar,
    required this.onQuitar,
    required this.onLista,
    required this.onAgregarMas,
  });

  final GrupoPuesto grupo;
  final bool habilitado;
  final ValueChanged<ItemCanasta> onSumar;
  final ValueChanged<ItemCanasta> onRestar;
  final ValueChanged<ItemCanasta> onQuitar;
  final VoidCallback onLista;
  final VoidCallback onAgregarMas;

  @override
  Widget build(BuildContext context) {
    final n = grupo.items.length;
    final lista = grupo.listaMandado;
    return TarjetaApp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            label: tr('Puesto {0}, {1} {2}, subtotal {3}', [
              grupo.puesto.nombre,
              n,
              n == 1 ? tr('producto') : tr('productos'),
              soles(grupo.subtotal),
            ]),
            excludeSemantics: true,
            child: Row(
              children: [
                const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.azul,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    grupo.puesto.nombre,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  soles(grupo.subtotal),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.divisor, height: 24),
          for (final it in grupo.items) ...[
            MergeSemantics(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      it.producto.nombre,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    soles(it.subtotal),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textoSecundario,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Cantidad y «Quitar» en la misma fila: el botón de borrar queda
            // grande y junto al producto, no como un ícono en la esquina.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                ControlCantidad(
                  cantidad: it.cantidad,
                  unidad: it.producto.unidad,
                  nombre: it.producto.nombre,
                  onRestar: habilitado ? () => onRestar(it) : null,
                  onSumar: habilitado ? () => onSumar(it) : null,
                ),
                Semantics(
                  button: true,
                  label: tr('Quitar {0} de la canasta', [it.producto.nombre]),
                  excludeSemantics: true,
                  child: OutlinedButton.icon(
                    onPressed: habilitado ? () => onQuitar(it) : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error, width: 2),
                      minimumSize: const Size(120, 52),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: const StadiumBorder(),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 26),
                    label: Text(
                      tr('Quitar'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(color: AppColors.divisor, height: 24),
          ],
          // C3b · Lista de mandado
          TarjetaApp(
            color: AppColors.fondo,
            colorBorde: AppColors.divisor,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit_note, color: AppColors.azul),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        tr('Lista de mandado'),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  lista ?? tr('¿Falta algo? Escríbele al casero.'),
                  style: TextStyle(
                    fontSize: 17,
                    color: lista == null
                        ? AppColors.textoSecundario
                        : AppColors.texto,
                  ),
                ),
                TextButton(
                  onPressed: onLista,
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  child: Text(
                    lista == null
                        ? tr('Escribir lista de mandado')
                        : tr('Cambiar lista'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAgregarMas,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.azul,
                side: const BorderSide(color: AppColors.azul, width: 2),
                minimumSize: const Size(48, 52),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.add, size: 26),
              label: Text(
                tr('Agregar más productos'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hoja para escribir la lista de mandado. Devuelve el texto o null si cancela.
Future<String?> mostrarListaMandado(BuildContext context, GrupoPuesto g) {
  final ctrl = TextEditingController(text: g.listaMandado ?? '');
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('Lista de mandado para {0}', [g.puesto.nombre]),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            tr('Ejemplo: "un atado de culantro y 3 ajíes bien frescos".'),
            style: TextStyle(fontSize: 16, color: AppColors.textoSecundario),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            minLines: 3,
            maxLines: 5,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 18),
            decoration: InputDecoration(
              labelText: tr('¿Qué más le pides al casero?'),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.borde, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.borde, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          BotonPrincipal(
            texto: tr('Guardar lista'),
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text(tr('Cancelar'), style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    ),
  );
}
