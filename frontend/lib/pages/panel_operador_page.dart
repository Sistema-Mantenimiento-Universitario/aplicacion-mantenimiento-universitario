import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/incidencias_repository.dart';
import '../models/estado_incidencia.dart';
import '../models/incidencia.dart';
import '../models/transiciones_estado.dart';
import '../models/usuario.dart';
import '../services/servicio_agitado.dart';
import '../widgets/estado_chip.dart';
import 'rutas.dart';

// Lo que se escribe al cambiar de estado
typedef DatosCambioEstado = ({String? solucion, String? comentario});

// F10  Panel de administración y seguimiento para el operador
class PanelOperadorPage extends StatefulWidget {
  const PanelOperadorPage({
    super.key,
    required this.usuario,
    required this.repositorio,
    this.onSesionExpirada,
    this.servicioAgitado,
  });

  final Usuario usuario;
  final IncidenciasRepository repositorio;

  // Se llama cuando la API responde 401, main.dart cierra la sesión
  final VoidCallback? onSesionExpirada;

  // Acelerómetro: Al agitar el celular se recarga la lista
  final ServicioAgitado? servicioAgitado;

  // Reglas de docs/api.md → Límites y validaciones de campos
  static String? validarSolucion(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return 'Escribe la solución aplicada';
    if (texto.length < 10 || texto.length > 2000) {
      return 'La solución debe tener entre 10 y 2000 caracteres';
    }
    return null;
  }

  static String? validarComentario(String? valor) {
    if ((valor ?? '').trim().length > 500) {
      return 'El comentario puede tener hasta 500 caracteres';
    }
    return null;
  }

  @override
  State<PanelOperadorPage> createState() => _PanelOperadorPageState();
}

class _PanelOperadorPageState extends State<PanelOperadorPage> {
  List<Incidencia>? _incidencias;
  bool _cargando = true;
  String? _error;
  bool _saliendo = false;

  // null = todas, agrupadas por estado
  EstadoIncidencia? _filtro;

  // Incidencias con un cambio de estado en curso
  final Set<int> _procesando = {};

  static const _orden = EstadoIncidencia.values;

  // Escucha del acelerómetro, se cancela al salir de la pantalla
  StreamSubscription<void>? _escuchaAgitado;

  @override
  void initState() {
    super.initState();
    _cargar();
    _escuchaAgitado = widget.servicioAgitado?.agitados.listen(
      (_) => _alAgitar(),
    );
  }

  @override
  void dispose() {
    _escuchaAgitado?.cancel();
    super.dispose();
  }

