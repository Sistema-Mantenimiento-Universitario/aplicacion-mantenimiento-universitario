import 'package:flutter/material.dart';

import 'data/auth_fake_repository.dart';
import 'data/auth_repository.dart';
import 'data/incidencias_fake_repository.dart';
import 'data/incidencias_repository.dart';
import 'data/sesion_controller.dart';
import 'data/sesion_storage.dart';
import 'models/usuario.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/pendiente_page.dart';
import 'pages/rutas.dart';
import 'theme/app_theme.dart';

/// URL base de la API (docs/api.md). Incluye el prefijo /api.
/// En emulador Android sería 'http://10.0.2.2:3000/api'.
const String kApiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:3000/api',
);

// TODO: cambiar defaultValue a true cuando el backend tenga
// POST /api/auth/login y GET /api/incidencias/resumen.
/// false → datos simulados. true → backend real:
///   `flutter run -d chrome --dart-define=API_REAL=true`
const bool kUsarApiReal = bool.fromEnvironment('API_REAL', defaultValue: false);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    this.authRepository,
    this.sesionStorage,
    this.crearIncidenciasRepository,
  });

  /// Permiten inyectar dependencias (las usan las pruebas).
  final AuthRepository? authRepository;
  final SesionStorage? sesionStorage;
  final IncidenciasRepository Function(Usuario usuario)?
  crearIncidenciasRepository;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final SesionController _sesion;

  @override
  void initState() {
    super.initState();
    _sesion = SesionController(
      auth:
          widget.authRepository ??
          (kUsarApiReal
              ? ApiAuthRepository(baseUrl: kApiBaseUrl)
              : FakeAuthRepository()),
      storage: widget.sesionStorage ?? SesionStorage(),
    )..iniciar();
  }

  @override
  void dispose() {
    _sesion.dispose();
    super.dispose();
  }

  /// El token de la sesión se envía en las peticiones protegidas.
  IncidenciasRepository _incidenciasPara(Usuario usuario) =>
      widget.crearIncidenciasRepository?.call(usuario) ??
      (kUsarApiReal
          ? ApiIncidenciasRepository(baseUrl: kApiBaseUrl, token: usuario.token)
          : FakeIncidenciasRepository(
              idUsuario: usuario.id,
              esOperador: usuario.esOperador,
            ));

  Widget _pantallaInicial() {
    switch (_sesion.estado) {
      case EstadoSesion.cargando:
        return const _PantallaCarga();
      case EstadoSesion.sinSesion:
        return LoginPage(onIniciarSesion: _sesion.iniciarSesion);
      case EstadoSesion.conSesion:
        final usuario = _sesion.usuario!;
        return HomePage(
          key: ValueKey(usuario.id),
          usuario: usuario,
          repositorio: _incidenciasPara(usuario),
          onCerrarSesion: _sesion.cerrarSesion,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: modoTema,
      builder: (context, modo, _) => MaterialApp(
        title: 'Mantenimiento universitario',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.claro,
        darkTheme: AppTheme.oscuro,
        themeMode: modo,
        // La raíz escucha la sesión: login, carga o pantalla principal.
        home: ListenableBuilder(
          listenable: _sesion,
          builder: (context, _) => _pantallaInicial(),
        ),
        routes: {
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

class _PantallaCarga extends StatelessWidget {
  const _PantallaCarga();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
