// Pruebas de la  Inicio de sesión y manejo de sesión.
// Usan el login simulado y SharedPreferences en memoria.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mantenimiento_universitario/data/auth_fake_repository.dart';
import 'package:mantenimiento_universitario/data/incidencias_fake_repository.dart';
import 'package:mantenimiento_universitario/data/sesion_storage.dart';
import 'package:mantenimiento_universitario/main.dart';
import 'package:mantenimiento_universitario/pages/login_page.dart';

Future<void> _abrirApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

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

Future<void> _iniciarSesion(
  WidgetTester tester,
  String correo,
  String password,
) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), correo);
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Contraseña'),
    password,
  );
  await tester.tap(find.text('Entrar'));
  await tester.pumpAndSettle();
}

String _usuarioGuardado(int id, String nombre, String correo, String rol) =>
    jsonEncode({
      'id_usuario': id,
      'nombre': nombre,
      'correo': correo,
      'rol': rol,
    });

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Validaciones del formulario', () {
    test('correo', () {
      expect(LoginPage.validarCorreo(''), 'Escribe tu correo');
      expect(LoginPage.validarCorreo('ana'), 'Escribe un correo válido');
      expect(LoginPage.validarCorreo('ana@correo'), 'Escribe un correo válido');
      expect(LoginPage.validarCorreo('ana@correo.com'), isNull);
    });

    test('contraseña', () {
      expect(LoginPage.validarPassword(''), 'Escribe tu contraseña');
      expect(
        LoginPage.validarPassword('a' * 73),
        'La contraseña es demasiado larga',
      );
      expect(LoginPage.validarPassword('Ana12345'), isNull);
    });
  });

  testWidgets('Sin sesión guardada muestra el login', (tester) async {
    await _abrirApp(tester);

    expect(find.text('Entrar'), findsOneWidget);
    expect(find.textContaining('Hola,'), findsNothing);
  });

  testWidgets('Campos vacíos muestran los errores de validación', (
    tester,
  ) async {
    await _abrirApp(tester);
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Escribe tu correo'), findsOneWidget);
    expect(find.text('Escribe tu contraseña'), findsOneWidget);
  });

  testWidgets('Credenciales incorrectas muestran el mensaje', (tester) async {
    await _abrirApp(tester);
    await _iniciarSesion(tester, 'ana@correo.com', 'incorrecta');

    expect(find.text('Correo o contraseña incorrectos'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets(
    'Login correcto guarda token y rol, y abre la pantalla principal',
    (tester) async {
      await _abrirApp(tester);
      await _iniciarSesion(tester, 'ana@correo.com', 'Ana12345');

      expect(find.text('Hola, Ana López'), findsOneWidget);
      expect(find.text('Mis incidencias'), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SesionStorage.claveToken), 'fake-token-1');
      final usuario =
          jsonDecode(prefs.getString(SesionStorage.claveUsuario)!) as Map;
      expect(usuario['rol'], 'usuario');
    },
  );

  testWidgets('Con sesión guardada entra directo a la pantalla principal', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      SesionStorage.claveToken: 'fake-token-2',
      SesionStorage.claveUsuario: _usuarioGuardado(
        2,
        'Luis Pérez',
        'luis@correo.com',
        'operador',
      ),
    });

    await _abrirApp(tester);

    expect(find.text('Entrar'), findsNothing);
    expect(find.text('Hola, Luis Pérez'), findsOneWidget);
    expect(find.text('Administración de incidencias'), findsOneWidget);
  });

  testWidgets('Sesión guardada expirada regresa al login y la borra', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      SesionStorage.claveToken: 'token-expirado',
      SesionStorage.claveUsuario: _usuarioGuardado(
        1,
        'Ana López',
        'ana@correo.com',
        'usuario',
      ),
    });

    await _abrirApp(tester);

    expect(find.text('Entrar'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SesionStorage.claveToken), isNull);
  });

  testWidgets('Cerrar sesión borra la sesión y regresa al login', (
    tester,
  ) async {
    await _abrirApp(tester);
    await _iniciarSesion(tester, 'luis@correo.com', 'Luis12345');
    expect(find.text('Hola, Luis Pérez'), findsOneWidget);

    // El botón de cerrar sesión está en el perfil
    await tester.tap(find.byTooltip('Perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();

    expect(find.text('Entrar'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SesionStorage.claveToken), isNull);
  });
}
