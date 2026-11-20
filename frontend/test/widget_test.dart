// Pruebas de la  Pantalla principal según el rol.
// Usan el repositorio simulado, así que no necesitan el backend.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mantenimiento_universitario/data/incidencias_fake_repository.dart';
import 'package:mantenimiento_universitario/data/incidencias_repository.dart';
import 'package:mantenimiento_universitario/models/categoria.dart';
import 'package:mantenimiento_universitario/models/estado_incidencia.dart';
import 'package:mantenimiento_universitario/models/incidencia.dart';
import 'package:mantenimiento_universitario/models/usuario.dart';
import 'package:mantenimiento_universitario/pages/home_page.dart';
import 'package:mantenimiento_universitario/theme/app_theme.dart';
import 'package:mantenimiento_universitario/models/datos_incidencia.dart';
import 'package:mantenimiento_universitario/models/evidencia.dart';
import 'package:mantenimiento_universitario/models/historial.dart';

const _ana = Usuario(
  id: 1,
  nombre: 'Ana López',
  correo: 'ana@correo.com',
  rol: Rol.usuario,
);

const _luis = Usuario(
  id: 2,
  nombre: 'Luis Pérez',
  correo: 'luis@correo.com',
  rol: Rol.operador,
);

/// Repositorio que siempre falla, para probar el estado de error.
class _RepositorioConError implements IncidenciasRepository {
  @override
  Future<Map<String, int>> obtenerResumenPorEstado() async =>
      throw ApiException('No se pudo conectar con el servidor');
  @override
  Future<List<Incidencia>> obtenerIncidencias({
    String? texto,
    EstadoIncidencia? estado,
    int? idCategoria,
  }) async => throw ApiException('No se pudo conectar con el servidor');

  @override
  Future<List<Categoria>> obtenerCategorias() async =>
      throw ApiException('No se pudo conectar con el servidor');

  @override
  Future<Incidencia> crearIncidencia(DatosIncidencia datos) async =>
      throw ApiException('No se pudo conectar con el servidor');

  @override
  Future<Incidencia> editarIncidencia(int id, DatosIncidencia datos) async =>
      throw ApiException('No se pudo conectar con el servidor');
  @override
  Future<Incidencia> obtenerIncidencia(int id) async =>
      throw ApiException('No se pudo conectar con el servidor');

  @override
  Future<List<EntradaHistorial>> obtenerHistorial(int id) async =>
      throw ApiException('No se pudo conectar con el servidor');

  @override
  Future<List<Evidencia>> obtenerEvidencias(int id) async =>
      throw ApiException('No se pudo conectar con el servidor');

  @override
  Future<void> cancelarIncidencia(int id) async =>
      throw ApiException('No se pudo conectar con el servidor');
}

Future<void> _abrirHome(
  WidgetTester tester,
  Usuario usuario,
  IncidenciasRepository repositorio,
) async {
  // Pantalla alta para que toda la lista quede visible.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.claro,
      home: HomePage(usuario: usuario, repositorio: repositorio),
    ),
  );
  await tester.pumpAndSettle();
}

FakeIncidenciasRepository _fake(Usuario u) => FakeIncidenciasRepository(
  idUsuario: u.id,
  esOperador: u.esOperador,
  demora: Duration.zero,
);

void main() {
  testWidgets('Usuario: ve su resumen y sus accesos', (tester) async {
    await _abrirHome(tester, _ana, _fake(_ana));

    expect(find.text('Hola, Ana López'), findsOneWidget);
    expect(find.text('Total: 5'), findsOneWidget);
    expect(find.text('Pendientes'), findsOneWidget);
    expect(find.text('Canceladas'), findsOneWidget);

    expect(find.text('Nueva incidencia'), findsOneWidget);
    expect(find.text('Mis incidencias'), findsOneWidget);
    expect(find.text('Administración de incidencias'), findsNothing);
  });

  testWidgets('Operador: ve todas las incidencias y la administración', (
    tester,
  ) async {
    await _abrirHome(tester, _luis, _fake(_luis));

    expect(find.text('Total: 7'), findsOneWidget);
    expect(find.text('Administración de incidencias'), findsOneWidget);
    expect(find.text('Nueva incidencia'), findsNothing);
    expect(find.text('Mis incidencias'), findsNothing);
  });

  testWidgets('Muestra el error y permite reintentar', (tester) async {
    await _abrirHome(tester, _ana, _RepositorioConError());

    expect(find.text('No se pudo conectar con el servidor'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
