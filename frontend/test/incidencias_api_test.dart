// Pruebas del repositorio real con un servidor simulado
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mantenimiento_universitario/data/incidencias_repository.dart';
import 'package:mantenimiento_universitario/models/datos_incidencia.dart';
import 'package:mantenimiento_universitario/services/servicio_imagenes.dart';

const _datos = DatosIncidencia(
  titulo: 'Lámpara fundida en el pasillo',
  descripcion: 'La lámpara del pasillo no enciende desde el lunes.',
  idCategoria: 2,
  ubicacionTexto: 'Edificio 3, planta baja',
);

// Objeto incidencia como lo devuelve el backend
const _respuesta = {
  'id_incidencia': 12,
  'titulo': 'Lámpara fundida en el pasillo',
  'descripcion': 'La lámpara del pasillo no enciende desde el lunes.',
  'estado': 'pendiente',
  'categoria': {'id_categoria': 2, 'nombre': 'Electricidad'},
  'reportado_por': {'id_usuario': 5, 'nombre': 'Ana López'},
  'operador': null,
  'ubicacion_texto': 'Edificio 3, planta baja',
  'fecha_creacion': '2026-11-11T15:30:00.000Z',
};

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
  test('Crear: manda POST con el token y el cuerpo del contrato', () async {
    late http.Request enviada;
    final repositorio = _repositorio(
      MockClient((peticion) async {
        enviada = peticion;
        return _json(_respuesta, 201);
      }),
    );

    final incidencia = await repositorio.crearIncidencia(_datos);

    expect(enviada.method, 'POST');
    expect(enviada.url.toString(), 'http://servidor/api/incidencias');
    expect(enviada.headers['Authorization'], 'Bearer abc');
    expect(jsonDecode(enviada.body), {
      'titulo': 'Lámpara fundida en el pasillo',
      'descripcion': 'La lámpara del pasillo no enciende desde el lunes.',
      'id_categoria': 2,
      'ubicacion_texto': 'Edificio 3, planta baja',
    });
    expect(incidencia.id, 12);
  });

  test('Con coordenadas, las manda junto con la ubicación en texto', () async {
    late http.Request enviada;
    final repositorio = _repositorio(
      MockClient((peticion) async {
        enviada = peticion;
        return _json(_respuesta, 201);
      }),
    );

    await repositorio.crearIncidencia(
      const DatosIncidencia(
        titulo: 'Lámpara fundida en el pasillo',
        descripcion: 'La lámpara del pasillo no enciende desde el lunes.',
        idCategoria: 2,
        latitud: 21.913600,
        longitud: -102.315800,
      ),
    );

    final cuerpo = jsonDecode(enviada.body) as Map<String, dynamic>;
    expect(cuerpo['latitud'], 21.9136);
    expect(cuerpo['longitud'], -102.3158);
    // Sin texto no se manda la clave
    expect(cuerpo.containsKey('ubicacion_texto'), isFalse);
  });

  test('Editar: manda PUT a /incidencias/:id', () async {
    late http.Request enviada;
    final repositorio = _repositorio(
      MockClient((peticion) async {
        enviada = peticion;
        return _json(_respuesta, 200);
      }),
    );

    await repositorio.editarIncidencia(12, _datos);

    expect(enviada.method, 'PUT');
    expect(enviada.url.path, '/api/incidencias/12');
  });

  test('Fotos: manda multipart con el campo imagenes y su tipo', () async {
    late http.Request enviada;
    final repositorio = _repositorio(
      MockClient((peticion) async {
        enviada = peticion;
        return _json([
          {
            'id_evidencia': 7,
            'tipo': 'reporte',
            'url': '/uploads/evidencias/abc.jpg',
            'nombre_original': 'lampara.jpg',
            'mime_type': 'image/jpeg',
            'fecha_subida': '2026-11-11T15:31:00.000Z',
          },
        ], 201);
      }),
    );

    final evidencias = await repositorio.subirEvidencias(12, [
      FotoSeleccionada(
        nombre: 'lampara.jpg',
        bytes: Uint8List.fromList([1, 2, 3]),
        tipoMime: 'image/jpeg',
      ),
    ]);

    expect(enviada.method, 'POST');
    expect(enviada.url.path, '/api/incidencias/12/evidencias');
    expect(enviada.headers['Authorization'], 'Bearer abc');
    expect(enviada.headers['content-type'], startsWith('multipart/form-data'));
    // Cada foto va en el campo "imagenes" con su nombre y su tipo
    final cuerpo = latin1.decode(enviada.bodyBytes);
    expect(cuerpo, contains('name="imagenes"; filename="lampara.jpg"'));
    expect(cuerpo, contains('content-type: image/jpeg'));
    // La URL de la evidencia se completa con el host del servidor
    expect(evidencias.single.url, 'http://servidor/uploads/evidencias/abc.jpg');
  });

  test('Un 400 trae el mensaje y los errores por campo', () async {
    final repositorio = _repositorio(
      MockClient(
        (_) async => _json({
          'ok': false,
          'mensaje': 'Datos inválidos',
          'errores': [
            {'campo': 'titulo', 'mensaje': 'El título es obligatorio'},
          ],
        }, 400),
      ),
    );

    await expectLater(
      repositorio.crearIncidencia(_datos),
      throwsA(
        isA<ApiException>()
            .having((e) => e.mensaje, 'mensaje', 'Datos inválidos')
            .having((e) => e.errores, 'errores', {
              'titulo': 'El título es obligatorio',
            }),
      ),
    );
  });
}
