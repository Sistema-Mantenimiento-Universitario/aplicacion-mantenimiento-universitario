import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/usuario.dart';

/// Guarda la sesión (token, rol y datos del usuario) en el dispositivo.
/// En Flutter web usa el localStorage del navegador.
class SesionStorage {
  static const claveToken = 'sesion_token';
  static const claveUsuario = 'sesion_usuario';

  Future<void> guardar(Usuario usuario) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(claveToken, usuario.token ?? '');
    await prefs.setString(claveUsuario, jsonEncode(usuario.toJson()));
  }

  /// Devuelve la sesión guardada, o null si no hay (o está dañada).
  Future<Usuario?> leer() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(claveToken);
    final datos = prefs.getString(claveUsuario);
    if (token == null || token.isEmpty || datos == null) return null;

    try {
      final json = jsonDecode(datos) as Map<String, dynamic>;
      return Usuario.fromJson(json, token: token);
    } catch (_) {
      await borrar();
      return null;
    }
  }

  Future<void> borrar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(claveToken);
    await prefs.remove(claveUsuario);
  }
}
