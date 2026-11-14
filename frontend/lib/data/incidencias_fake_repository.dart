import 'incidencias_repository.dart';

/// Datos simulados con los estados y roles del contrato (docs/api.md).
/// Se usa mientras el backend no tenga GET /api/incidencias/resumen.
///
/// Usuarios simulados:
///   1 · Ana López     · usuario
///   2 · Luis Pérez    · operador
///   3 · Beatriz Gómez · usuario
class FakeIncidenciasRepository implements IncidenciasRepository {
  FakeIncidenciasRepository({
    required this.idUsuario,
    required this.esOperador,
    this.demora = const Duration(milliseconds: 600),
  });

  /// Usuario "del token" simulado.
  final int idUsuario;
  final bool esOperador;
  final Duration demora;

  static const _estados = [
    'pendiente',
    'asignada',
    'en_proceso',
    'finalizada',
    'cancelada',
  ];

  /// (id_usuario que reportó, estado)
  static const _incidencias = [
    (1, 'pendiente'),
    (1, 'pendiente'),
    (1, 'asignada'),
    (1, 'en_proceso'),
    (1, 'finalizada'),
    (3, 'pendiente'),
    (3, 'cancelada'),
  ];

  @override
  Future<Map<String, int>> obtenerResumenPorEstado() async {
    // Simula la latencia de la red para ver el indicador de carga.
    if (demora > Duration.zero) await Future<void>.delayed(demora);

    final resumen = {for (final e in _estados) e: 0};
    for (final (usuario, estado) in _incidencias) {
      if (esOperador || usuario == idUsuario) {
        resumen[estado] = resumen[estado]! + 1;
      }
    }
    return resumen;
  }
}