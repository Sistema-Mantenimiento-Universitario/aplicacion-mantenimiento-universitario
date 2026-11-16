import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/categoria.dart';
import '../models/estado_incidencia.dart';
import '../models/incidencia.dart';

/// Error de la API con el mensaje listo para mostrarse al usuario.
class ApiException implements Exception {
  ApiException(this.mensaje, {this.statusCode});
  final String mensaje;
  final int? statusCode;

  /// 401: falta el token, es inválido o expiró (docs/api.md -> Formato de errores).
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
  // Listado de incidencias desde la más reciente a la más antigua
  Future<List<Incidencia>> obtenerIncidencias({
    String? texto,
    EstadoIncidencia? estado,
    int? idCategoria,
  });

  /// Categorías para el filtro del listado y para el formulario.
  Future<List<Categoria>> obtenerCategorias();
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
    final body = await _getJson(
      Uri.parse('$baseUrl/incidencias/resumen'),
      recurso: 'el resumen',
    );

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

  /// GET /api/incidencias?estado=...&categoria=...&q=...
  ///
  /// Respuesta 200: lista de incidencias (`[]` si no hay resultados).
  @override
  Future<List<Incidencia>> obtenerIncidencias({
    String? texto,
    EstadoIncidencia? estado,
    int? idCategoria,
  }) async {
    final q = texto?.trim() ?? '';
    final parametros = {
      if (estado != null) 'estado': estado.valorIncidencia,
      if (idCategoria != null) 'categoria': '$idCategoria',
      if (q.isNotEmpty) 'q': q,
    };
    final uri = Uri.parse('$baseUrl/incidencias');

    final body = await _getJson(
      parametros.isEmpty ? uri : uri.replace(queryParameters: parametros),
      recurso: 'las incidencias',
    );
    return _convertirLista(body, Incidencia.fromJson);
  }

  /// GET /api/categorias
  @override
  Future<List<Categoria>> obtenerCategorias() async {
    final body = await _getJson(
      Uri.parse('$baseUrl/categorias'),
      recurso: 'las categorías',
    );
    return _convertirLista(body, Categoria.fromJson);
  }

  // Hace un GET y devuelve el JSON, o lanza una excepción
  Future<dynamic> _getJson(Uri uri, {required String recurso}) async {
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
      final mensaje = body is Map ? body['mensaje'] as String? : null;
      throw ApiException(
        mensaje ?? _mensajePorCodigo(res.statusCode, recurso),
        statusCode: res.statusCode,
      );
    }
    return body;
  }

  // Convierte una lista JSON; si algún elemento no tiene el formato del contrato, lanza excepción
  static List<T> _convertirLista<T>(
    dynamic body,
    T Function(Map<String, dynamic>) convertir,
  ) {
    if (body is! List) {
      throw ApiException('Respuesta inesperada del servidor');
    }
    try {
      return [for (final item in body) convertir(item as Map<String, dynamic>)];
    } catch (_) {
      throw ApiException('Respuesta inesperada del servidor');
    }
  }

  static String _mensajePorCodigo(int codigo, String recurso) =>
      switch (codigo) {
        401 => 'Sesión expirada. Inicia sesión de nuevo',
        403 => 'No tienes permiso para ver esta información',
        404 => 'El servidor no encontró el $recurso (404)',
        _ => 'Error $codigo al obtener el resumen',
      };
}
