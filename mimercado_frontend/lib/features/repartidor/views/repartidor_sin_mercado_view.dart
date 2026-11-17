import 'package:flutter/material.dart';
import '../widgets/piezas_repartidor.dart';

import 'package:mimercado_frontend/core/i18n/idioma.dart';

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
              ? tr('Esperando autorización del mercado')
              : tr('Elige el mercado donde trabajarás'),
        ),
        Text(
          inicio['pendiente'] == true
              ? tr(
                  'Tu solicitud para {0} está registrada. El responsable del mercado debe autorizarte.',
                  [inicio['mercado_solicitado']],
                )
              : tr(
                  'Solo recibirás pedidos del mercado que autorice tu cuenta.',
                ),
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 12),
        Text(tr('Mercado'), style: TextStyle(fontSize: 18)),
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
        Text(tr('Movilidad'), style: TextStyle(fontSize: 18)),
        DropdownButtonFormField<String>(
          initialValue: _movilidad,
          isExpanded: true,
          itemHeight: null,
          items: [
            for (final e in {
              'a_pie': tr('Estibador a pie'),
              'carretilla': tr('Carretilla'),
              'bicicleta': tr('Bicicleta'),
              'moto': tr('Moto'),
              'mototaxi': tr('Mototaxi'),
              'otro': tr('Otra movilidad'),
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
        Text(tr('Placa, si corresponde'), style: TextStyle(fontSize: 18)),
        TextField(
          controller: _placa,
          maxLength: 20,
          enabled: !ocupado,
          style: const TextStyle(fontSize: 18),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        if (_movilidad == 'otro') ...[
          Text(tr('Describe tu movilidad'), style: TextStyle(fontSize: 18)),
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
          tr('Solicitar autorización'),
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
