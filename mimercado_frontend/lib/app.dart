import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class MiMercadoApp extends StatelessWidget {
  const MiMercadoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      debugShowCheckedModeBanner: false,
      title: 'MiMercado+',
      theme: buildAppTheme(),
      routerConfig: appRouter,
    );
  }
}