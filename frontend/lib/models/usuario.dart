/// Roles disponibles (docs/api.md → Convenciones → Roles).
enum Rol {
  usuario,
  operador;

  static Rol fromString(String? valor) =>
      (valor ?? '').toLowerCase() == 'operador' ? Rol.operador : Rol.usuario;

  String get etiqueta => this == Rol.operador ? 'Operador' : 'Usuario';
}

/// Usuario autenticado. Los campos siguen el contrato de la API
/// (respuesta de POST /api/auth/login → "usuario", y GET /api/auth/perfil).
class Usuario {
  const Usuario({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.rol,
    this.token,
  });

  final int id;
  final String nombre;
  final String correo;
  final Rol rol;

  /// JWT que se manda en `Authorization: Bearer <token>`.
  final String? token;

  bool get esOperador => rol == Rol.operador;

  factory Usuario.fromJson(Map<String, dynamic> json, {String? token}) =>
      Usuario(
        id: json['id_usuario'] as int,
        nombre: (json['nombre'] ?? '') as String,
        correo: (json['correo'] ?? '') as String,
        rol: Rol.fromString(json['rol'] as String?),
        token: token,
      );
}