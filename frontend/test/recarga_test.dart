// Pruebas de lo que pasa al recargar la página en web estando en una
// ruta interna: la app abre esa ruta mientras la sesión todavía se lee
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
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Con sesión guardada, al recargar se muestra el formulario', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      SesionStorage.claveToken: 'fake-token-1',
      SesionStorage.claveUsuario: jsonEncode({
        'id_usuario': 1,
        'nombre': 'Ana López',
        'correo': 'ana@correo.com',
        'rol': 'usuario',
      }),
    });

    await _abrirAppEn(tester, Rutas.nuevaIncidencia);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Crear incidencia'), findsOneWidget);
  });

  testWidgets('Con sesión guardada, al recargar se muestra el listado', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      SesionStorage.claveToken: 'fake-token-1',
      SesionStorage.claveUsuario: jsonEncode({
        'id_usuario': 1,
        'nombre': 'Ana López',
        'correo': 'ana@correo.com',
        'rol': 'usuario',
      }),
    });

    await _abrirAppEn(tester, Rutas.misIncidencias);

    expect(find.text('Mis incidencias'), findsOneWidget);
    expect(find.text('Lámpara fundida en el pasillo'), findsOneWidget);
  });

  testWidgets('Sin sesión, al recargar pide iniciar sesión y luego sigue', (
    tester,
  ) async {
    await _abrirAppEn(tester, Rutas.nuevaIncidencia);

    expect(find.text('Entrar'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo'),
      'ana@correo.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      'Ana12345',
    );
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Crear incidencia'), findsOneWidget);
  });
}