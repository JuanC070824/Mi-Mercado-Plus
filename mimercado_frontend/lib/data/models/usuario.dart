import 'rol.dart';

class Usuario {
  const Usuario({
    required this.nombres,
    this.apellidoPaterno,
    this.apellidoMaterno,
    required this.celular,
    this.correo,
    this.fechaNacimiento,
    this.letraGrande = false,
    this.sonido = true,
    this.vibracion = true,
    required this.rol,
  });

  final String nombres;
  final String? apellidoPaterno;
  final String? apellidoMaterno;
  final String celular;
  final String? correo;
  final DateTime? fechaNacimiento;
  final bool letraGrande;
  final bool sonido;
  final bool vibracion;
  final Rol rol;

  String get nombreCompleto => [nombres, apellidoPaterno, apellidoMaterno]
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .join(' ');
}