import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/categoria.dart';
import '../models/estado_incidencia.dart';
import '../models/evidencia.dart';
import '../models/historial.dart';
import '../models/incidencia.dart';
import '../models/datos_incidencia.dart';
import '../services/servicio_imagenes.dart';

/// Error de la API con el mensaje listo para mostrarse al usuario.
class ApiException implements Exception {
  ApiException(this.mensaje, {this.statusCode, this.errores = const {}});
  final String mensaje;
  final int? statusCode;

  // Errores de validación por campo (solo en 400)
  final Map<String, String> errores;

  /// 401: falta el token, es inválido o expiró
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

  // Crea una incidencia en estado pendiente y la devuelve
  Future<Incidencia> crearIncidencia(DatosIncidencia datos);

  // Edita una incidencia pendiente del usuario y la devuelve actualizada
  Future<Incidencia> editarIncidencia(int id, DatosIncidencia datos);
  // Detalle completo de una incidencia (F9)
  Future<Incidencia> obtenerIncidencia(int id);

  // Historial de cambios, del más antiguo al más reciente (F9)
  Future<List<EntradaHistorial>> obtenerHistorial(int id);

  // Imágenes de la incidencia (F9)
  Future<List<Evidencia>> obtenerEvidencias(int id);

  // Cancela una incidencia pendiente (F9)
  Future<void> cancelarIncidencia(int id);

  // Sube fotos de la incidencia y devuelve las evidencias guardadas
  Future<List<Evidencia>> subirEvidencias(int id, List<FotoSeleccionada> fotos);
  // Solo operador: avanza o cancela una incidencia y la devuelve
  // actualizada `solucion` es obligatoria al pasar a finalizada
  Future<Incidencia> cambiarEstado(
    int id,
    EstadoIncidencia nuevoEstado, {
    String? solucion,
    String? comentario,
  });
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

