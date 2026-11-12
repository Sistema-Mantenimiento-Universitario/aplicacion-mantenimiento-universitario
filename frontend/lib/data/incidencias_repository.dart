import 'dart:async';
import 'dart:convert';
 
import 'package:http/http.dart' as http;
 
class ApiException implements Exception {
  ApiException(this.mensaje);
  final String mensaje;
 
  @override
  String toString() => mensaje;
}
 
class IncidenciasRepository {
  IncidenciasRepository({required this.baseUrl, this.token, http.Client? client})
      : _client = client ?? http.Client();
 
  /// Ej.: 'http://10.0.2.2:3000/api' ).
  final String baseUrl;
  final String? token;
  final http.Client _client;
 
  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
 
  /// Devuelve el conteo de incidencias agrupado por estado,
  /// p. ej. {'abierta': 3, 'en_proceso': 1, 'cerrada': 5}.
  ///
  /// Consulta GET /incidencias y cuenta por el campo `estado`.
  /// Se espera que el backend filtre según el token (el usuario solo ve
  /// las suyas y el operador ve todas).
  Future<Map<String, int>> obtenerResumenPorEstado() async {
    final uri = Uri.parse('$baseUrl/incidencias');
 
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
 
    if (res.statusCode == 401) {
      throw ApiException('Sesión expirada. Inicia sesión de nuevo.');
    }
    if (res.statusCode != 200) {
      throw ApiException('Error ${res.statusCode} al obtener las incidencias');
    }
 
    final dynamic body = jsonDecode(res.body);
    final List<dynamic> lista;
    if (body is List) {
      lista = body;
    } else if (body is Map && body['data'] is List) {
      lista = body['data'] as List;
    } else {
      throw ApiException('Respuesta inesperada del servidor');
    }
 
    final conteo = <String, int>{};
    for (final item in lista) {
      if (item is Map) {
        final estado = (item['estado'] ?? 'sin_estado').toString();
        conteo[estado] = (conteo[estado] ?? 0) + 1;
      }
    }
    return conteo;
  }
}