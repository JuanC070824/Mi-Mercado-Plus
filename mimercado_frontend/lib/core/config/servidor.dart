import 'dart:async';

import 'package:http/http.dart' as http;

import 'api_config.dart';

/// En el plan gratis, Render apaga el servidor tras 15 minutos sin uso y tarda
/// entre 30 y 60 s en volver. Esta clase lo despierta apenas se abre la app
/// (mientras la persona elige su perfil y escribe) y permite esperar a que
/// responda antes de iniciar sesión, en lugar de mostrar un error.
class Servidor {
  Servidor._();

  static Future<bool>? _enCurso;
  static DateTime? _listoEn;

  /// Tiempo máximo que se espera a que el servidor arranque.
  static const espera = Duration(seconds: 75);

  /// true si el servidor respondió (o no hay servidor configurado).
  static Future<bool> despertar({http.Client? client}) {
    if (!ApiConfig.configurada) return Future.value(true);
    final listo = _listoEn;
    // Respondió hace poco: sigue despierto, no hace falta preguntar otra vez.
    if (listo != null &&
        DateTime.now().difference(listo) < const Duration(minutes: 10)) {
      return Future.value(true);
    }
    return _enCurso ??= _intentar(
      client ?? http.Client(),
    ).whenComplete(() => _enCurso = null);
  }

  static Future<bool> _intentar(http.Client client) async {
    final limite = DateTime.now().add(espera);
    while (DateTime.now().isBefore(limite)) {
      try {
        final r = await client
            .get(ApiConfig.uri('/api/mercados/'))
            .timeout(const Duration(seconds: 20));
        // 502/503: Render todavía está levantando el servidor.
        if (r.statusCode < 500) {
          _listoEn = DateTime.now();
          return true;
        }
      } catch (_) {
        // Sin respuesta todavía: se reintenta.
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    }
    return false;
  }
}
