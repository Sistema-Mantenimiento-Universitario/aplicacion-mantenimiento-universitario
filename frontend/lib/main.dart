import 'package:flutter/material.dart';

import 'data/auth_fake_repository.dart';
import 'data/preferencias_storage.dart';
import 'data/auth_repository.dart';
import 'data/incidencias_fake_repository.dart';
import 'data/incidencias_repository.dart';
import 'data/sesion_controller.dart';
import 'data/sesion_storage.dart';
import 'models/incidencia.dart';
import 'models/usuario.dart';
import 'pages/formulario_incidencia_page.dart';
import 'pages/home_page.dart';
import 'pages/listado_incidencias_page.dart';
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
// POST /api/auth/login, GET /api/incidencias/resumen,
// GET /api/incidencias y GET /api/categorias,
// POST /api/incidencias y PUT /api/incidencias/:id.
/// false: datos simulados. true backend real:
///   `flutter run -d chrome --dart-define=API_REAL=true`
const bool kUsarApiReal = bool.fromEnvironment('API_REAL', defaultValue: false);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Carga el tema guardado antes de mostrar la app
  await iniciarPreferenciaTema();
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

  // Las rutas internas escuchan la sesión. Al recargar la página en web,
  // la sesión todavía se está leyendo y la pantalla se actualiza al terminar
  Widget _conSesion(Widget Function(Usuario usuario) pantalla) {
    return ListenableBuilder(
      listenable: _sesion,
      builder: (context, _) => switch (_sesion.estado) {
        EstadoSesion.cargando => const _PantallaCarga(),
        EstadoSesion.sinSesion => LoginPage(
          onIniciarSesion: _sesion.iniciarSesion,
        ),
        EstadoSesion.conSesion => pantalla(_sesion.usuario!),
      },
    );
  }
  // Listado con el repositorio y el token de la sesión actual
  Widget _listado() => _conSesion((usuario) => ListadoIncidenciasPage(
      usuario: usuario,
      repositorio: _incidenciasPara(usuario),
      onSesionExpirada: _sesion.cerrarSesion,
    ),
  );

  // Si la ruta recibe una Incidencia se abre en modo edición
  Widget _formulario(BuildContext context) {
    final argumento = ModalRoute.of(context)?.settings.arguments;
    return _conSesion((usuario) => FormularioIncidenciaPage(
      usuario: usuario,
      repositorio: _incidenciasPara(usuario),
      incidencia: argumento is Incidencia ? argumento : null,
      onSesionExpirada: _sesion.cerrarSesion,
      ),
    );
  }

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
          Rutas.nuevaIncidencia: _formulario,
          Rutas.editarIncidencia: _formulario,
          Rutas.misIncidencias: (_) => _listado(),
          Rutas.detalleIncidencia: (_) =>
              const PendientePage(titulo: 'Detalle de incidencia'),
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
