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

  Future<void> _vaciar() async {
    final ok = await confirmar(
      context,
      titulo: '¿Vaciar tu canasta?',
      texto: 'Se quitarán todos los productos y las listas de mandado.',
      textoSi: 'Sí, vaciar',
    );
    if (!ok) return;
    await _repo.vaciar();
    if (mounted) avisar(context, 'Tu canasta quedó vacía.');
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
              ? 'Borraste la lista de mandado.'
              : 'Lista de mandado guardada.',
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
          const EncabezadoSimple(titulo: 'Mi canasta', mostrarAtras: false),
          Expanded(
            child: ValueListenableBuilder<Canasta>(
              valueListenable: _repo.canasta,
              builder: (context, canasta, _) {
                if (canasta.vacia) {
                  return AvisoPantalla(
                    icono: Icons.shopping_basket_outlined,
                    titulo: 'Tu canasta está vacía',
                    texto: 'Elige un casero y agrega lo que necesitas.',
                    textoBoton: 'Ir al mercado',
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
              ? 'Un repartidor recoge en tu puesto'
              : 'Un solo repartidor recoge en tus $n puestos',
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
            onQuitar: (it) => _cambiar(g, () => _repo.quitar(it.producto.id)),
            onLista: () => _editarLista(g),
            onAgregarMas: () => context.go('/inicio/puesto/${g.puesto.id}'),
          ),
          const SizedBox(height: 16),
        ],
        const TarjetaApp(
          color: AppColors.avisoFondo,
          colorBorde: AppColors.aviso,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.scale_outlined, color: AppColors.aviso),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Precio estimado. Cada casero pesa tus productos y te '
                  'confirma el precio final antes de que salga tu pedido.',
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
              FilaMonto(etiqueta: 'Productos', monto: c.totalProductos),
              FilaMonto(etiqueta: 'Envío', monto: c.envio),
              const Divider(color: AppColors.divisor),
              FilaMonto(
                etiqueta: 'Total estimado',
                monto: c.totalEstimado,
                destacado: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        BotonPrincipal(
          texto: 'Continuar',
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
            label: const Text('Vaciar canasta', style: TextStyle(fontSize: 18)),
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
            label:
                'Puesto ${grupo.puesto.nombre}, $n '
                '${n == 1 ? 'producto' : 'productos'}, subtotal ${soles(grupo.subtotal)}',
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
            Row(
              children: [
                Expanded(
                  child: MergeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          it.producto.nombre,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          soles(it.subtotal),
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Quitar ${it.producto.nombre}',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: habilitado ? () => onQuitar(it) : null,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: ControlCantidad(
                cantidad: it.cantidad,
                unidad: it.producto.unidad,
                nombre: it.producto.nombre,
                onRestar: habilitado ? () => onRestar(it) : null,
                onSumar: habilitado ? () => onSumar(it) : null,
              ),
            ),
            const SizedBox(height: 12),
          ],
          // C3b · Lista de mandado
          TarjetaApp(
            color: AppColors.fondo,
            colorBorde: AppColors.divisor,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.edit_note, color: AppColors.azul),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Lista de mandado',
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
                  lista ??
                      '¿Algo que no está en la lista? Pídeselo al casero aquí.',
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
                        ? 'Escribir lista de mandado'
                        : 'Cambiar lista',
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
          TextButton.icon(
            onPressed: onAgregarMas,
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: const Icon(Icons.add),
            label: const Text(
              'Agregar o cambiar en este puesto',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
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
            'Lista de mandado para ${g.puesto.nombre}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ejemplo: "un atado de culantro y 3 ajíes bien frescos".',
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
            decoration: const InputDecoration(
              labelText: '¿Qué más le pides al casero?',
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
            texto: 'Guardar lista',
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: const Text('Cancelar', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    ),
  );
}
