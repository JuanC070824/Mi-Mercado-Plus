import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../core/widgets/encabezado_azul.dart';
import '../../../data/models/repartidor.dart';
import '../../../data/models/usuario.dart';
import '../../../data/repositories/administracion_api_repository.dart';

/// Administrador del mercado (RF-05, RF-18): solicitudes de repartidores y mercados.
class AdminScreen extends StatelessWidget {
  const AdminScreen({
    super.key,
    required this.usuario,
    required this.alCerrarSesion,
    this.repository,
  });
  final Usuario usuario;
  final VoidCallback alCerrarSesion;
  final AdministracionApiRepository? repository;

  @override
  Widget build(BuildContext context) {
    final repo = repository ?? AdministracionApiRepository.instancia;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Column(
          children: [
            const EncabezadoAzul(titulo: 'Administración', mostrarAtras: false),
            Material(
              color: AppColors.blanco,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Hola, ${usuario.nombres.split(' ').first}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: alCerrarSesion,
                          icon: const Icon(Icons.logout),
                          label: const Text(
                            'Cerrar sesión',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const TabBar(
                    labelStyle: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                    tabs: [
                      Tab(text: 'Repartidores'),
                      Tab(text: 'Mercados'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _Repartidores(repo: repo),
                  _Mercados(repo: repo),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carga una lista con estados de carga, error y reintento.
abstract class _ListaState<W extends StatefulWidget, T> extends State<W> {
  List<T>? datos;
  String? error;
  bool ocupado = false;

  Future<List<T>> leer();

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    try {
      final r = await leer();
      if (mounted) {
        setState(() {
          datos = r;
          error = null;
        });
      }
    } on AdministracionException catch (e) {
      if (mounted) setState(() => error = e.mensaje);
    }
  }

  Future<void> hacer(Future<void> Function() accion, String exito) async {
    setState(() => ocupado = true);
    try {
      await accion();
      await cargar();
      if (mounted) avisar(context, exito);
    } on AdministracionException catch (e) {
      if (mounted) avisar(context, e.mensaje);
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  Widget lista(List<Widget> Function(List<T>) hijos, {Widget? cabecera}) {
    if (error != null && datos == null) {
      return AvisoPantalla(
        icono: Icons.wifi_off,
        titulo: 'No pudimos cargar',
        texto: error,
        esError: true,
        textoBoton: 'Reintentar',
        alTocar: cargar,
      );
    }
    if (datos == null) return const CargandoApp();
    return RefreshIndicator(
      onRefresh: cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [?cabecera, ...hijos(datos!)],
      ),
    );
  }
}

class _Repartidores extends StatefulWidget {
  const _Repartidores({required this.repo});
  final AdministracionApiRepository repo;
  @override
  State<_Repartidores> createState() => _RepartidoresState();
}

class _RepartidoresState
    extends _ListaState<_Repartidores, SolicitudRepartidor> {
  @override
  Future<List<SolicitudRepartidor>> leer() => widget.repo.solicitudes();

  @override
  Widget build(BuildContext context) => lista(
    (datos) => datos.isEmpty
        ? [
            const AvisoPantalla(
              icono: Icons.delivery_dining,
              titulo: 'No hay solicitudes',
              texto:
                  'Cuando un repartidor pida trabajar en un mercado, '
                  'aparecerá aquí.',
            ),
          ]
        : [for (final s in datos) _tarjeta(s)],
  );

  Widget _tarjeta(SolicitudRepartidor s) {
    final movilidad = Movilidad.desdeCodigo(s.movilidad).etiqueta;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TarjetaApp(
        colorBorde: s.autorizado ? AppColors.borde : AppColors.azul,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.nombre,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${s.celular} · ${s.mercado}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textoSecundario,
                    ),
                  ),
                  Text(
                    s.placa == null ? movilidad : '$movilidad · ${s.placa}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  s.autorizado
                      ? const EtiquetaEstado(
                          texto: 'Autorizado',
                          icono: Icons.verified_outlined,
                          tipo: TipoEstado.exito,
                        )
                      : const EtiquetaEstado(
                          texto: 'Pendiente de autorizar',
                          icono: Icons.schedule,
                          tipo: TipoEstado.aviso,
                        ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (!s.autorizado)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.azul,
                  minimumSize: const Size(48, 52),
                ),
                onPressed: ocupado
                    ? null
                    : () => hacer(
                        () => widget.repo.autorizar(s.id, autorizar: true),
                        '${s.nombre} ya puede recibir pedidos.',
                      ),
                icon: const Icon(Icons.check),
                label: const Text('Autorizar', style: TextStyle(fontSize: 18)),
              )
            else if (s.entregaEnCurso)
              const Text(
                'Tiene una entrega en curso: podrás quitarle la autorización '
                'cuando termine.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textoSecundario,
                ),
              )
            else
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: AppColors.error,
                ),
                onPressed: ocupado
                    ? null
                    : () => hacer(
                        () => widget.repo.autorizar(s.id, autorizar: false),
                        '${s.nombre} ya no recibe pedidos.',
                      ),
                icon: const Icon(Icons.block),
                label: const Text(
                  'Quitar autorización',
                  style: TextStyle(fontSize: 17),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Mercados extends StatefulWidget {
  const _Mercados({required this.repo});
  final AdministracionApiRepository repo;
  @override
  State<_Mercados> createState() => _MercadosState();
}

class _MercadosState extends _ListaState<_Mercados, MercadoAdmin> {
  @override
  Future<List<MercadoAdmin>> leer() => widget.repo.mercados();

  @override
  Widget build(BuildContext context) => lista(
    cabecera: Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.azul,
          minimumSize: const Size(48, 52),
        ),
        onPressed: ocupado ? null : () => _formulario(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo mercado', style: TextStyle(fontSize: 18)),
      ),
    ),
    (datos) => [for (final m in datos) _tarjeta(m)],
  );

  Widget _tarjeta(MercadoAdmin m) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TarjetaApp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            m.nombre,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          Text(
            [m.distrito, m.direccion].whereType<String>().join(' · '),
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textoSecundario,
            ),
          ),
          Text(
            '${m.puestos} ${m.puestos == 1 ? 'puesto' : 'puestos'}',
            style: const TextStyle(fontSize: 16),
          ),
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: m.activo,
              onChanged: ocupado
                  ? null
                  : (v) => hacer(
                      () => widget.repo.editarMercado(m.id, {
                        'estado': v ? 'activo' : 'suspendido',
                      }),
                      v
                          ? '${m.nombre} vuelve a aparecer para los clientes.'
                          : '${m.nombre} ya no aparece para los clientes.',
                    ),
              title: Text(
                m.activo ? 'Activo' : 'Suspendido',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: ocupado ? null : () => _formulario(m),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar datos', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _formulario([MercadoAdmin? m]) async {
    final nombre = TextEditingController(text: m?.nombre);
    final direccion = TextEditingController(text: m?.direccion);
    final distrito = TextEditingController(text: m?.distrito);
    final clave = GlobalKey<FormState>();
    String? requerido(String? v) =>
        (v ?? '').trim().length < 3 ? 'Escribe al menos 3 letras' : null;
    final guardar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(m == null ? 'Nuevo mercado' : 'Editar mercado'),
        content: Form(
          key: clave,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nombre,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: requerido,
                ),
                TextFormField(
                  controller: direccion,
                  decoration: const InputDecoration(labelText: 'Dirección'),
                  validator: requerido,
                ),
                TextFormField(
                  controller: distrito,
                  decoration: const InputDecoration(
                    labelText: 'Distrito (opcional)',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (clave.currentState!.validate()) Navigator.of(ctx).pop(true);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (guardar != true || !mounted) return;
    final datos = (
      nombre.text.trim(),
      direccion.text.trim(),
      distrito.text.trim(),
    );
    await hacer(
      () => m == null
          ? widget.repo.crearMercado(
              nombre: datos.$1,
              direccion: datos.$2,
              distrito: datos.$3,
            )
          : widget.repo.editarMercado(m.id, {
              'nombre': datos.$1,
              'direccion': datos.$2,
              'distrito': datos.$3,
            }),
      m == null ? 'Mercado creado.' : 'Datos guardados.',
    );
  }
}
