import 'package:speech_to_text/speech_to_text.dart';

/// Reconocimiento de voz para buscar caseros hablando (RF-08).
abstract class VozService {
  /// Pide el permiso del micrófono la primera vez. false si no se puede usar.
  Future<bool> preparar();

  /// Escucha y avisa el texto entendido; [fin] es true con el resultado definitivo.
  /// [alTerminar] avisa si dejó de escuchar sin resultado (silencio, error o
  /// micrófono bloqueado), para no dejar al usuario esperando.
  Future<void> escuchar(
    void Function(String texto, bool fin) alOir, {
    required void Function() alTerminar,
  });

  Future<void> detener();
}

class VozSpeechToText implements VozService {
  VozSpeechToText._();
  static final instancia = VozSpeechToText._();

  final _stt = SpeechToText();
  bool? _lista;
  String? _idioma;
  void Function()? _alTerminar;

  @override
  Future<bool> preparar() async {
    if (_lista == true) return true;
    try {
      _lista = await _stt.initialize(
        onError: (_) => _alTerminar?.call(),
        onStatus: (estado) {
          if (estado == SpeechToText.doneStatus ||
              estado == SpeechToText.notListeningStatus) {
            _alTerminar?.call();
          }
        },
      );
      if (_lista!) {
        // Español del Perú si el teléfono lo tiene; si no, cualquier español.
        final idiomas = await _stt.locales();
        String? buscar(bool Function(String) cumple) => idiomas
            .map((l) => l.localeId)
            .where((id) => cumple(id.toLowerCase().replaceAll('-', '_')))
            .firstOrNull;
        _idioma =
            buscar((id) => id == 'es_pe') ??
            buscar((id) => id.startsWith('es'));
      }
    } catch (_) {
      _lista = false;
    }
    return _lista!;
  }

  @override
  Future<void> escuchar(
    void Function(String texto, bool fin) alOir, {
    required void Function() alTerminar,
  }) {
    _alTerminar = alTerminar;
    return _stt.listen(
      onResult: (r) => alOir(r.recognizedWords, r.finalResult),
      listenOptions: SpeechListenOptions(
        localeId: _idioma,
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        listenMode: ListenMode.search,
      ),
    );
  }

  @override
  Future<void> detener() {
    _alTerminar = null;
    return _stt.stop();
  }
}
