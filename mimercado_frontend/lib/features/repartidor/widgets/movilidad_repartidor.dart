import 'package:flutter/material.dart';
import '../../../core/widgets/componentes_app.dart';
import '../../../data/models/repartidor.dart';
import '../../../data/repositories/pedido_repository.dart';
import '../../../data/repositories/pedidos_api_repository.dart';
import 'mercado_repartidor.dart';

/// Una movilidad activa por turno; se puede cambiar al terminar el reparto.
class MovilidadRepartidor extends StatefulWidget {
  const MovilidadRepartidor({super.key, this.repository});
  final PedidosApiRepository? repository;
  @override
  State<MovilidadRepartidor> createState() => _MovilidadRepartidorState();
}

class _MovilidadRepartidorState extends State<MovilidadRepartidor> {
  late final _repo = widget.repository ?? PedidosApiRepository.instancia;
  final _placa = TextEditingController();
  final _descripcion = TextEditingController();
  Map<String, dynamic>? _datos;
  Movilidad _movilidad = Movilidad.aPie;
  bool _cargando = true, _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (TickerMode.valuesOf(context).enabled && !_cargando && !_guardando) {
      _cargar();
    }
  }

  @override
  void dispose() {
    _placa.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final d = await _repo.inicioRepartidor();
      if (!mounted) return;
      setState(() {
        _datos = d;
        _movilidad = Movilidad.desdeCodigo(d['movilidad']?.toString());
        _placa.text = d['placa']?.toString() ?? '';
        _descripcion.text = d['descripcion_movilidad']?.toString() ?? '';
        _error = null;
      });
    } on PedidoException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    if (_movilidad == Movilidad.otro && _descripcion.text.trim().isEmpty) {
      setState(() => _error = 'Describe la movilidad que utilizarás.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await _repo.cambiarMovilidad(
        _movilidad.codigo,
        _placa.text.trim(),
        _descripcion.text.trim(),
      );
      await _cargar();
      if (mounted) avisar(context, 'Tu movilidad quedó guardada.');
    } on PedidoException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activa = _datos?['en_curso'] != null;
    final editable = !_guardando && !activa;
    return TarjetaApp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: const Text(
              'Mi mercado y movilidad',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
          if (_cargando)
            const LinearProgressIndicator(
              semanticsLabel: 'Cargando tu movilidad',
            )
          else if (_datos != null) ...[
            const SizedBox(height: 12),
            MercadoRepartidor(datos: _datos!),
            const SizedBox(height: 16),
          ],
          if (!_cargando && _datos?['autorizado'] == true) ...[
            const Text(
              'Puedes usar diferentes movilidades. Elige una para tu próximo reparto.',
              style: TextStyle(fontSize: 18),
            ),
            if (activa)
              const Text(
                'Termina tu entrega para cambiar de movilidad.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            const SizedBox(height: 16),
            const Text(
              'Movilidad para repartir',
              style: TextStyle(fontSize: 18),
            ),
            DropdownButtonFormField<Movilidad>(
              key: ValueKey(_datos!['movilidad']),
              initialValue: _movilidad,
              isExpanded: true,
              itemHeight: null,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: [
                for (final m in Movilidad.values)
                  DropdownMenuItem(
                    value: m,
                    child: Text(
                      m.etiqueta,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
              ],
              onChanged: editable
                  ? (v) => setState(() {
                      _movilidad = v!;
                      if (v == Movilidad.aPie ||
                          v == Movilidad.carretilla ||
                          v == Movilidad.bicicleta) {
                        _placa.clear();
                      }
                    })
                  : null,
            ),
            if (_movilidad == Movilidad.moto ||
                _movilidad == Movilidad.mototaxi ||
                _movilidad == Movilidad.otro) ...[
              const SizedBox(height: 12),
              const Text(
                'Placa, si corresponde',
                style: TextStyle(fontSize: 18),
              ),
              TextField(
                controller: _placa,
                enabled: editable,
                maxLength: 20,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ],
            if (_movilidad == Movilidad.otro) ...[
              const Text(
                'Describe tu movilidad',
                style: TextStyle(fontSize: 18),
              ),
              TextField(
                controller: _descripcion,
                enabled: editable,
                maxLength: 150,
                maxLines: 3,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 56),
                padding: const EdgeInsets.all(16),
              ),
              onPressed: editable ? _guardar : null,
              child: Text(
                _guardando ? 'Guardando…' : 'Guardar movilidad',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ],
          if (_error != null)
            Semantics(
              liveRegion: true,
              child: Text(_error!, style: const TextStyle(fontSize: 18)),
            ),
          if (!_cargando && _datos == null)
            TextButton(
              onPressed: _cargar,
              child: const Text('Reintentar', style: TextStyle(fontSize: 18)),
            ),
        ],
      ),
    );
  }
}
