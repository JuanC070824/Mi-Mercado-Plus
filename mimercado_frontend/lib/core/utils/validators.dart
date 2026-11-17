import 'package:flutter/services.dart';

import 'package:mimercado_frontend/core/i18n/idioma.dart';

// Esto me sirve para las reglas de validación (9 dígitos, correo válido, etc.)

class Validadores {
  static String? requerido(String? v, {String? campo}) {
    if (v == null || v.trim().isEmpty) {
      return tr('{0} es obligatorio', [campo ?? tr('Este campo')]);
    }
    return null;
  }

  static String? dni(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return tr('El DNI es obligatorio');
    if (!RegExp(r'^\d+$').hasMatch(t)) return tr('El DNI solo lleva números');
    if (t.length != 8) {
      return tr('El DNI debe tener 8 dígitos (llevas {0})', [t.length]);
    }
    return null;
  }

  static String? nombre(
    String? v, {
    required String campo,
    bool opcional = false,
  }) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return opcional ? null : tr('{0} es obligatorio', [campo]);
    if (t.length < 2) return tr('{0} debe tener al menos 2 letras', [campo]);
    if (!RegExp(r"^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ' -]+$").hasMatch(t)) {
      return tr('{0} solo puede tener letras', [campo]);
    }
    return null;
  }

  static String? celular(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return tr('El celular es obligatorio');
    if (!RegExp(r'^\d+$').hasMatch(t)) {
      return tr('El celular solo lleva números');
    }
    if (t.length != 9) {
      return tr('El celular debe tener 9 dígitos (llevas {0})', [t.length]);
    }
    if (!t.startsWith('9')) return tr('El celular debe empezar con 9');
    return null;
  }

  static String? correo(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null; // opcional en la BD
    if (t.length > 254) return tr('El correo es demasiado largo');
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(t)) {
      return tr('Escribe un correo válido, por ejemplo nombre@correo.com');
    }
    return null;
  }

  static DateTime? parseFecha(String t) {
    final p = t.split('/');
    if (p.length != 3) return null;
    final d = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final a = int.tryParse(p[2]);
    if (d == null || m == null || a == null) return null;
    final f = DateTime(a, m, d);
    if (f.day != d || f.month != m || f.year != a) return null;
    return f;
  }

  static String? fechaNacimiento(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null; // opcional en la BD
    if (t.length != 10) return tr('Escribe la fecha como DD/MM/AAAA');
    final f = parseFecha(t);
    if (f == null) return tr('Esa fecha no existe. Revisa el día y el mes');
    if (f.isAfter(DateTime.now())) return tr('La fecha no puede ser futura');
    if (f.year < 1900) return tr('Revisa el año');
    return null;
  }

  static String? direccionOpcional(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    if (t.length < 5) {
      return tr('Escribe la dirección completa (calle y número)');
    }
    return null;
  }

  static bool tieneMinimo(String p) => p.length >= 8;
  static bool tieneLetra(String p) => RegExp(r'[A-Za-z]').hasMatch(p);
  static bool tieneNumero(String p) => RegExp(r'\d').hasMatch(p);

  static String? password(String? v) {
    final p = v ?? '';
    if (p.isEmpty) return tr('La contraseña es obligatoria');
    if (!tieneMinimo(p)) return tr('Debe tener al menos 8 caracteres');
    if (!tieneLetra(p)) return tr('Agrega al menos una letra');
    if (!tieneNumero(p)) return tr('Agrega al menos un número');
    return null;
  }

  static String? confirmacion(String? v, String original) {
    if (v == null || v.isEmpty) return tr('Repite tu contraseña');
    if (v != original) return tr('Las contraseñas no coinciden');
    return null;
  }
}

/// Escribe las barras solas: el usuario teclea 12052000 y ve 12/05/2000.
class FormateadorFecha extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue anterior,
    TextEditingValue nuevo,
  ) {
    final digitos = nuevo.text.replaceAll(RegExp(r'\D'), '');
    final limpio = digitos.length > 8 ? digitos.substring(0, 8) : digitos;
    final b = StringBuffer();
    for (var i = 0; i < limpio.length; i++) {
      if (i == 2 || i == 4) b.write('/');
      b.write(limpio[i]);
    }
    final t = b.toString();
    return TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }
}
