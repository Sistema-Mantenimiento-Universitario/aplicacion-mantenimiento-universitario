// Datos que captura el formulario para crear o editar una incidencia
class DatosIncidencia {
  const DatosIncidencia({
    required this.titulo,
    required this.descripcion,
    required this.idCategoria,
    this.ubicacionTexto,
    this.latitud,
    this.longitud,
  });

  final String titulo;
  final String descripcion;
  final int idCategoria;
  final String? ubicacionTexto;

  // Coordenadas del GPS o escritas a mano
  final double? latitud;
  final double? longitud;

  bool get tieneCoordenadas => latitud != null && longitud != null;

  // Al menos una forma de ubicación ya sea en texto o coordenadas
  bool get tieneUbicacion =>
      (ubicacionTexto ?? '').isNotEmpty || tieneCoordenadas;

  // Cuerpo de POST y PUT /api/incidencias
  Map<String, dynamic> toJson() => {
    'titulo': titulo,
    'descripcion': descripcion,
    'id_categoria': idCategoria,
    if (ubicacionTexto != null) 'ubicacion_texto': ubicacionTexto,
    if (tieneCoordenadas) ...{'latitud': latitud, 'longitud': longitud},
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
  static const latitudMax = 90.0;
  static const longitudMax = 180.0;
}
