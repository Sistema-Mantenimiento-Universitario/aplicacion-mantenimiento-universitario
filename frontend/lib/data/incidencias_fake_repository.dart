import '../models/categoria.dart';
import '../models/estado_incidencia.dart';
import '../models/evidencia.dart';
import '../models/historial.dart';
import '../models/incidencia.dart';
import 'incidencias_repository.dart';
import '../models/datos_incidencia.dart';

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

  static const _personas = [_ana, _luis, _beatriz];
  // Id para la siguiente incidencia nueva
  static int _siguienteId = 8;

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
      latitud: 21.913600,
      longitud: -102.315800,
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
      latitud: 21.914250,
      longitud: -102.316420,
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
      solucionDescripcion:
          'Se cambió el contacto dañado y se revisó el cableado del muro.',
      fechaCreacion: DateTime(2026, 11, 5, 16, 20),
      fechaFinalizacion: DateTime(2026, 11, 7, 12, 0),
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

  @override
  Future<Incidencia> crearIncidencia(DatosIncidencia datos) async {
    await _esperar();
    final nueva = Incidencia(
      id: _siguienteId++,
      titulo: datos.titulo,
      descripcion: datos.descripcion,
      estado: EstadoIncidencia.pendiente,
      categoria: _buscarCategoria(datos.idCategoria),
      reportadoPor: _personas.firstWhere(
        (p) => p.id == idUsuario,
        orElse: () => PersonaIncidencia(id: idUsuario, nombre: 'Usuario'),
      ),
      ubicacionTexto: datos.ubicacionTexto,
      fechaCreacion: DateTime.now(),
    );
    _incidencias.add(nueva);
    _historialDe(nueva);
    return nueva;
  }

  @override
  Future<Incidencia> editarIncidencia(int id, DatosIncidencia datos) async {
    await _esperar();
    final posicion = _incidencias.indexWhere((i) => i.id == id);
    if (posicion == -1) {
      throw ApiException('La incidencia no existe', statusCode: 404);
    }
    final actual = _incidencias[posicion];

    if (actual.reportadoPor.id != idUsuario) {
      throw ApiException(
        'Solo quien creó la incidencia puede editarla',
        statusCode: 403,
      );
    }
    if (actual.estado != EstadoIncidencia.pendiente) {
      throw ApiException(
        'Solo se pueden editar incidencias pendientes',
        statusCode: 400,
      );
    }

    // Se conservan el id, el estado, quién la reportó y la fecha
    final editada = Incidencia(
      id: actual.id,
      titulo: datos.titulo,
      descripcion: datos.descripcion,
      estado: actual.estado,
      categoria: _buscarCategoria(datos.idCategoria),
      reportadoPor: actual.reportadoPor,
      operador: actual.operador,
      ubicacionTexto: datos.ubicacionTexto,
      latitud: actual.latitud,
      longitud: actual.longitud,
      solucionDescripcion: actual.solucionDescripcion,
      fechaCreacion: actual.fechaCreacion,
      fechaActualizacion: DateTime.now(),
      fechaFinalizacion: actual.fechaFinalizacion,
    );
    _historialDe(actual).add(
      _entrada(AccionHistorial.edicion, actual.reportadoPor, DateTime.now()),
    );
    _incidencias[posicion] = editada;
    return editada;
  }

  @override
  Future<Incidencia> obtenerIncidencia(int id) async {
    await _esperar();
    return _buscarVisible(id);
  }

  @override
  Future<List<EntradaHistorial>> obtenerHistorial(int id) async {
    await _esperar();
    final incidencia = _buscarVisible(id);
    return List.of(_historialDe(incidencia))
      ..sort((a, b) => a.fecha.compareTo(b.fecha));
  }

  @override
  Future<List<Evidencia>> obtenerEvidencias(int id) async {
    await _esperar();
    _buscarVisible(id);
    return _evidencias[id] ?? const [];
  }

  @override
  Future<void> cancelarIncidencia(int id) async {
    await _esperar();
    final posicion = _incidencias.indexWhere((i) => i.id == id);
    if (posicion == -1) {
      throw ApiException('Incidencia no encontrada', statusCode: 404);
    }
    final actual = _incidencias[posicion];

    // El usuario solo cancela las suyas; el operador cualquiera
    if (!esOperador && actual.reportadoPor.id != idUsuario) {
      throw ApiException(
        'No tienes permiso para realizar esta acción',
        statusCode: 403,
      );
    }
    if (actual.estado != EstadoIncidencia.pendiente) {
      throw ApiException(
        'Solo se puede cancelar una incidencia pendiente',
        statusCode: 400,
      );
    }

    _historialDe(actual).add(
      _entrada(
        AccionHistorial.cambioEstado,
        _personaActual,
        DateTime.now(),
        anterior: EstadoIncidencia.pendiente,
        nuevo: EstadoIncidencia.cancelada,
      ),
    );
    _incidencias[posicion] = actual.conEstado(EstadoIncidencia.cancelada);
  }

  // Igual que el backend: 404 si no existe y 403 si es de otro usuario
  Incidencia _buscarVisible(int id) {
    final posicion = _incidencias.indexWhere((i) => i.id == id);
    if (posicion == -1) {
      throw ApiException('Incidencia no encontrada', statusCode: 404);
    }
    final incidencia = _incidencias[posicion];
    if (!esOperador && incidencia.reportadoPor.id != idUsuario) {
      throw ApiException(
        'No tienes permiso para realizar esta acción',
        statusCode: 403,
      );
    }
    return incidencia;
  }

  PersonaIncidencia get _personaActual => _personas.firstWhere(
    (p) => p.id == idUsuario,
    orElse: () => PersonaIncidencia(id: idUsuario, nombre: 'Usuario'),
  );

  // ---------- Historial y evidencias simulados ----------

  static int _siguienteIdHistorial = 1;
  static final Map<int, List<EntradaHistorial>> _historiales = {};

  static EntradaHistorial _entrada(
    AccionHistorial accion,
    PersonaIncidencia responsable,
    DateTime fecha, {
    EstadoIncidencia? anterior,
    EstadoIncidencia? nuevo,
    String? comentario,
  }) => EntradaHistorial(
    id: _siguienteIdHistorial++,
    accion: accion,
    estadoAnterior: anterior,
    estadoNuevo: nuevo,
    comentario: comentario,
    fecha: fecha,
    responsable: responsable,
  );

  // Se arma la primera vez a partir del estado de la incidencia
  static List<EntradaHistorial> _historialDe(Incidencia i) =>
      _historiales.putIfAbsent(i.id, () {
        const pendiente = EstadoIncidencia.pendiente;
        const asignada = EstadoIncidencia.asignada;
        const enProceso = EstadoIncidencia.enProceso;
        const finalizada = EstadoIncidencia.finalizada;
        final operador = i.operador ?? _luis;
        final inicio = i.fechaCreacion;

        return [
          _entrada(
            AccionHistorial.creacion,
            i.reportadoPor,
            inicio,
            nuevo: pendiente,
          ),
          if ([asignada, enProceso, finalizada].contains(i.estado))
            _entrada(
              AccionHistorial.cambioEstado,
              operador,
              inicio.add(const Duration(hours: 20)),
              anterior: pendiente,
              nuevo: asignada,
            ),
          if ([enProceso, finalizada].contains(i.estado))
            _entrada(
              AccionHistorial.cambioEstado,
              operador,
              inicio.add(const Duration(days: 1, hours: 2)),
              anterior: asignada,
              nuevo: enProceso,
              comentario: 'Se revisó en sitio',
            ),
          if (i.estado == finalizada)
            _entrada(
              AccionHistorial.cambioEstado,
              operador,
              i.fechaFinalizacion ?? inicio.add(const Duration(days: 2)),
              anterior: enProceso,
              nuevo: finalizada,
              comentario: 'Trabajo concluido',
            ),
          if (i.estado == EstadoIncidencia.cancelada)
            _entrada(
              AccionHistorial.cambioEstado,
              i.reportadoPor,
              inicio.add(const Duration(hours: 3)),
              anterior: pendiente,
              nuevo: EstadoIncidencia.cancelada,
              comentario: 'Reporte duplicado',
            ),
        ];
      });

  static final Map<int, List<Evidencia>> _evidencias = {
    2: [
      Evidencia(
        id: 1,
        tipo: 'reporte',
        url: 'https://picsum.photos/seed/fuga-1/800/600',
        nombreOriginal: 'lavabo.jpg',
        fechaSubida: DateTime(2026, 11, 10, 13, 42),
      ),
      Evidencia(
        id: 2,
        tipo: 'reporte',
        url: 'https://picsum.photos/seed/fuga-2/800/600',
        nombreOriginal: 'piso.jpg',
        fechaSubida: DateTime(2026, 11, 10, 13, 43),
      ),
    ],
    3: [
      Evidencia(
        id: 3,
        tipo: 'reporte',
        url: 'https://picsum.photos/seed/silla-1/800/600',
        nombreOriginal: 'silla.jpg',
        fechaSubida: DateTime(2026, 11, 8, 10, 6),
      ),
    ],
    4: [
      Evidencia(
        id: 4,
        tipo: 'reporte',
        url: 'https://picsum.photos/seed/contacto-1/800/600',
        nombreOriginal: 'contacto.jpg',
        fechaSubida: DateTime(2026, 11, 5, 16, 22),
      ),
      Evidencia(
        id: 5,
        tipo: 'atencion',
        url: 'https://picsum.photos/seed/contacto-2/800/600',
        nombreOriginal: 'reparado.jpg',
        fechaSubida: DateTime(2026, 11, 7, 11, 55),
      ),
    ],
  };

  // Igual que en el backend la categoría debe existir y estar activa
  Categoria _buscarCategoria(int id) => _categorias.firstWhere(
    (c) => c.id == id && c.activa,
    orElse: () => throw ApiException(
      'Datos inválidos',
      statusCode: 400,
      errores: {'id_categoria': 'La categoría no existe o está inactiva'},
    ),
  );

  /// Simula la latencia de la red para ver el indicador de carga.
  Future<void> _esperar() async {
    if (demora > Duration.zero) await Future<void>.delayed(demora);
  }
}
