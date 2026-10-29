import 'package:flutter/material.dart';
import '../widgets/piezas_repartidor.dart';

typedef SolicitudMercado =
    void Function(
      int mercado,
      String movilidad,
      String placa,
      String descripcion,
    );

/// Solicitud de autorización a un mercado, o espera de la respuesta.
class RepartidorSinMercadoView extends StatefulWidget {
  const RepartidorSinMercadoView({
    super.key,
    required this.inicio,
    required this.ocupado,
    required this.alSolicitar,
  });
  final Map<String, dynamic> inicio;
  final bool ocupado;
  final SolicitudMercado alSolicitar;

  @override
  State<RepartidorSinMercadoView> createState() =>
      _RepartidorSinMercadoViewState();
}

class _RepartidorSinMercadoViewState extends State<RepartidorSinMercadoView> {
  late final _placa = TextEditingController(
    text: widget.inicio['placa']?.toString() ?? '',
  );
  late final _descripcion = TextEditingController(
    text: widget.inicio['descripcion_movilidad']?.toString() ?? '',
  );
  late String _movilidad = widget.inicio['movilidad']?.toString() ?? 'a_pie';
  int? _mercado;

  @override
  void dispose() {
    _placa.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inicio = widget.inicio;
    final ocupado = widget.ocupado;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TituloRepartidor(
          inicio['pendiente'] == true
              ? 'Esperando autorización del mercado'
              : 'Elige el mercado donde trabajarás',
        ),
        Text(
          inicio['pendiente'] == true
              ? 'Tu solicitud para ${inicio['mercado_solicitado']} está registrada. El responsable del mercado debe autorizarte.'
              : 'Solo recibirás pedidos del mercado que autorice tu cuenta.',
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 12),
        const Text('Mercado', style: TextStyle(fontSize: 18)),
        DropdownButtonFormField<int>(
          initialValue: _mercado,
          isExpanded: true,
          itemHeight: null,
          items: [
            for (final m in inicio['mercados'] as List? ?? [])
              DropdownMenuItem(
                value: (m['id'] as num).toInt(),
                child: Text(
                  m['nombre'].toString(),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
          ],
          onChanged: ocupado ? null : (v) => setState(() => _mercado = v),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        const Text('Movilidad', style: TextStyle(fontSize: 18)),
        DropdownButtonFormField<String>(
          initialValue: _movilidad,
          isExpanded: true,
          itemHeight: null,
          items: [
            for (final e in const {
              'a_pie': 'Estibador a pie',
              'carretilla': 'Carretilla',
              'bicicleta': 'Bicicleta',
              'moto': 'Moto',
              'mototaxi': 'Mototaxi',
              'otro': 'Otra movilidad',
            }.entries)
              DropdownMenuItem(
                value: e.key,
                child: Text(e.value, style: const TextStyle(fontSize: 18)),
              ),
          ],
          onChanged: ocupado ? null : (v) => setState(() => _movilidad = v!),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        const Text('Placa, si corresponde', style: TextStyle(fontSize: 18)),
        TextField(
          controller: _placa,
          maxLength: 20,
          enabled: !ocupado,
          style: const TextStyle(fontSize: 18),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        if (_movilidad == 'otro') ...[
          const Text('Describe tu movilidad', style: TextStyle(fontSize: 18)),
          TextField(
            controller: _descripcion,
            maxLength: 150,
            maxLines: 3,
            enabled: !ocupado,
            style: const TextStyle(fontSize: 18),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ],
        AccionRepartidor(
          'Solicitar autorización',
          _mercado == null
              ? null
              : () => widget.alSolicitar(
                  _mercado!,
                  _movilidad,
                  _placa.text.trim(),
                  _descripcion.text.trim(),
                ),
          ocupado: ocupado,
        ),
      ],
    );
  }
}
