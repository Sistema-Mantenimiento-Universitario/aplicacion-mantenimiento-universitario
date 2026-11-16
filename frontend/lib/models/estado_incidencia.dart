// Estados de una incidencia
enum EstadoIncidencia {
  pendiente('pendiente', 'Pendiente'),
  asignada('asignada', 'Asignada'),
  enProceso('en_proceso', 'En proceso'),
  finalizada('finalizada', 'Finalizada'),
  cancelada('cancelada', 'Cancelada');

  const EstadoIncidencia(this.valorIncidencia, this.etiqueta);

  final String valorIncidencia; // Valor que usan la API y la base de datos

  final String etiqueta; // Texto mostrado en la aplicación

  // Convierte el valor de la API.
  static EstadoIncidencia desdeApi(String? valor) => values.firstWhere(
    (e) => e.valorIncidencia == valor,
    orElse: () => throw FormatException(
      'Estado desconocido: $valor',
    ), // Si el estado no es uno de los definidos en el contrato
  );
}
