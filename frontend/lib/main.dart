import 'package:flutter/material.dart';

import 'data/incidencias_fake_repository.dart';
import 'data/incidencias_repository.dart';
import 'models/usuario.dart';
import 'pages/home_page.dart';
import 'pages/pendiente_page.dart';
import 'pages/rutas.dart';
import 'theme/app_theme.dart';

/// URL base de la API (docs/api.md). Incluye el prefijo /api.
/// En emulador Android sería 'http://10.0.2.2:3000/api'.
const String kApiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:3000/api',
);

/// false → datos simulados. true → backend real:
///   `flutter run -d chrome --dart-define=API_REAL=true --dart-define=API_TOKEN=TU_TOKEN`
const bool kUsarApiReal = bool.fromEnvironment('API_REAL');

/// JWT de prueba mientras no exista la pantalla de login.
const String kTokenPrueba = String.fromEnvironment('API_TOKEN');

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.repositorio});

  /// Permite inyectar otro repositorio (lo usan las pruebas).
  final IncidenciasRepository? repositorio;

  // TODO: reemplazar por el usuario que devuelve POST /api/auth/login.
  // Para probar la vista del operador: id 2, Luis Pérez, Rol.operador.
  static const Usuario usuarioDemo = Usuario(
    id: 1,
    nombre: 'Ana López',
    correo: 'ana@correo.com',
    rol: Rol.usuario,
    token: kTokenPrueba,
  );

  @override
  Widget build(BuildContext context) {
    final IncidenciasRepository repo = repositorio ??
        (kUsarApiReal
            ? ApiIncidenciasRepository(
                baseUrl: kApiBaseUrl,
                token: usuarioDemo.token,
              )
            : FakeIncidenciasRepository(
                idUsuario: usuarioDemo.id,
                esOperador: usuarioDemo.esOperador,
              ));

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: modoTema,
      builder: (context, modo, _) => MaterialApp(
        title: 'Mantenimiento universitario',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.claro,
        darkTheme: AppTheme.oscuro,
        themeMode: modo,
        initialRoute: Rutas.inicio,
        routes: {
          Rutas.inicio: (_) =>
              HomePage(usuario: usuarioDemo, repositorio: repo),
          // Sustituye estas pantallas provisionales por las reales:
          Rutas.nuevaIncidencia: (_) =>
              const PendientePage(titulo: 'Nueva incidencia'),
          Rutas.misIncidencias: (_) =>
              const PendientePage(titulo: 'Mis incidencias'),
          Rutas.adminIncidencias: (_) =>
              const PendientePage(titulo: 'Administración de incidencias'),
        },
      ),
    );
  }
}