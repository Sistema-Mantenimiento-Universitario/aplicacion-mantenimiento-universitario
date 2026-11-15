import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

/// Preferencias de la app guardadas en el dispositivo.
/// En Flutter web usa el localStorage del navegador.
class PreferenciasStorage {
  static const claveTema = 'pref_tema';

  /// Tema guardado; si no hay, sigue al sistema.
  Future<ThemeMode> leerTema() async {
    final prefs = await SharedPreferences.getInstance();
    return switch (prefs.getString(claveTema)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> guardarTema(ThemeMode modo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(claveTema, modo.name);
  }
}

bool _guardandoCambios = false;

/// Carga el tema guardado en [modoTema] y, a partir de ahí, guarda cada
/// cambio (desde el perfil o desde el botón de la barra).
/// Se llama una vez en `main()`.
Future<void> iniciarPreferenciaTema({PreferenciasStorage? storage}) async {
  final preferencias = storage ?? PreferenciasStorage();
  modoTema.value = await preferencias.leerTema();

  if (_guardandoCambios) return;
  _guardandoCambios = true;
  modoTema.addListener(() => preferencias.guardarTema(modoTema.value));
}
