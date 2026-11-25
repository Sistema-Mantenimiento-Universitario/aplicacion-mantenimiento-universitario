// Pruebas de PATCH /api/incidencias/:id/estado con un servidor simulado
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mantenimiento_universitario/data/incidencias_repository.dart';
import 'package:mantenimiento_universitario/models/estado_incidencia.dart';

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

Map<String, dynamic> _incidencia(String estado) => {
  'id_incidencia': 12,
  'titulo': 'Lámpara fundida en el pasillo',
  'estado': estado,
  'categoria': {'id_categoria': 2, 'nombre': 'Electricidad'},
  'reportado_por': {'id_usuario': 5, 'nombre': 'Ana López'},
  'operador': {'id_usuario': 2, 'nombre': 'Luis Pérez'},
  'solucion_descripcion': estado == 'finalizada'
      ? 'Se cambió la lámpara y se revisó el balastro.'
      : null,
  'fecha_creacion': '2026-11-11T15:30:00.000Z',
};

void main() {
  test('Manda PATCH con el estado, la solución y el comentario', () async {
    late http.Request enviada;
    final repositorio = _repositorio(
      MockClient((peticion) async {
        enviada = peticion;
        return _json(_incidencia('finalizada'), 200);
      }),
    );

    final incidencia = await repositorio.cambiarEstado(
      12,
      EstadoIncidencia.finalizada,
      solucion: '  Se cambió la lámpara y se revisó el balastro.  ',
      comentario: 'Trabajo concluido',
    );

    expect(enviada.method, 'PATCH');
    expect(enviada.url.path, '/api/incidencias/12/estado');
    expect(enviada.headers['Authorization'], 'Bearer abc');
    expect(jsonDecode(enviada.body), {
      'estado': 'finalizada',
      'solucion_descripcion': 'Se cambió la lámpara y se revisó el balastro.',
      'comentario': 'Trabajo concluido',
    });
    expect(incidencia.estado, EstadoIncidencia.finalizada);
    expect(incidencia.solucionDescripcion, isNotNull);
  });

  test('Sin solución ni comentario solo manda el estado', () async {
    late http.Request enviada;
    final repositorio = _repositorio(
      MockClient((peticion) async {
        enviada = peticion;
        return _json(_incidencia('asignada'), 200);
      }),
    );

    await repositorio.cambiarEstado(12, EstadoIncidencia.asignada);

    expect(jsonDecode(enviada.body), {'estado': 'asignada'});
  });

  test('Transición no permitida: muestra el mensaje del backend', () async {
    final repositorio = _repositorio(
      MockClient(
        (_) async => _json({
          'ok': false,
          'mensaje': "Transición no permitida: de 'pendiente' a 'finalizada'",
        }, 400),
      ),
    );

    await expectLater(
      repositorio.cambiarEstado(12, EstadoIncidencia.finalizada),
      throwsA(
        isA<ApiException>()
            .having(
              (e) => e.mensaje,
              'mensaje',
              "Transición no permitida: de 'pendiente' a 'finalizada'",
            )
            .having((e) => e.statusCode, 'statusCode', 400),
      ),
    );
  });

  test('403 si el rol no es operador', () async {
    final repositorio = _repositorio(
      MockClient(
        (_) async => _json({
          'ok': false,
          'mensaje': 'No tienes permiso para realizar esta acción',
        }, 403),
      ),
    );

    await expectLater(
      repositorio.cambiarEstado(12, EstadoIncidencia.asignada),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'código', 403)),
    );
  });
}
