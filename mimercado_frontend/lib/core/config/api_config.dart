class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: '',
  );

  static bool get configurada => baseUrl.trim().isNotEmpty;

  static Uri uri(String ruta, {String? baseUrlOverride}) {
    final base = (baseUrlOverride ?? baseUrl).trim().replaceFirst(RegExp(r'/$'), '');
    if (base.isEmpty) {
      throw StateError('Configura API_URL para conectarte al backend.');
    }
    final path = ruta.startsWith('/') ? ruta : '/$ruta';
    return Uri.parse('$base$path');
  }
}
