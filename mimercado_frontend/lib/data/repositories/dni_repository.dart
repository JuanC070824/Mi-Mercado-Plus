class DatosReniec {
  const DatosReniec({
    required this.nombres,
    required this.apellidoPaterno,
    required this.apellidoMaterno,
  });

  final String nombres;
  final String apellidoPaterno;
  final String apellidoMaterno;
}

enum EstadoConsulta { encontrado, noEncontrado, falloServicio }

class ResultadoDni {
  const ResultadoDni.encontrado(this.datos) : estado = EstadoConsulta.encontrado;
  const ResultadoDni.noEncontrado()
      : estado = EstadoConsulta.noEncontrado,
        datos = null;
  const ResultadoDni.falloServicio()
      : estado = EstadoConsulta.falloServicio,
        datos = null;

  final EstadoConsulta estado;
  final DatosReniec? datos;
}

abstract class DniRepository {
  Future<ResultadoDni> consultar(String dni);
}

/// Simula la consulta de DNI. En producción la hará el backend (con el token).
class DniRepositoryMock implements DniRepository {
  // Los datos de RENIEC suelen venir en MAYÚSCULAS; aquí se convierten a "Título".
  static const Map<String, (String, String, String)> _padron = {
    '12345678': ('MARIA ESPERANZA', 'DEL PILAR', 'LÓPEZ'),
    '87654321': ('JUAN CARLOS', 'QUISPE', 'MAMANI'),
    '45612378': ('ROSA ELENA', 'FLORES', 'HUAMAN'),
  };

  static String _titulo(String s) => s
      .toLowerCase()
      .split(' ')
      .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
      .join(' ');

  @override
  Future<ResultadoDni> consultar(String dni) async {
    await Future.delayed(const Duration(milliseconds: 900));
    if (dni == '99999999') return const ResultadoDni.falloServicio();
    final f = _padron[dni];
    if (f == null) return const ResultadoDni.noEncontrado();
    return ResultadoDni.encontrado(
      DatosReniec(
        nombres: _titulo(f.$1),
        apellidoPaterno: _titulo(f.$2),
        apellidoMaterno: _titulo(f.$3),
      ),
    );
  }
}