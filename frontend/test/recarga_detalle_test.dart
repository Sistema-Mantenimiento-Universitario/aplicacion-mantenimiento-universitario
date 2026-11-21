// Recargar la página (F5 en web) estando en el detalle o en editar:
// el id viene en la URL y la pantalla se vuelve a abrir con sus datos
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mantenimiento_universitario/data/auth_fake_repository.dart';
import 'package:mantenimiento_universitario/data/incidencias_fake_repository.dart';
import 'package:mantenimiento_universitario/data/sesion_storage.dart';
import 'package:mantenimiento_universitario/main.dart';
import 'package:mantenimiento_universitario/pages/rutas.dart';

// Abre la app directamente en una ruta, como al recargar el navegador
Future<void> _abrirAppEn(WidgetTester tester, String ruta) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  tester.binding.platformDispatcher.defaultRouteNameTestValue = ruta;
  addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);

  await tester.pumpWidget(
    MyApp(
      authRepository: FakeAuthRepository(demora: Duration.zero),
      sesionStorage: SesionStorage(),
      crearIncidenciasRepository: (u) => FakeIncidenciasRepository(
        idUsuario: u.id,
        esOperador: u.esOperador,
        demora: Duration.zero,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // Sesión guardada de Ana (usuario)
  setUp(() {
    SharedPreferences.setMockInitialValues({
      SesionStorage.claveToken: 'fake-token-1',
      SesionStorage.claveUsuario: jsonEncode({
        'id_usuario': 1,
        'nombre': 'Ana López',
        'correo': 'ana@correo.com',
        'rol': 'usuario',
      }),
    });
  });

  testWidgets('Recargar en el detalle vuelve a mostrar la incidencia', (
    tester,
  ) async {
    await _abrirAppEn(tester, Rutas.detalle(1));

    expect(find.text('Detalle de incidencia'), findsOneWidget);
    expect(find.text('Lámpara fundida en el pasillo'), findsOneWidget);
    expect(find.text('Estado actual'), findsOneWidget);
    expect(find.text('Pantalla en construcción'), findsNothing);
  });

  testWidgets('Recargar en editar abre la misma incidencia en edición', (
    tester,
  ) async {
    await _abrirAppEn(tester, Rutas.editar(1));

    expect(find.text('Editar incidencia'), findsOneWidget);
    expect(find.text('Guardar cambios'), findsOneWidget);
    expect(find.text('Crear incidencia'), findsNothing);
    // El título ya viene escrito en el campo
    expect(
      find.widgetWithText(TextFormField, 'Lámpara fundida en el pasillo'),
      findsOneWidget,
    );
  });

  testWidgets('Editar sin id no abre el formulario de nueva incidencia', (
    tester,
  ) async {
    await _abrirAppEn(tester, Rutas.editarIncidencia);

    expect(find.text('Incidencia no indicada'), findsOneWidget);
    expect(find.text('Crear incidencia'), findsNothing);
  });

  testWidgets('Detalle sin id muestra un aviso', (tester) async {
    await _abrirAppEn(tester, Rutas.detalleIncidencia);

    expect(find.text('Incidencia no indicada'), findsOneWidget);
    expect(find.text('Pantalla en construcción'), findsNothing);
  });

  testWidgets('Detalle de una incidencia que no existe muestra el error', (
    tester,
  ) async {
    await _abrirAppEn(tester, Rutas.detalle(999));

    expect(find.text('Incidencia no encontrada'), findsOneWidget);
  });
}
