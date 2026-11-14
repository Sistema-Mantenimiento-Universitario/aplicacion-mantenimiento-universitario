import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Error de la API con el mensaje listo para mostrarse al usuario.
class ApiException implements Exception {
  ApiException(this.mensaje, {this.statusCode});
  final String mensaje;
  final int? statusCode;

  /// 401: falta el token, es inválido o expiró (docs/api.md → Formato de errores).
  bool get sesionExpirada => statusCode == 401;

  @override
  String toString() => mensaje;
}

/// Contrato que usa la app para obtener datos de incidencias.
/// Implementaciones:
///  - [ApiIncidenciasRepository]: consume el backend real.
///  - FakeIncidenciasRepository (incidencias_fake_repository.dart):
///    datos simulados mientras el backend no tenga el endpoint.
abstract class IncidenciasRepository {
  /// Conteo de incidencias por estado (sin la clave "total"):
  /// {'pendiente': 3, 'asignada': 1, 'en_proceso': 2, 'finalizada': 8, 'cancelada': 0}
  ///
  /// El usuario del token determina qué se cuenta: un `usuario` solo
  /// las suyas y un `operador` todas.
  Future<Map<String, int>> obtenerResumenPorEstado();
}

class ApiIncidenciasRepository implements IncidenciasRepository {
  ApiIncidenciasRepository({
    required this.baseUrl,
    required this.token,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Incluye el prefijo /api, p. ej. 'http://localhost:3000/api'.
  final String baseUrl;
  final String? token;
  final http.Client _client;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  /// GET /api/incidencias/resumen
  ///
  /// Respuesta 200 (docs/api.md):
  /// { "pendiente": 3, "asignada": 1, "en_proceso": 2,
  ///   "finalizada": 8, "cancelada": 0, "total": 14 }
  @override
  Future<Map<String, int>> obtenerResumenPorEstado() async {
    final uri = Uri.parse('$baseUrl/incidencias/resumen');

    final http.Response res;
    try {
      res = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
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

    if (res.statusCode != 200) {
      // Formato de errores: { "ok": false, "mensaje": "..." }
      final mensaje = body is Map ? body['mensaje'] as String? : null;
      throw ApiException(
        mensaje ?? _mensajePorCodigo(res.statusCode),
        statusCode: res.statusCode,
      );
    }

    if (body is! Map) {
      throw ApiException('Respuesta inesperada del servidor');
    }

    final resumen = <String, int>{};
    body.forEach((clave, valor) {
      if (clave != 'total' && valor is num) {
        resumen[clave.toString()] = valor.toInt();
      }
    });
    return resumen;
  }

  static String _mensajePorCodigo(int codigo) => switch (codigo) {
        401 => 'Sesión expirada. Inicia sesión de nuevo',
        403 => 'No tienes permiso para ver esta información',
        404 => 'El servidor no tiene el endpoint del resumen',
        _ => 'Error $codigo al obtener el resumen',
      };
}