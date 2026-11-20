// Pruebas de los endpoints de la F9 con un servidor simulado
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mantenimiento_universitario/data/incidencias_repository.dart';
import 'package:mantenimiento_universitario/models/estado_incidencia.dart';
import 'package:mantenimiento_universitario/models/historial.dart';

http.Response _json(Object cuerpo, int codigo) => http.Response(
  jsonEncode(cuerpo),
  codigo,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

ApiIncidenciasRepository _repositorio(MockClient cliente) =>
    ApiIncidenciasRepository(
      baseUrl: 'http://servidor/api',
      token: 'abc',
      client: cliente,
    );

void main() {
  test('Detalle: GET /incidencias/:id con coordenadas y solución', () async {
    late http.Request enviada;
    final repositorio = _repositorio(
      MockClient((peticion) async {
        enviada = peticion;
        return _json({
          'id_incidencia': 12,
          'titulo': 'Lámpara fundida en el pasillo',
          'descripcion': 'No enciende desde el lunes.',
          'estado': 'finalizada',
          'categoria': {'id_categoria': 2, 'nombre': 'Electricidad'},
          'reportado_por': {'id_usuario': 5, 'nombre': 'Ana López'},
          'operador': {'id_usuario': 2, 'nombre': 'Luis Pérez'},
          'ubicacion_texto': 'Edificio 3',
          'latitud': 21.912345,
          'longitud': -102.296789,
          'solucion_descripcion': 'Se cambió la lámpara.',
          'fecha_creacion': '2026-11-11T15:30:00.000Z',
          'fecha_actualizacion': '2026-11-12T10:00:00.000Z',
          'fecha_finalizacion': '2026-11-12T10:00:00.000Z',
        }, 200);
      }),
    );

    final incidencia = await repositorio.obtenerIncidencia(12);

    expect(enviada.method, 'GET');
    expect(enviada.url.path, '/api/incidencias/12');
    expect(enviada.headers['Authorization'], 'Bearer abc');
    expect(incidencia.estado, EstadoIncidencia.finalizada);
    expect(incidencia.latitud, 21.912345);
    expect(incidencia.longitud, -102.296789);
    expect(incidencia.solucionDescripcion, 'Se cambió la lámpara.');
    expect(incidencia.fechaFinalizacion, isNotNull);
  });

  test('Historial: GET /incidencias/:id/historial', () async {
    late http.Request enviada;
    final repositorio = _repositorio(
      MockClient((peticion) async {
        enviada = peticion;
        return _json([
          {
            'id_historial': 30,
            'accion': 'creacion',
            'estado_anterior': null,
            'estado_nuevo': 'pendiente',
            'comentario': null,
            'fecha': '2026-11-11T15:30:00.000Z',
            'responsable': {'id_usuario': 5, 'nombre': 'Ana López'},
          },
          {
            'id_historial': 31,
            'accion': 'cambio_estado',
            'estado_anterior': 'pendiente',
            'estado_nuevo': 'asignada',
            'comentario': null,
            'fecha': '2026-11-12T09:10:00.000Z',
            'responsable': {'id_usuario': 2, 'nombre': 'Luis Pérez'},
          },
        ], 200);
      }),
    );

    final historial = await repositorio.obtenerHistorial(12);

    expect(enviada.url.path, '/api/incidencias/12/historial');
    expect(historial, hasLength(2));
    expect(historial[1].accion, AccionHistorial.cambioEstado);
    expect(historial[1].estadoAnterior, EstadoIncidencia.pendiente);
    expect(historial[1].estadoNuevo, EstadoIncidencia.asignada);
    expect(historial[1].responsable.nombre, 'Luis Pérez');
  });

  test('Evidencias: la URL se completa con el host del servidor', () async {
    late http.Request enviada;
    final repositorio = _repositorio(
      MockClient((peticion) async {
        enviada = peticion;
        return _json([
          {
            'id_evidencia': 7,
            'tipo': 'reporte',
            'url': '/uploads/evidencias/3f9c1a2e.jpg',
            'nombre_original': 'lampara.jpg',
            'mime_type': 'image/jpeg',
            'fecha_subida': '2026-11-11T15:31:00.000Z',
          },
        ], 200);
      }),
    );

    final evidencias = await repositorio.obtenerEvidencias(12);

    expect(enviada.url.path, '/api/incidencias/12/evidencias');
    expect(
      evidencias.single.url,
      'http://servidor/uploads/evidencias/3f9c1a2e.jpg',
    );
    expect(evidencias.single.etiquetaTipo, 'Reporte');
  });

  test('Cancelar: manda DELETE a /incidencias/:id', () async {
    late http.Request enviada;
    final repositorio = _repositorio(
      MockClient((peticion) async {
        enviada = peticion;
        return _json({
          'ok': true,
          'mensaje': 'Incidencia cancelada',
          'estado': 'cancelada',
        }, 200);
      }),
    );

    await repositorio.cancelarIncidencia(12);

    expect(enviada.method, 'DELETE');
    expect(enviada.url.path, '/api/incidencias/12');
  });

  test(
    'Cancelar una que no está pendiente muestra el mensaje del backend',
    () async {
      final repositorio = _repositorio(
        MockClient(
          (_) async => _json({
            'ok': false,
            'mensaje': 'Solo se puede cancelar una incidencia pendiente',
          }, 400),
        ),
      );

      await expectLater(
        repositorio.cancelarIncidencia(12),
        throwsA(
          isA<ApiException>().having(
            (e) => e.mensaje,
            'mensaje',
            'Solo se puede cancelar una incidencia pendiente',
          ),
        ),
      );
    },
  );
}
