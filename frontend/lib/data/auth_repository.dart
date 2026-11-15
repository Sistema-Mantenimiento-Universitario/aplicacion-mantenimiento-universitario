import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/usuario.dart';
import 'incidencias_repository.dart' show ApiException;

/// Autenticación (docs/api.md -> Autenticación).
/// Implementaciones:
///  - [ApiAuthRepository]: consume el backend real.
///  - FakeAuthRepository (auth_fake_repository.dart): usuarios de prueba.
abstract class AuthRepository {
  /// POST /api/auth/login. Devuelve el usuario con su token.
  /// Lanza [ApiException] con statusCode 401 si las credenciales son incorrectas.
  Future<Usuario> login(String correo, String password);

  /// GET /api/auth/perfil. Comprueba que el token sigue siendo válido.
  /// Lanza [ApiException] con statusCode 401 si expiró o es inválido.
  Future<Usuario> perfil(String token);
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  /// Incluye el prefijo /api, p. ej. 'http://localhost:3000/api'.
  final String baseUrl;
  final http.Client _client;

  @override
  Future<Usuario> login(String correo, String password) async {
    final body = await _enviar(
      () => _client.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'correo': correo, 'password': password}),
      ),
      mensaje401: 'Correo o contraseña incorrectos',
    );

    final token = body['token'];
    final usuario = body['usuario'];
    if (token is! String || usuario is! Map<String, dynamic>) {
      throw ApiException('Respuesta inesperada del servidor');
    }
    return Usuario.fromJson(usuario, token: token);
  }

  @override
  Future<Usuario> perfil(String token) async {
    final body = await _enviar(
      () => _client.get(
        Uri.parse('$baseUrl/auth/perfil'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
      mensaje401: 'Sesión expirada. Inicia sesión de nuevo',
    );
    return Usuario.fromJson(body, token: token);
  }

  /// Hace la petición y devuelve el JSON, o lanza [ApiException]
  /// con el `mensaje` del formato de errores del contrato.
  Future<Map<String, dynamic>> _enviar(
    Future<http.Response> Function() peticion, {
    required String mensaje401,
  }) async {
    final http.Response res;
    try {
      res = await peticion().timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw ApiException('El servidor tardó demasiado en responder');
    } catch (_) {
      throw ApiException('No se pudo conectar con el servidor');
    }

    dynamic body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      body = null;
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final mensaje = body is Map ? body['mensaje'] as String? : null;
      throw ApiException(
        mensaje ??
            (res.statusCode == 401 ? mensaje401 : 'Error ${res.statusCode}'),
        statusCode: res.statusCode,
      );
    }

    if (body is! Map<String, dynamic>) {
      throw ApiException('Respuesta inesperada del servidor');
    }
    return body;
  }
}
