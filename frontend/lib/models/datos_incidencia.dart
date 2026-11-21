// Datos que captura el formulario para crear o editar una incidencia
class DatosIncidencia {
  const DatosIncidencia({
    required this.titulo,
    required this.descripcion,
    required this.idCategoria,
    this.ubicacionTexto,
  });

  final String titulo;
  final String descripcion;
  final int idCategoria;
  final String? ubicacionTexto;

  // Cuerpo de POST y PUT /api/incidencias
  Map<String, dynamic> toJson() => {
    'titulo': titulo,
    'descripcion': descripcion,
    'id_categoria': idCategoria,
    if (ubicacionTexto != null) 'ubicacion_texto': ubicacionTexto,
  };
}

// Límites del contrato
class LimitesIncidencia {
  static const tituloMin = 5;
  static const tituloMax = 150;
  static const descripcionMin = 10;
  static const descripcionMax = 2000;
  static const ubicacionMin = 3;
  static const ubicacionMax = 200;
  static const fotosMax = 5;
  static const fotoMaxBytes = 5 * 1024 * 1024;  
}