  // Al agitar el celular se recarga la lista
  void _alAgitar() {
    // Solo si esta pantalla es la que se ve y no está cargando ya
    if (!mounted || _cargando) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;

    HapticFeedback.mediumImpact();
    _mensaje('Actualizando la lista…');
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = _incidencias == null;
      _error = null;
    });
    try {
      // El operador recibe todas; el filtro se aplica aquí para tener los conteos
      final incidencias = await widget.repositorio.obtenerIncidencias();
      if (!mounted) return;
      setState(() {
        _incidencias = incidencias;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _cargando = false;
      });
      if (e.sesionExpirada) {
        _sesionExpirada();
      } else if (_incidencias != null) {
        _mensaje(e.mensaje);
      }
    }
  }

  List<Incidencia> _dePorEstado(EstadoIncidencia estado) =>
      (_incidencias ?? const []).where((i) => i.estado == estado).toList();

  // Cambia el estado. Si hace falta, primero pide solución o comentario.
  // Devuelve true si el cambio se guardó
  Future<bool> _cambiarEstado(
    Incidencia incidencia,
    EstadoIncidencia destino, {
    bool pedirDatos = false,
  }) async {
    if (_procesando.contains(incidencia.id)) return false;

    DatosCambioEstado datos = (solucion: null, comentario: null);
    final necesitaDialogo =
        pedirDatos ||
        destino == EstadoIncidencia.finalizada ||
        destino == EstadoIncidencia.cancelada;
    if (necesitaDialogo) {
      final respuesta = await showDialog<DatosCambioEstado>(
        context: context,
        builder: (_) =>
            _DialogoCambioEstado(incidencia: incidencia, destino: destino),
      );
      if (respuesta == null || !mounted) return false;
      datos = respuesta;
    }

    setState(() => _procesando.add(incidencia.id));
    try {
      final actualizada = await widget.repositorio.cambiarEstado(
        incidencia.id,
        destino,
        solucion: datos.solucion,
        comentario: datos.comentario,
      );
      if (!mounted) return false;
      setState(() {
        _incidencias = [
          for (final i in _incidencias ?? const <Incidencia>[])
            i.id == actualizada.id ? actualizada : i,
        ];
      });
      _mensaje('#${incidencia.id} pasó a ${destino.etiqueta}');
      return true;
    } on ApiException catch (e) {
      if (!mounted) return false;
      if (e.sesionExpirada) {
        _sesionExpirada();
        return false;
      }
      // Error del backend, p. ej. "Transición no permitida: ..."
      final detalle = e.errores.values.join('\n');
      _mensaje(detalle.isEmpty ? e.mensaje : '${e.mensaje}\n$detalle');
      // Por si otro operador ya la había cambiado
      _cargar();
      return false;
    } finally {
      if (mounted) setState(() => _procesando.remove(incidencia.id));
    }
  }

  Future<void> _abrirDetalle(Incidencia incidencia) async {
    await Navigator.pushNamed(context, Rutas.detalle(incidencia.id));
    if (mounted) _cargar();
  }

  // Mantener presionado (o el botón ⋮): ver detalle y estados permitidos
  Future<void> _mostrarOpciones(Incidencia incidencia) async {
    final eleccion = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (contextHoja) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                '#${incidencia.id}  ${incidencia.titulo}',
                style: Theme.of(contextHoja).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Ver detalle'),
              onTap: () => Navigator.pop(contextHoja, 'detalle'),
            ),
            for (final destino in incidencia.estado.permitidos)
              ListTile(
                leading: Icon(_iconoAccion(destino)),
                title: Text(destino.accion),
                subtitle: Text('Pasa a ${destino.etiqueta}'),
                onTap: () => Navigator.pop(contextHoja, destino),
              ),
            if (incidencia.estado.permitidos.isEmpty)
              const ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text('Esta incidencia ya no cambia de estado'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || eleccion == null) return;
    if (eleccion == 'detalle') {
      _abrirDetalle(incidencia);
    } else if (eleccion is EstadoIncidencia) {
      _cambiarEstado(incidencia, eleccion, pedirDatos: true);
    }
  }

  void _mensaje(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  // Token expirado: se cierran las pantallas abiertas y se cierra la sesión
  void _sesionExpirada() {
    if (_saliendo || !mounted) return;
    _saliendo = true;
    Navigator.of(context).popUntil((ruta) => ruta.isFirst);
    widget.onSesionExpirada?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administración de incidencias'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _cargar,
          ),
        ],
      ),
      body: !widget.usuario.esOperador
          ? const _Aviso(
              icono: Icons.lock_outline,
              texto: 'Esta pantalla es solo para operadores.',
            )
          : _cargando
          ? const Center(child: CircularProgressIndicator())
          : _incidencias == null
          ? _Aviso(
              icono: Icons.cloud_off,
              texto: _error ?? 'Sin datos',
              onReintentar: _cargar,
            )
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _filtros(),
                          const SizedBox(height: 8),
                          Text(
                            'Desliza a la derecha para avanzar de estado, '
                            'a la izquierda para cancelar. Mantén presionado '
                            'para ver más opciones.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          ..._lista(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _filtros() {
    final total = _incidencias?.length ?? 0;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: Text('Todas  $total'),
          selected: _filtro == null,
          onSelected: (_) => setState(() => _filtro = null),
        ),
        for (final estado in _orden)
          ChoiceChip(
            label: Text('${estado.etiqueta}  ${_dePorEstado(estado).length}'),
            selected: _filtro == estado,
            onSelected: (_) => setState(() => _filtro = estado),
          ),
      ],
    );
  }

  List<Widget> _lista() {
    // Un estado elegido: lista simple
    if (_filtro != null) {
      final incidencias = _dePorEstado(_filtro!);
      if (incidencias.isEmpty) {
        return [
          _Aviso(
            icono: Icons.inbox_outlined,
            texto: 'No hay incidencias en ${_filtro!.etiqueta.toLowerCase()}',
          ),
        ];
      }
      return [for (final i in incidencias) _elemento(i)];
    }

    // Todas: agrupadas por estado
    if ((_incidencias ?? const []).isEmpty) {
      return const [
        _Aviso(icono: Icons.inbox_outlined, texto: 'No hay incidencias'),
      ];
    }
    return [
      for (final estado in _orden)
        if (_dePorEstado(estado).isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Row(
              children: [
                EstadoChip(estado: estado),
                const SizedBox(width: 8),
                Text(
                  _cuantas(_dePorEstado(estado).length),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          for (final i in _dePorEstado(estado)) _elemento(i),
          const SizedBox(height: 8),
        ],
    ];
  }

  static String _cuantas(int n) => n == 1 ? '1 incidencia' : '$n incidencias';

  Widget _elemento(Incidencia incidencia) {
    final siguiente = incidencia.estado.siguiente;
    final puedeCancelar = incidencia.estado.puedePasarA(
      EstadoIncidencia.cancelada,
    );
    final procesando = _procesando.contains(incidencia.id);

    // Derecha: avanzar. Izquierda: cancelar (solo pendientes)
    final direccion = procesando
        ? DismissDirection.none
        : siguiente != null && puedeCancelar
        ? DismissDirection.horizontal
        : siguiente != null
        ? DismissDirection.startToEnd
        : puedeCancelar
        ? DismissDirection.endToStart
        : DismissDirection.none;

    final fondoAvanzar = siguiente == null
        ? null
        : _FondoGesto(destino: siguiente, alaIzquierda: true);
    const fondoCancelar = _FondoGesto(
      destino: EstadoIncidencia.cancelada,
      alaIzquierda: false,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey('incidencia-${incidencia.id}'),
        direction: direccion,
        background: fondoAvanzar ?? fondoCancelar,
        secondaryBackground: fondoAvanzar == null ? null : fondoCancelar,
        // El elemento no se quita de la lista: se cambia su estado
        confirmDismiss: (sentido) async {
          final destino = sentido == DismissDirection.startToEnd
              ? siguiente
              : EstadoIncidencia.cancelada;
          if (destino != null) await _cambiarEstado(incidencia, destino);
          return false;
        },
        child: _TarjetaIncidencia(
          incidencia: incidencia,
          procesando: procesando,
          onTap: () => _abrirDetalle(incidencia),
          onOpciones: () => _mostrarOpciones(incidencia),
        ),
      ),
    );
  }
}

IconData _iconoAccion(EstadoIncidencia destino) => switch (destino) {
  EstadoIncidencia.asignada => Icons.assignment_ind_outlined,
  EstadoIncidencia.enProceso => Icons.build_outlined,
  EstadoIncidencia.finalizada => Icons.task_alt,
  EstadoIncidencia.cancelada => Icons.block,
  EstadoIncidencia.pendiente => Icons.undo,
};

String _fecha(DateTime fecha) {
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year}';
}

