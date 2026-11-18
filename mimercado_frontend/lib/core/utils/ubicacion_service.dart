import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class UbicacionActual {
  const UbicacionActual({
    required this.latitud,
    required this.longitud,
    this.direccion,
  });
  final double latitud;
  final double longitud;
  final String? direccion;
}

class UbicacionException implements Exception {
  const UbicacionException(this.mensaje);
  final String mensaje;
}

class UbicacionService {
  static Future<UbicacionActual> obtener({bool buscarDireccion = true}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const UbicacionException(
        'Tu GPS está apagado. Actívalo o escribe tu dirección.',
      );
    }

    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied) {
      throw const UbicacionException(
        'No diste permiso de ubicación. Puedes escribir tu dirección.',
      );
    }
    if (permiso == LocationPermission.deniedForever) {
      throw const UbicacionException(
        'El permiso de ubicación está bloqueado. Actívalo en los ajustes '
        'o escribe tu dirección.',
      );
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final direccion = buscarDireccion
          ? await _direccionDesde(pos.latitude, pos.longitude)
          : null;
      return UbicacionActual(
        latitud: pos.latitude,
        longitud: pos.longitude,
        direccion: direccion,
      );
    } catch (_) {
      throw const UbicacionException(
        'No pudimos obtener tu ubicación. Inténtalo de nuevo o escribe tu dirección.',
      );
    }
  }

  /// Convierte coordenadas en texto con Nominatim (OpenStreetMap).
  /// Solo para el prototipo: en producción conviene hacerlo desde el backend.
  static Future<String?> _direccionDesde(double lat, double lon) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': '$lat',
        'lon': '$lon',
        'zoom': '18',
        'addressdetails': '1',
        'accept-language': 'es',
      });
      final r = await http.get(uri).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;

      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final a = (data['address'] as Map<String, dynamic>?) ?? {};
      final calle = [
        a['road'],
        a['house_number'],
      ].whereType<String>().join(' ');
      final zona = a['suburb'] ?? a['neighbourhood'] ?? a['city_district'];
      final ciudad = a['city'] ?? a['town'] ?? a['village'];
      final partes = [
        calle,
        zona,
        ciudad,
      ].whereType<String>().where((s) => s.trim().isNotEmpty).toList();
      if (partes.isEmpty) return data['display_name'] as String?;
      return partes.join(', ');
    } catch (_) {
      return null;
    }
  }
}
