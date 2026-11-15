import '../models/usuario.dart';
import 'auth_repository.dart';
import 'incidencias_repository.dart' show ApiException;

/// Login simulado mientras el backend no tenga /api/auth/login.
///
/// Usuarios de prueba:
///   ana@correo.com  / Ana12345  · usuario
///   luis@correo.com / Luis12345 · operador
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.demora = const Duration(milliseconds: 600)});

  final Duration demora;

  static const _usuarios = [
    (
      id: 1,
      nombre: 'Ana López',
      correo: 'ana@correo.com',
      password: 'Ana12345',
      rol: Rol.usuario,
    ),
    (
      id: 2,
      nombre: 'Luis Pérez',
      correo: 'luis@correo.com',
      password: 'Luis12345',
      rol: Rol.operador,
    ),
  ];

  static const _prefijoToken = 'fake-token-';

  @override
  Future<Usuario> login(String correo, String password) async {
    await _esperar();
    for (final u in _usuarios) {
      if (u.correo == correo.trim().toLowerCase() && u.password == password) {
        return _aUsuario(u);
      }
    }
    throw ApiException('Correo o contraseña incorrectos', statusCode: 401);
  }

  @override
  Future<Usuario> perfil(String token) async {
    await _esperar();
    final id = token.startsWith(_prefijoToken)
        ? int.tryParse(token.substring(_prefijoToken.length))
        : null;
    for (final u in _usuarios) {
      if (u.id == id) return _aUsuario(u);
    }
    throw ApiException(
      'Sesión expirada. Inicia sesión de nuevo',
      statusCode: 401,
    );
  }

  Future<void> _esperar() async {
    if (demora > Duration.zero) await Future<void>.delayed(demora);
  }

  static Usuario _aUsuario(
    ({int id, String nombre, String correo, String password, Rol rol}) u,
  ) => Usuario(
    id: u.id,
    nombre: u.nombre,
    correo: u.correo,
    rol: u.rol,
    token: '$_prefijoToken${u.id}',
  );
}