  // Encabezados para enviar un cuerpo en JSON (POST y PUT)
  Map<String, String> get _headersJson => {
    ..._headers,
    'Content-Type': 'application/json',
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

  // POST /api/incidencias. Respuesta 201: el objeto incidencia
  @override
  Future<Incidencia> crearIncidencia(DatosIncidencia datos) async {
    final body = await _procesar(
      _client.post(
        Uri.parse('$baseUrl/incidencias'),
        headers: _headersJson,
        body: jsonEncode(datos.toJson()),
      ),
      recurso: 'la incidencia',
      codigoEsperado: 201,
    );
    return _convertirIncidencia(body);
  }

  // PUT /api/incidencias/:id. Respuesta 200: el objeto incidencia actualizado
  @override
  Future<Incidencia> editarIncidencia(int id, DatosIncidencia datos) async {
    final body = await _procesar(
      _client.put(
        Uri.parse('$baseUrl/incidencias/$id'),
        headers: _headersJson,
        body: jsonEncode(datos.toJson()),
      ),
      recurso: 'la incidencia',
    );
    return _convertirIncidencia(body);
  }

  // GET /api/incidencias/:id. Respuesta 200: el objeto incidencia completo
  @override
  Future<Incidencia> obtenerIncidencia(int id) async {
    final body = await _getJson(
      Uri.parse('$baseUrl/incidencias/$id'),
      recurso: 'la incidencia',
    );
    return _convertirIncidencia(body);
  }

  // GET /api/incidencias/:id/historial
  @override
  Future<List<EntradaHistorial>> obtenerHistorial(int id) async {
    final body = await _getJson(
      Uri.parse('$baseUrl/incidencias/$id/historial'),
      recurso: 'el historial',
    );
    return _convertirLista(body, EntradaHistorial.fromJson);
  }

  // GET /api/incidencias/:id/evidencias. Las URL vienen sin el host
  @override
  Future<List<Evidencia>> obtenerEvidencias(int id) async {
    final body = await _getJson(
      Uri.parse('$baseUrl/incidencias/$id/evidencias'),
      recurso: 'las evidencias',
    );
    final servidor = Uri.parse(baseUrl).origin;
    return _convertirLista(
      body,
      (json) => Evidencia.fromJson(json, servidor: servidor),
    );
  }

  // DELETE /api/incidencias/:id. Respuesta 200: { ok, mensaje, estado }
  @override
  Future<void> cancelarIncidencia(int id) async {
    await _procesar(
      _client.delete(Uri.parse('$baseUrl/incidencias/$id'), headers: _headers),
      recurso: 'la incidencia',
    );
  }

  // POST /api/incidencias/:id/evidencias
  // Respuesta 201: lista de evidencias guardadas
  @override
  Future<List<Evidencia>> subirEvidencias(
    int id,
    List<FotoSeleccionada> fotos,
  ) async {
    final peticion =
        http.MultipartRequest(
            'POST',
            Uri.parse('$baseUrl/incidencias/$id/evidencias'),
          )
          ..headers.addAll(_headers)
          ..files.addAll([
            for (final foto in fotos)
              http.MultipartFile.fromBytes(
                'imagenes',
                foto.bytes,
                filename: foto.nombre,
                contentType: MediaType.parse(foto.tipoMime),
              ),
          ]);

    final body = await _procesar(
      _client.send(peticion).then(http.Response.fromStream),
      recurso: 'las evidencias',
      codigoEsperado: 201,
      // Subir fotos tarda más que una petición normal
      tiempoMax: const Duration(seconds: 60),
    );
    final servidor = Uri.parse(baseUrl).origin;
    return _convertirLista(
      body,
      (json) => Evidencia.fromJson(json, servidor: servidor),
    );
  }

  // PATCH /api/incidencias/:id/estado. Respuesta 200: la incidencia actualizada
  @override
  Future<Incidencia> cambiarEstado(
    int id,
    EstadoIncidencia nuevoEstado, {
    String? solucion,
    String? comentario,
  }) async {
    final body = await _procesar(
      _client.patch(
        Uri.parse('$baseUrl/incidencias/$id/estado'),
        headers: _headersJson,
        body: jsonEncode({
          'estado': nuevoEstado.valorIncidencia,
          if (solucion != null && solucion.trim().isNotEmpty)
            'solucion_descripcion': solucion.trim(),
          if (comentario != null && comentario.trim().isNotEmpty)
            'comentario': comentario.trim(),
        }),
      ),
      recurso: 'la incidencia',
    );
    return _convertirIncidencia(body);
  }

  // Hace un GET y devuelve el JSON, o lanza una excepción
  Future<dynamic> _getJson(Uri uri, {required String recurso}) =>
      _procesar(_client.get(uri, headers: _headers), recurso: recurso);
  // Espera la respuesta de cualquier petición y devuelve el JSON.
  // Si el código no es el esperado, lanza ApiException con el mensaje
  // del backend y los errores por campo
  Future<dynamic> _procesar(
    Future<http.Response> peticion, {
    required String recurso,
    int codigoEsperado = 200,
    Duration tiempoMax = const Duration(seconds: 15),
  }) async {
    final http.Response res;
    try {
      res = await peticion.timeout(tiempoMax);
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

    if (res.statusCode != codigoEsperado) {
      final mensaje = body is Map ? body['mensaje'] as String? : null;
      throw ApiException(
        mensaje ?? _mensajePorCodigo(res.statusCode, recurso),
        statusCode: res.statusCode,
        errores: _leerErrores(body),
      );
    }
    return body;
  }

  // Convierte "errores" en un mapa
  static Map<String, String> _leerErrores(dynamic body) {
    final errores = body is Map ? body['errores'] : null;
    if (errores is! List) return const {};
    return {
      for (final error in errores)
        if (error is Map &&
            error['campo'] is String &&
            error['mensaje'] is String)
          error['campo'] as String: error['mensaje'] as String,
    };
  }

  // Convierte un objeto incidencia; si no tiene el formato del contrato, lanza excepción
  static Incidencia _convertirIncidencia(dynamic body) {
    try {
      return Incidencia.fromJson(body as Map<String, dynamic>);
    } catch (_) {
      throw ApiException('Respuesta inesperada del servidor');
    }
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
        403 => 'No tienes permiso para realziar esta acción',
        404 => 'El servidor no encontró el $recurso (404)',
        _ => 'Error $codigo al obtener el $recurso',
      };
}
