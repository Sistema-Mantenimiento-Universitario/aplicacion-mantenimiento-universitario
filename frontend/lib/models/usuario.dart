/// Roles disponibles en la aplicación.
enum Rol {
  usuario,
  operador;

  static Rol fromString(String? valor) =>
      (valor ?? '').toLowerCase() == 'operador' ? Rol.operador : Rol.usuario;

  String get etiqueta => this == Rol.operador ? 'Operador' : 'Usuario';
}

/// Usuario autenticado (normalmente se obtiene tras el login).
class Usuario {
  const Usuario({
    required this.id,
    required this.nombre,
    required this.rol,
    this.token,
  });

  final int id;
  final String nombre;
  final Rol rol;
  final String? token;

  bool get esOperador => rol == Rol.operador;

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
        id: json['id'] as int,
        nombre: (json['nombre'] ?? '') as String,
        rol: Rol.fromString(json['rol'] as String?),
        token: json['token'] as String?,
      );
}