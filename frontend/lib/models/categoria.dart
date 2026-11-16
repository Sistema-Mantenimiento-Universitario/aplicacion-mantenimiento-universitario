// Categoría de una incidencia
class Categoria {
  const Categoria({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.activa = true,
  });

  final int id;
  final String nombre;
  final String? descripcion;
  final bool activa;

  factory Categoria.fromJson(Map<String, dynamic> json) => Categoria(
    id: (json['id_categoria'] as num).toInt(),
    nombre: (json['nombre'] ?? '') as String,
    descripcion: json['descripcion'] as String?,

    activa:
        json['activa'] == null || json['activa'] == true || json['activa'] == 1,
  );
}
