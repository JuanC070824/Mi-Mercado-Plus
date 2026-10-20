import 'package:flutter/foundation.dart';

class AccesibilidadState {
  AccesibilidadState._();

  static const double factorLetraGrande = 1.3;

  static final ValueNotifier<bool> letraGrande = ValueNotifier<bool>(false);

  static void alternarLetra() => letraGrande.value = !letraGrande.value;
}
