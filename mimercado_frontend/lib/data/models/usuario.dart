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
    this.puestoId,
    this.mercadoId,
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

  /// Solo casero: su puesto (puestos.vendedor_id).
  final int? puestoId;

  /// Casero y repartidor: el mercado donde trabaja (repartidor_mercados).
  final int? mercadoId;

  String get nombreCompleto => [
    nombres,
    apellidoPaterno,
    apellidoMaterno,
  ].whereType<String>().where((s) => s.isNotEmpty).join(' ');

  Usuario copyWith({
    String? celular,
    String? correo,
    bool? letraGrande,
    bool? sonido,
    bool? vibracion,
    int? puestoId,
    int? mercadoId,
  }) => Usuario(
    nombres: nombres,
    apellidoPaterno: apellidoPaterno,
    apellidoMaterno: apellidoMaterno,
    celular: celular ?? this.celular,
    correo: correo ?? this.correo,
    fechaNacimiento: fechaNacimiento,
    letraGrande: letraGrande ?? this.letraGrande,
    sonido: sonido ?? this.sonido,
    vibracion: vibracion ?? this.vibracion,
    rol: rol,
    puestoId: puestoId ?? this.puestoId,
    mercadoId: mercadoId ?? this.mercadoId,
  );
}
