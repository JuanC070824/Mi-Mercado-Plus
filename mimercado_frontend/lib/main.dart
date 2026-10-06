import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'app.dart';

void main() {
  runApp(
    DevicePreview(
      enabled: const bool.fromEnvironment('DEVICE_PREVIEW', defaultValue: true),
      builder: (context) => const MiMercadoApp(),
    ),
  );
}