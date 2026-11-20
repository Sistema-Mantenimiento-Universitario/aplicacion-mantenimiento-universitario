import 'categoria.dart';
import 'estado_incidencia.dart';

// Usuario relacionado con una incidencia (el que reporta o el operador que la atiende
class PersonaIncidencia {
  const PersonaIncidencia({required this.id, required this.nombre});

  final int id;
  final String nombre;

  factory PersonaIncidencia.fromJson(Map<String, dynamic> json) =>
      PersonaIncidencia(
        id: (json['id_usuario'] as num).toInt(),
        nombre: (json['nombre'] ?? '') as String,
      );
}

class Incidencia {
  const Incidencia({
    required this.id,
    required this.titulo,
    required this.estado,
    required this.categoria,
    required this.reportadoPor,
    required this.fechaCreacion,
    this.operador,
    this.descripcion,
    this.ubicacionTexto,
    this.latitud,
    this.longitud,
    this.solucionDescripcion,
    this.fechaActualizacion,
    this.fechaFinalizacion,
  });

  final int id;
  final String titulo;
  final EstadoIncidencia estado;
  final Categoria categoria;
  final PersonaIncidencia reportadoPor;

  // null mientras la incidencia no tiene operador asignado
  final PersonaIncidencia? operador;
  final String? descripcion;
  final String? ubicacionTexto;

  // En hora local (la API la manda en UTC).
  final DateTime fechaCreacion;

  // Solo vienen en el detalle (GET /api/incidencias/:id)
  final double? latitud;
  final double? longitud;
  final String? solucionDescripcion;
  final DateTime? fechaActualizacion;
  final DateTime? fechaFinalizacion;

  bool get tieneCoordenadas => latitud != null && longitud != null;

  // Copia con otro estado (la usa el repositorio simulado)
  Incidencia conEstado(EstadoIncidencia nuevoEstado) => Incidencia(
    id: id,
    titulo: titulo,
    estado: nuevoEstado,
    categoria: categoria,
    reportadoPor: reportadoPor,
    fechaCreacion: fechaCreacion,
    operador: operador,
    descripcion: descripcion,
    ubicacionTexto: ubicacionTexto,
    latitud: latitud,
    longitud: longitud,
    solucionDescripcion: solucionDescripcion,
    fechaActualizacion: DateTime.now(),
    fechaFinalizacion: fechaFinalizacion,
  );

  factory Incidencia.fromJson(Map<String, dynamic> json) => Incidencia(
    id: (json['id_incidencia'] as num).toInt(),
    titulo: (json['titulo'] ?? '') as String,
    estado: EstadoIncidencia.desdeApi(json['estado'] as String?),
    categoria: Categoria.fromJson(json['categoria'] as Map<String, dynamic>),
    reportadoPor: PersonaIncidencia.fromJson(
      json['reportado_por'] as Map<String, dynamic>,
    ),
    operador: json['operador'] == null
        ? null
        : PersonaIncidencia.fromJson(json['operador'] as Map<String, dynamic>),
    descripcion: json['descripcion'] as String?,
    ubicacionTexto: json['ubicacion_texto'] as String?,
    fechaCreacion: DateTime.parse(json['fecha_creacion'] as String).toLocal(),
    latitud: (json['latitud'] as num?)?.toDouble(),
    longitud: (json['longitud'] as num?)?.toDouble(),
    solucionDescripcion: json['solucion_descripcion'] as String?,
    fechaActualizacion: _fecha(json['fecha_actualizacion']),
    fechaFinalizacion: _fecha(json['fecha_finalizacion']),
  );

  static DateTime? _fecha(Object? valor) =>
      valor is String ? DateTime.parse(valor).toLocal() : null;
}
