import 'estado_incidencia.dart';

// Flujo permitido (docs/api.md -> Cambio de estado):
//   pendiente -> asignada -> en_proceso -> finalizada
//   pendiente -> cancelada
extension TransicionesEstado on EstadoIncidencia {
  // Siguiente estado del flujo normal (null si ya no avanza)
  EstadoIncidencia? get siguiente => switch (this) {
    EstadoIncidencia.pendiente => EstadoIncidencia.asignada,
    EstadoIncidencia.asignada => EstadoIncidencia.enProceso,
    EstadoIncidencia.enProceso => EstadoIncidencia.finalizada,
    EstadoIncidencia.finalizada || EstadoIncidencia.cancelada => null,
  };

  // Estados a los que el operador puede mover la incidencia
  List<EstadoIncidencia> get permitidos => [
    ?siguiente,
    if (this == EstadoIncidencia.pendiente) EstadoIncidencia.cancelada,
  ];

  bool puedePasarA(EstadoIncidencia destino) => permitidos.contains(destino);

  // Texto del botón o gesto que lleva a este estado
  String get accion => switch (this) {
    EstadoIncidencia.asignada => 'Asignarme',
    EstadoIncidencia.enProceso => 'Iniciar atención',
    EstadoIncidencia.finalizada => 'Finalizar',
    EstadoIncidencia.cancelada => 'Cancelar incidencia',
    EstadoIncidencia.pendiente => 'Volver a pendiente',
  };
}
