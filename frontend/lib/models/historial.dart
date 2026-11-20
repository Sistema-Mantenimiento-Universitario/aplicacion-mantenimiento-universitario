import 'estado_incidencia.dart';
import 'incidencia.dart';

// Tipo de cambio registrado en el historial (docs/api.md -> Historial)
enum AccionHistorial {
  creacion('creacion', 'Incidencia creada'),
  edicion('edicion', 'Datos editados'),
  cambioEstado('cambio_estado', 'Cambio de estado');

  const AccionHistorial(this.valorApi, this.etiqueta);

  final String valorApi;
  final String etiqueta;

  static AccionHistorial desdeApi(String? valor) => values.firstWhere(
    (a) => a.valorApi == valor,
    orElse: () => throw FormatException('Acción desconocida: $valor'),
  );
}

// Un cambio de la incidencia: quién, cuándo y qué cambió
class EntradaHistorial {
  const EntradaHistorial({
    required this.id,
    required this.accion,
    required this.fecha,
    required this.responsable,
    this.estadoAnterior,
    this.estadoNuevo,
    this.comentario,
  });

  final int id;
  final AccionHistorial accion;
  final EstadoIncidencia? estadoAnterior;
  final EstadoIncidencia? estadoNuevo;
  final String? comentario;

  // En hora local (la API la manda en UTC)
  final DateTime fecha;
  final PersonaIncidencia responsable;

  factory EntradaHistorial.fromJson(Map<String, dynamic> json) =>
      EntradaHistorial(
        id: (json['id_historial'] as num).toInt(),
        accion: AccionHistorial.desdeApi(json['accion'] as String?),
        estadoAnterior: json['estado_anterior'] == null
            ? null
            : EstadoIncidencia.desdeApi(json['estado_anterior'] as String),
        estadoNuevo: json['estado_nuevo'] == null
            ? null
            : EstadoIncidencia.desdeApi(json['estado_nuevo'] as String),
        comentario: json['comentario'] as String?,
        fecha: DateTime.parse(json['fecha'] as String).toLocal(),
        responsable: PersonaIncidencia.fromJson(
          json['responsable'] as Map<String, dynamic>,
        ),
      );
}
