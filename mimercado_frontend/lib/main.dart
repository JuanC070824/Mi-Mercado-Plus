import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'core/config/servidor.dart';
import 'core/i18n/idioma.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await IdiomaState.cargar(); // el idioma que eligió la última vez
  // Despierta el servidor mientras la persona elige su perfil y escribe.
  Servidor.despertar();
  runApp(
    DevicePreview(
      enabled: const bool.fromEnvironment('DEVICE_PREVIEW', defaultValue: true),
      builder: (context) => const MiMercadoApp(),
    ),
  );
}
