import '../models/categoria.dart';
import '../models/estado_incidencia.dart';
import '../models/incidencia.dart';
import 'incidencias_repository.dart';

/// Datos simulados con los estados y roles del contrato (docs/api.md).
/// Se usa mientras el backend no tenga GET /api/incidencias/resumen.
///
/// Usuarios simulados:
///   1 · Ana López      usuario
///   2 · Luis Pérez     operador
///   3 · Beatriz Gómez  usuario
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

  static const _electricidad = Categoria(id: 1, nombre: 'Electricidad');
  static const _plomeria = Categoria(id: 2, nombre: 'Plomería');
  static const _mobiliario = Categoria(id: 3, nombre: 'Mobiliario');
  static const _limpieza = Categoria(id: 4, nombre: 'Limpieza');

  static const _categorias = [_electricidad, _plomeria, _mobiliario, _limpieza];

  static const _ana = PersonaIncidencia(id: 1, nombre: 'Ana López');
  static const _luis = PersonaIncidencia(id: 2, nombre: 'Luis Pérez');
  static const _beatriz = PersonaIncidencia(id: 3, nombre: 'Beatriz Gómez');

  static final _incidencias = [
    Incidencia(
      id: 1,
      titulo: 'Lámpara fundida en el pasillo',
      descripcion:
          'La lámpara del pasillo del edificio 3 no enciende desde el lunes.',
      estado: EstadoIncidencia.pendiente,
      categoria: _electricidad,
      reportadoPor: _ana,
      ubicacionTexto: 'Edificio 3, planta baja',
      fechaCreacion: DateTime(2026, 11, 12, 9, 15),
    ),
    Incidencia(
      id: 2,
      titulo: 'Fuga de agua en el baño',
      descripcion: 'El lavabo del fondo gotea y se encharca el piso.',
      estado: EstadoIncidencia.asignada,
      categoria: _plomeria,
      reportadoPor: _ana,
      operador: _luis,
      ubicacionTexto: 'Edificio 1, baño de mujeres',
      fechaCreacion: DateTime(2026, 11, 10, 13, 40),
    ),
    Incidencia(
      id: 3,
      titulo: 'Silla rota en el aula 204',
      descripcion: 'Una silla de la tercera fila tiene la pata floja.',
      estado: EstadoIncidencia.enProceso,
      categoria: _mobiliario,
      reportadoPor: _ana,
      operador: _luis,
      ubicacionTexto: 'Edificio 2, aula 204',
      fechaCreacion: DateTime(2026, 11, 8, 10, 5),
    ),
    Incidencia(
      id: 4,
      titulo: 'Contacto sin corriente en el laboratorio',
      descripcion: 'El contacto junto a la ventana no funciona.',
      estado: EstadoIncidencia.finalizada,
      categoria: _electricidad,
      reportadoPor: _ana,
      operador: _luis,
      ubicacionTexto: 'Laboratorio de cómputo 1',
      fechaCreacion: DateTime(2026, 11, 5, 16, 20),
    ),
    Incidencia(
      id: 5,
      titulo: 'Bote de basura desbordado',
      descripcion: 'El bote junto a la entrada no se ha vaciado hoy.',
      estado: EstadoIncidencia.pendiente,
      categoria: _limpieza,
      reportadoPor: _ana,
      ubicacionTexto: 'Cafetería central',
      fechaCreacion: DateTime(2026, 11, 13, 8, 30),
    ),
    Incidencia(
      id: 6,
      titulo: 'Proyector sin imagen',
      descripcion: 'El proyector enciende pero no muestra imagen.',
      estado: EstadoIncidencia.pendiente,
      categoria: _electricidad,
      reportadoPor: _beatriz,
      ubicacionTexto: 'Edificio 5, aula 101',
      fechaCreacion: DateTime(2026, 11, 11, 11, 0),
    ),
    Incidencia(
      id: 7,
      titulo: 'Puerta que no cierra',
      descripcion: 'La puerta de la entrada principal se queda abierta.',
      estado: EstadoIncidencia.cancelada,
      categoria: _mobiliario,
      reportadoPor: _beatriz,
      ubicacionTexto: 'Biblioteca, entrada principal',
      fechaCreacion: DateTime(2026, 11, 6, 12, 45),
    ),
  ];

  // Lo que puede ver el usuario simulado
  Iterable<Incidencia> get _visibles =>
      _incidencias.where((i) => esOperador || i.reportadoPor.id == idUsuario);

  @override
  Future<Map<String, int>> obtenerResumenPorEstado() async {
    await _esperar();
    final resumen = {
      for (final e in EstadoIncidencia.values) e.valorIncidencia: 0,
    };
    for (final i in _visibles) {
      resumen[i.estado.valorIncidencia] =
          resumen[i.estado.valorIncidencia]! + 1;
    }
    return resumen;
  }

  @override
  Future<List<Incidencia>> obtenerIncidencias({
    String? texto,
    EstadoIncidencia? estado,
    int? idCategoria,
  }) async {
    await _esperar();
    final q = (texto ?? '').trim().toLowerCase();
    return _visibles
        .where(
          (i) =>
              (estado == null || i.estado == estado) &&
              (idCategoria == null || i.categoria.id == idCategoria) &&
              (q.isEmpty ||
                  i.titulo.toLowerCase().contains(q) ||
                  (i.descripcion ?? '').toLowerCase().contains(q)),
        )
        .toList()
      // De la más reciente a la más antigua, como el backend.
      ..sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
  }

  @override
  Future<List<Categoria>> obtenerCategorias() async {
    await _esperar();
    return _categorias;
  }

  /// Simula la latencia de la red para ver el indicador de carga.
  Future<void> _esperar() async {
    if (demora > Duration.zero) await Future<void>.delayed(demora);
  }
}