// ---------------------------------------------------------------------------
// Elemento de la lista
// ---------------------------------------------------------------------------

class _TarjetaIncidencia extends StatelessWidget {
  const _TarjetaIncidencia({
    required this.incidencia,
    required this.procesando,
    required this.onTap,
    required this.onOpciones,
  });

  final Incidencia incidencia;
  final bool procesando;
  final VoidCallback onTap;
  final VoidCallback onOpciones;

  @override
  Widget build(BuildContext context) {
    final i = incidencia;
    final theme = Theme.of(context);
    final operador = i.operador?.nombre ?? 'Sin asignar';

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onOpciones,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '#${i.id}  ${i.categoria.nombre}  ${_fecha(i.fechaCreacion)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      'Reportó: ${i.reportadoPor.nombre}  Operador: $operador',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    EstadoChip(estado: i.estado),
                  ],
                ),
              ),
              procesando
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Opciones',
                      icon: const Icon(Icons.more_vert),
                      onPressed: onOpciones,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

// Fondo que aparece al deslizar
class _FondoGesto extends StatelessWidget {
  const _FondoGesto({required this.destino, required this.alaIzquierda});

  final EstadoIncidencia destino;
  final bool alaIzquierda;

  @override
  Widget build(BuildContext context) {
    final cancelar = destino == EstadoIncidencia.cancelada;
    final colores = Theme.of(context).colorScheme;
    final fondo = cancelar ? colores.error : colores.primary;
    final texto = cancelar ? colores.onError : colores.onPrimary;

    return Container(
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: alaIzquierda ? Alignment.centerLeft : Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconoAccion(destino), color: texto),
          const SizedBox(width: 8),
          Text(
            destino.accion,
            style: TextStyle(color: texto, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Diálogo para confirmar el cambio de estado
// ---------------------------------------------------------------------------

class _DialogoCambioEstado extends StatefulWidget {
  const _DialogoCambioEstado({required this.incidencia, required this.destino});

  final Incidencia incidencia;
  final EstadoIncidencia destino;

  @override
  State<_DialogoCambioEstado> createState() => _DialogoCambioEstadoState();
}

class _DialogoCambioEstadoState extends State<_DialogoCambioEstado> {
  final _formKey = GlobalKey<FormState>();
  final _solucion = TextEditingController();
  final _comentario = TextEditingController();

  bool get _finaliza => widget.destino == EstadoIncidencia.finalizada;

  String get _titulo => switch (widget.destino) {
    EstadoIncidencia.asignada => '¿Asignarte esta incidencia?',
    EstadoIncidencia.enProceso => '¿Iniciar la atención?',
    EstadoIncidencia.finalizada => '¿Finalizar la incidencia?',
    EstadoIncidencia.cancelada => '¿Cancelar la incidencia?',
    EstadoIncidencia.pendiente => '¿Cambiar el estado?',
  };

  @override
  void dispose() {
    _solucion.dispose();
    _comentario.dispose();
    super.dispose();
  }

  void _confirmar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop<DatosCambioEstado>(context, (
      solucion: _finaliza ? _solucion.text.trim() : null,
      comentario: _comentario.text.trim().isEmpty
          ? null
          : _comentario.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cancelar = widget.destino == EstadoIncidencia.cancelada;

    return AlertDialog(
      title: Text(_titulo),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('#${widget.incidencia.id}  ${widget.incidencia.titulo}'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    EstadoChip(estado: widget.incidencia.estado),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.arrow_forward, size: 16),
                    ),
                    EstadoChip(estado: widget.destino),
                  ],
                ),
                const SizedBox(height: 16),
                if (_finaliza) ...[
                  TextFormField(
                    controller: _solucion,
                    autofocus: true,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: 'Solución aplicada',
                      hintText: 'Qué se hizo para resolver la falla',
                      border: OutlineInputBorder(),
                    ),
                    validator: PanelOperadorPage.validarSolucion,
                  ),
                  const SizedBox(height: 8),
                ],
                TextFormField(
                  controller: _comentario,
                  maxLines: 2,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Comentario (opcional)',
                    hintText: 'Se guarda en el historial',
                    border: OutlineInputBorder(),
                  ),
                  validator: PanelOperadorPage.validarComentario,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Volver'),
        ),
        FilledButton(
          onPressed: _confirmar,
          style: cancelar
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                )
              : null,
          child: Text(widget.destino.accion),
        ),
      ],
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icono, required this.texto, this.onReintentar});

  final IconData icono;
  final String texto;
  final Future<void> Function()? onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 40),
            const SizedBox(height: 8),
            Text(texto, textAlign: TextAlign.center),
            if (onReintentar != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onReintentar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
