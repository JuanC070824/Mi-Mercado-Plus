import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'traducciones_ay.dart';
import 'traducciones_qu.dart';

/// Idiomas de la app (con su nombre en español, como lo conoce el usuario).
enum Idioma {
  espanol('es', 'Español', Locale('es', 'PE')),
  // Material no trae textos en quechua ni aimara: sus controles (calendario,
  // copiar, pegar) quedan en español, que es lo que el usuario ya conoce.
  quechua('qu', 'Quechua', Locale('es', 'PE')),
  aimara('ay', 'Aymara', Locale('es', 'PE'));

  const Idioma(this.codigo, this.nombre, this.localeMaterial);
  final String codigo;
  final String nombre;
  final Locale localeMaterial;

  static Idioma desdeCodigo(String? codigo) => Idioma.values.firstWhere(
    (i) => i.codigo == codigo,
    orElse: () => Idioma.espanol,
  );
}

/// Idioma elegido. Cambiarlo reconstruye toda la app con los textos nuevos.
class IdiomaState {
  IdiomaState._();

  static const _clave = 'idioma';
  static final ValueNotifier<Idioma> actual = ValueNotifier(Idioma.espanol);

  /// Lee el idioma guardado (si falla, se queda en español).
  static Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      actual.value = Idioma.desdeCodigo(prefs.getString(_clave));
    } catch (_) {}
  }

  static Future<void> cambiar(Idioma idioma) async {
    actual.value = idioma;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_clave, idioma.codigo);
    } catch (_) {}
  }
}

/// Traduce un texto escrito en español al idioma elegido.
///
/// El español es la clave: si una frase aún no tiene traducción se muestra
/// en español, nunca un error. `{0}`, `{1}`… se reemplazan por [args].
String tr(String es, [List<Object?> args = const []]) {
  final tabla = switch (IdiomaState.actual.value) {
    Idioma.espanol => null,
    Idioma.quechua => traduccionesQu,
    Idioma.aimara => traduccionesAy,
  };
  var texto = tabla?[es] ?? es;
  for (var i = 0; i < args.length; i++) {
    texto = texto.replaceAll('{$i}', '${args[i]}');
  }
  return texto;
}

@visibleForTesting
void reiniciarIdioma() => IdiomaState.actual.value = Idioma.espanol;
