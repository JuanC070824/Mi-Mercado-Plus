import '../../data/models/producto.dart';

/// Montos siempre como "S/ 15.80".
String soles(double monto) => 'S/ ${monto.toStringAsFixed(2)}';

/// "1 kg", "1.5 kg", "2 atados", "1 und.", "0.5 L".
String cantidadConUnidad(double cantidad, UnidadMedida unidad) {
  final numero = cantidad == cantidad.roundToDouble()
      ? cantidad.toStringAsFixed(0)
      : cantidad.toStringAsFixed(1);
  final simbolo = unidad == UnidadMedida.atado && cantidad != 1
      ? 'atados'
      : unidad.simbolo;
  return '$numero $simbolo';
}

/// "10:05".
String horaCorta(DateTime h) =>
    '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}';

/// "Hoy 10:05", "Ayer 18:40" o "09/10 12:40".
String fechaCorta(DateTime h, {DateTime? ahora}) {
  final hoy = ahora ?? DateTime.now();
  final dia = DateTime(h.year, h.month, h.day);
  final diferencia = DateTime(
    hoy.year,
    hoy.month,
    hoy.day,
  ).difference(dia).inDays;
  if (diferencia == 0) return 'Hoy ${horaCorta(h)}';
  if (diferencia == 1) return 'Ayer ${horaCorta(h)}';
  return '${h.day.toString().padLeft(2, '0')}/${h.month.toString().padLeft(2, '0')} '
      '${horaCorta(h)}';
}
