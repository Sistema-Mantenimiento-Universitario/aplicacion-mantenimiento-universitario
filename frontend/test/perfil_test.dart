// Pruebas de la Pantalla de perfil y configuración.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mantenimiento_universitario/data/preferencias_storage.dart';
import 'package:mantenimiento_universitario/models/usuario.dart';
import 'package:mantenimiento_universitario/pages/perfil_page.dart';
import 'package:mantenimiento_universitario/theme/app_theme.dart';

const _luis = Usuario(
  id: 2,
  nombre: 'Luis Pérez',
  correo: 'luis@correo.com',
  rol: Rol.operador,
);

Future<void> _abrirPerfil(
  WidgetTester tester, {
  VoidCallback? onCerrarSesion,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.claro,
      home: PerfilPage(usuario: _luis, onCerrarSesion: onCerrarSesion ?? () {}),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    modoTema.value = ThemeMode.system;
  });

  testWidgets('Muestra nombre, correo y rol del usuario', (tester) async {
    await _abrirPerfil(tester);

    expect(find.text('Luis Pérez'), findsWidgets);
    expect(find.text('luis@correo.com'), findsOneWidget);
    expect(find.text('Operador'), findsOneWidget);
  });

  testWidgets('Cambiar el tema lo guarda en el dispositivo', (tester) async {
    await iniciarPreferenciaTema();
    await _abrirPerfil(tester);

    await tester.tap(find.text('Oscuro'));
    await tester.pumpAndSettle();

    expect(modoTema.value, ThemeMode.dark);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PreferenciasStorage.claveTema), 'dark');
  });

  test('El tema guardado se carga al iniciar', () async {
    SharedPreferences.setMockInitialValues({
      PreferenciasStorage.claveTema: 'light',
    });

    await iniciarPreferenciaTema();

    expect(modoTema.value, ThemeMode.light);
  });

  testWidgets('Cerrar sesión pide confirmación', (tester) async {
    var cerroSesion = false;
    await _abrirPerfil(tester, onCerrarSesion: () => cerroSesion = true);

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cerrar sesión?'), findsOneWidget);

    // Cancelar no cierra la sesión
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(cerroSesion, isFalse);

    // Salir sí la cierra
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();
    expect(cerroSesion, isTrue);
  });
}
