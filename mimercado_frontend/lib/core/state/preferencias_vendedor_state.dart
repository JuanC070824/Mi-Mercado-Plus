import '../../data/models/usuario.dart';
import 'package:flutter/foundation.dart';
import 'accesibilidad_state.dart';

/// Permite que las pantallas conservadas por las pestañas lean el último ajuste.
class PreferenciasVendedorState {
  PreferenciasVendedorState._();
  static final cambios = ValueNotifier<Usuario?>(null);
  static Usuario de(Usuario usuario) =>
      cambios.value?.celular == usuario.celular ? cambios.value! : usuario;
  static void aplicar(Usuario usuario) {
    cambios.value = usuario;
    AccesibilidadState.letraGrande.value = usuario.letraGrande;
  }

  static void limpiar() {
    cambios.value = null;
  }
}
