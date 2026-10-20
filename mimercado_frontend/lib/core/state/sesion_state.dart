class SesionState {
  SesionState._();

  static String? _token;
  static DateTime? _venceEn;

  static String? get token => _token;
  static bool get activa =>
      _token != null && (_venceEn == null || DateTime.now().isBefore(_venceEn!));

  static void iniciar({required String token, required int expiresIn}) {
    _token = token;
    _venceEn = DateTime.now().add(Duration(seconds: expiresIn));
  }

  static void cerrar() {
    _token = null;
    _venceEn = null;
  }
}
