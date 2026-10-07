import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'core/router/app_router.dart';
import 'core/state/accesibilidad_state.dart';
import 'core/theme/app_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class MiMercadoApp extends StatelessWidget {
  const MiMercadoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      locale: const Locale('es', 'PE'),
      supportedLocales: const [Locale('es', 'PE')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // La escala de letra va DENTRO de DevicePreview para que no la pise.
      builder: (context, child) => DevicePreview.appBuilder(
        context,
        ValueListenableBuilder<bool>(
          valueListenable: AccesibilidadState.letraGrande,
          builder: (context, grande, _) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: grande
                    ? const TextScaler.linear(
                        AccesibilidadState.factorLetraGrande)
                    : mq.textScaler,
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
        ),
      ),
      debugShowCheckedModeBanner: false,
      title: 'MiMercado+',
      theme: buildAppTheme(),
      routerConfig: appRouter,
    );
  }
}