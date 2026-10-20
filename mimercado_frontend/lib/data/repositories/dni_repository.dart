import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';

class DatosReniec {
  const DatosReniec({
    required this.nombres,
    required this.apellidoPaterno,
    required this.apellidoMaterno,
    required this.registroToken,
  });

  final String nombres;
  final String apellidoPaterno;
  final String apellidoMaterno;
  final String registroToken;
}

enum EstadoConsulta { encontrado, noEncontrado, falloServicio }

class ResultadoDni {
  const ResultadoDni.encontrado(this.datos)
    : estado = EstadoConsulta.encontrado;
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

class DniApiRepository implements DniRepository {
  DniApiRepository({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl;

  static final DniApiRepository instancia = DniApiRepository();

  final http.Client _client;
  final String? _baseUrl;

  @override
  Future<ResultadoDni> consultar(String dni) async {
    try {
      final response = await _client
          .post(
            ApiConfig.uri('/api/auth/dni/', baseUrlOverride: _baseUrl),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'dni': dni}),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 404) return const ResultadoDni.noEncontrado();
      if (response.statusCode != 200) return const ResultadoDni.falloServicio();
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const ResultadoDni.falloServicio();
      }
      final nombres = decoded['nombres']?.toString() ?? '';
      final paterno = decoded['apellido_paterno']?.toString() ?? '';
      final materno = decoded['apellido_materno']?.toString() ?? '';
      final token = decoded['registro_token']?.toString() ?? '';
      if (nombres.isEmpty || paterno.isEmpty || token.isEmpty) {
        return const ResultadoDni.falloServicio();
      }
      return ResultadoDni.encontrado(
        DatosReniec(
          nombres: nombres,
          apellidoPaterno: paterno,
          apellidoMaterno: materno,
          registroToken: token,
        ),
      );
    } on TimeoutException {
      return const ResultadoDni.falloServicio();
    } on http.ClientException {
      return const ResultadoDni.falloServicio();
    } on FormatException {
      return const ResultadoDni.falloServicio();
    } on StateError {
      return const ResultadoDni.falloServicio();
    }
  }
}
