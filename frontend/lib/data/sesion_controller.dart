import 'package:flutter/foundation.dart';

import '../models/usuario.dart';
import 'auth_repository.dart';
import 'incidencias_repository.dart' show ApiException;
import 'sesion_storage.dart';

enum EstadoSesion { cargando, sinSesion, conSesion }

/// Estado de la sesión de toda la app. `main.dart` lo escucha para
/// decidir si muestra el login o la pantalla principal.
class SesionController extends ChangeNotifier {
  SesionController({required this.auth, required this.storage});

  final AuthRepository auth;
  final SesionStorage storage;

  EstadoSesion _estado = EstadoSesion.cargando;
  Usuario? _usuario;

  EstadoSesion get estado => _estado;
  Usuario? get usuario => _usuario;

  /// Al abrir la app: si hay sesión guardada, la valida con
  /// GET /api/auth/perfil y entra directo a la pantalla principal.
  Future<void> iniciar() async {
    final guardado = await storage.leer();
    if (guardado == null) {
      _cambiar(EstadoSesion.sinSesion, null);
      return;
    }

    try {
      final usuario = await auth.perfil(guardado.token!);
      await storage.guardar(usuario);
      _cambiar(EstadoSesion.conSesion, usuario);
    } on ApiException catch (e) {
      if (e.sesionExpirada) {
        // Token inválido o expirado: se borra y se pide login.
        await storage.borrar();
        _cambiar(EstadoSesion.sinSesion, null);
      } else {
        // Sin conexión u otro error: se entra con los datos guardados.
        _cambiar(EstadoSesion.conSesion, guardado);
      }
    }
  }

  /// Lanza [ApiException] si las credenciales son incorrectas.
  Future<void> iniciarSesion(String correo, String password) async {
    final usuario = await auth.login(correo, password);
    await storage.guardar(usuario);
    _cambiar(EstadoSesion.conSesion, usuario);
  }

  Future<void> cerrarSesion() async {
    await storage.borrar();
    _cambiar(EstadoSesion.sinSesion, null);
  }

  void _cambiar(EstadoSesion estado, Usuario? usuario) {
    _estado = estado;
    _usuario = usuario;
    notifyListeners();
  }
}
