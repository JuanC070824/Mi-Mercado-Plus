import 'package:flutter/services.dart';

// Esto me sirve para las reglas de validación (9 dígitos, correo válido, etc.)


class Validadores {
  static String? requerido(String? v, {String campo = 'Este campo'}) {
    if (v == null || v.trim().isEmpty) return '$campo es obligatorio';
    return null;
  }
  static String? dni(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'El DNI es obligatorio';
    if (!RegExp(r'^\d+$').hasMatch(t)) return 'El DNI solo lleva números';
    if (t.length != 8) return 'El DNI debe tener 8 dígitos (llevas ${t.length})';
    return null;
  }
  static String? nombre(String? v, {required String campo, bool opcional = false}) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return opcional ? null : '$campo es obligatorio';
    if (t.length < 2) return '$campo debe tener al menos 2 letras';
    if (!RegExp(r"^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ' -]+$").hasMatch(t)) {
      return '$campo solo puede tener letras';
    }
    return null;
  }

  static String? celular(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'El celular es obligatorio';
    if (!RegExp(r'^\d+$').hasMatch(t)) return 'El celular solo lleva números';
    if (t.length != 9) return 'El celular debe tener 9 dígitos (llevas ${t.length})';
    if (!t.startsWith('9')) return 'El celular debe empezar con 9';
    return null;
  }

  static String? correo(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null; // opcional en la BD
    if (t.length > 254) return 'El correo es demasiado largo';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(t)) {
      return 'Escribe un correo válido, por ejemplo nombre@correo.com';
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
    if (t.length != 10) return 'Escribe la fecha como DD/MM/AAAA';
    final f = parseFecha(t);
    if (f == null) return 'Esa fecha no existe. Revisa el día y el mes';
    if (f.isAfter(DateTime.now())) return 'La fecha no puede ser futura';
    if (f.year < 1900) return 'Revisa el año';
    return null;
  }

  static String? direccionOpcional(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    if (t.length < 5) return 'Escribe la dirección completa (calle y número)';
    return null;
  }

  static bool tieneMinimo(String p) => p.length >= 8;
  static bool tieneLetra(String p) => RegExp(r'[A-Za-z]').hasMatch(p);
  static bool tieneNumero(String p) => RegExp(r'\d').hasMatch(p);

  static String? password(String? v) {
    final p = v ?? '';
    if (p.isEmpty) return 'La contraseña es obligatoria';
    if (!tieneMinimo(p)) return 'Debe tener al menos 8 caracteres';
    if (!tieneLetra(p)) return 'Agrega al menos una letra';
    if (!tieneNumero(p)) return 'Agrega al menos un número';
    return null;
  }

  static String? confirmacion(String? v, String original) {
    if (v == null || v.isEmpty) return 'Repite tu contraseña';
    if (v != original) return 'Las contraseñas no coinciden';
    return null;
  }
}

/// Escribe las barras solas: el usuario teclea 12052000 y ve 12/05/2000.
class FormateadorFecha extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue anterior, TextEditingValue nuevo) {
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