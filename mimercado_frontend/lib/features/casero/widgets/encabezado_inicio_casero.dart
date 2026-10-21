import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/soporte_dialog.dart';
import '../../../data/repositories/vendedor_inicio_repository.dart';

/// Cabecera del puesto sin alturas fijas, para permitir ampliar el texto.
class EncabezadoInicioCasero extends StatelessWidget {
  const EncabezadoInicioCasero({
    super.key,
    required this.nombre,
    required this.puesto,
    required this.guardandoEstado,
    required this.onCambiarEstado,
  });

  final String nombre;
  final PuestoVendedor puesto;
  final bool guardandoEstado;
  final ValueChanged<bool> onCambiarEstado;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.azul,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 8,
                children: [
                  const ExcludeSemantics(
                    child: CircleAvatar(
                      backgroundColor: AppColors.fondo,
                      child: Icon(Icons.storefront, color: AppColors.azul),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => mostrarSoporte(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.blanco,
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.headset_mic_outlined),
                    label: const Text(
                      'Soporte',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  '¡Hola, $nombre!',
                  style: const TextStyle(
                    color: AppColors.blanco,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                puesto.nombre,
                style: const TextStyle(
                  color: AppColors.blanco,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${puesto.mercado}'
                '${puesto.numero == null || puesto.numero!.trim().isEmpty ? '' : ' · Puesto ${puesto.numero}'}',
                style: const TextStyle(color: AppColors.blanco, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Material(
                color: AppColors.blanco,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: SwitchListTile(
                  value: puesto.abierto,
                  onChanged: guardandoEstado ? null : onCambiarEstado,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  title: Text(
                    puesto.abierto ? 'Puesto abierto' : 'Puesto cerrado',
                    style: const TextStyle(
                      color: AppColors.texto,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    puesto.abierto
                        ? 'Los clientes pueden hacerte pedidos.'
                        : 'No recibirás nuevos pedidos. Los que ya aceptaste siguen en curso.',
                    style: const TextStyle(
                      color: AppColors.textoSecundario,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              if (guardandoEstado) ...[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: const Text(
                    'Guardando estado del puesto…',
                    style: TextStyle(color: AppColors.blanco, fontSize: 16),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
