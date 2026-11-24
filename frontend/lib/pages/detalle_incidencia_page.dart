import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/incidencias_repository.dart';
import '../models/estado_incidencia.dart';
import '../models/evidencia.dart';
import '../models/historial.dart';
import '../models/incidencia.dart';
import '../models/usuario.dart';
import '../widgets/estado_chip.dart';
import 'rutas.dart';

// F9 · Detalle de incidencia con historial y evidencias
class DetalleIncidenciaPage extends StatefulWidget {
  const DetalleIncidenciaPage({
    super.key,
    required this.usuario,
    required this.repositorio,
    required this.idIncidencia,
    this.onSesionExpirada,
  });

  final Usuario usuario;
  final IncidenciasRepository repositorio;
  final int idIncidencia;

  // Se llama cuando la API responde 401, main.dart cierra la sesión
  final VoidCallback? onSesionExpirada;

  @override
  State<DetalleIncidenciaPage> createState() => _DetalleIncidenciaPageState();
}

class _DetalleIncidenciaPageState extends State<DetalleIncidenciaPage> {
  Incidencia? _incidencia;
  bool _cargando = true;
  String? _error;

  // El historial y las evidencias se cargan aparte: si fallan,
  // el resto del detalle se sigue mostrando
  List<EntradaHistorial>? _historial;
  String? _errorHistorial;
  List<Evidencia>? _evidencias;
  String? _errorEvidencias;

  bool _cancelando = false;
  bool _saliendo = false;

  // PUT solo lo puede usar el usuario creador y mientras esté pendiente
  bool get _puedeEditar {
    final i = _incidencia;
    return i != null &&
        !widget.usuario.esOperador &&
        i.reportadoPor.id == widget.usuario.id &&
        i.estado == EstadoIncidencia.pendiente;
  }

  // DELETE: el creador o un operador, solo si está pendiente
  bool get _puedeCancelar {
    final i = _incidencia;
    return i != null &&
        i.estado == EstadoIncidencia.pendiente &&
        (widget.usuario.esOperador || i.reportadoPor.id == widget.usuario.id);
  }

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = _incidencia == null;
      _error = null;
    });
    await Future.wait([
      _cargarDetalle(),
      _cargarHistorial(),
      _cargarEvidencias(),
    ]);
  }

  Future<void> _cargarDetalle() async {
    try {
      final incidencia = await widget.repositorio.obtenerIncidencia(
        widget.idIncidencia,
      );
      if (!mounted) return;
      setState(() {
        _incidencia = incidencia;
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
      } else if (_incidencia != null) {
        // Ya había datos en pantalla: se avisa sin quitarlos
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }
  }

  Future<void> _cargarHistorial() async {
    try {
      final historial = await widget.repositorio.obtenerHistorial(
        widget.idIncidencia,
      );
      if (!mounted) return;
      setState(() {
        // Orden cronológico: del más antiguo al más reciente
        _historial = List.of(historial)
          ..sort((a, b) => a.fecha.compareTo(b.fecha));
        _errorHistorial = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorHistorial = e.mensaje);
      if (e.sesionExpirada) _sesionExpirada();
    }
  }

  Future<void> _cargarEvidencias() async {
    try {
      final evidencias = await widget.repositorio.obtenerEvidencias(
        widget.idIncidencia,
      );
      if (!mounted) return;
      setState(() {
        _evidencias = evidencias;
        _errorEvidencias = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorEvidencias = e.mensaje);
      if (e.sesionExpirada) _sesionExpirada();
    }
  }

  Future<void> _editar() async {
    final guardada = await Navigator.pushNamed(
      context,
      Rutas.editar(widget.idIncidencia),
      arguments: _incidencia,
    );
    if (guardada != null && mounted) _cargar();
  }

  Future<void> _confirmarCancelar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Cancelar la incidencia?'),
        content: const Text(
          'La incidencia quedará como cancelada y ya no se podrá atender ni editar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _cancelando = true);
    try {
      await widget.repositorio.cancelarIncidencia(widget.idIncidencia);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Incidencia cancelada')));
      await _cargar();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.sesionExpirada) {
        _sesionExpirada();
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      if (mounted) setState(() => _cancelando = false);
    }
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
    final incidencia = _incidencia;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de incidencia'),
        actions: [
          if (_puedeEditar)
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _editar,
            ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : incidencia == null
          ? _MensajeError(mensaje: _error ?? 'Sin datos', onReintentar: _cargar)
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _contenido(incidencia),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  List<Widget> _contenido(Incidencia i) {
    final theme = Theme.of(context);
    return [
      _BannerEstado(incidencia: i),
      const SizedBox(height: 16),
      Text(i.titulo, style: theme.textTheme.headlineSmall),
      const SizedBox(height: 4),
      Text(
        '#${i.id} · ${i.categoria.nombre}',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
      const SizedBox(height: 16),

      // Datos
      _Seccion(
        titulo: 'Datos',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((i.descripcion ?? '').isNotEmpty) ...[
              Text(i.descripcion!),
              const Divider(height: 24),
            ],
            _Dato(
              icono: Icons.person_outline,
              etiqueta: 'Reportó',
              valor: i.reportadoPor.nombre,
            ),
            _Dato(
              icono: Icons.support_agent,
              etiqueta: 'Operador',
              valor: i.operador?.nombre ?? 'Sin asignar',
            ),
            _Dato(
              icono: Icons.event_outlined,
              etiqueta: 'Creada',
              valor: formatoFecha(i.fechaCreacion),
            ),
            if (i.fechaActualizacion != null)
              _Dato(
                icono: Icons.update,
                etiqueta: 'Actualizada',
                valor: formatoFecha(i.fechaActualizacion!),
              ),
            if (i.fechaFinalizacion != null)
              _Dato(
                icono: Icons.task_alt,
                etiqueta: 'Finalizada',
                valor: formatoFecha(i.fechaFinalizacion!),
              ),
          ],
        ),
      ),

      if ((i.solucionDescripcion ?? '').isNotEmpty)
        _Seccion(
          titulo: 'Solución aplicada',
          child: Text(i.solucionDescripcion!),
        ),

      // Ubicación
      _Seccion(
        titulo: 'Ubicación',
        child: _Ubicacion(incidencia: i),
      ),

      // Evidencias
      _Seccion(
        titulo: 'Evidencias',
        child: _errorEvidencias != null
            ? _ErrorSeccion(
                mensaje: _errorEvidencias!,
                onReintentar: _cargarEvidencias,
              )
            : _evidencias == null
            ? const _CargandoSeccion()
            : _Galeria(evidencias: _evidencias!),
      ),

      // Historial
      _Seccion(
        titulo: 'Historial',
        child: _errorHistorial != null
            ? _ErrorSeccion(
                mensaje: _errorHistorial!,
                onReintentar: _cargarHistorial,
              )
            : _historial == null
            ? const _CargandoSeccion()
            : _LineaDeTiempo(entradas: _historial!),
      ),

      // Acciones según permisos
      if (_puedeEditar || _puedeCancelar) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.end,
          children: [
            if (_puedeEditar)
              OutlinedButton.icon(
                onPressed: _cancelando ? null : _editar,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar'),
              ),
            if (_puedeCancelar)
              FilledButton.icon(
                onPressed: _cancelando ? null : _confirmarCancelar,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                icon: _cancelando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.block),
                label: const Text('Cancelar incidencia'),
              ),
          ],
        ),
      ],
      const SizedBox(height: 24),
    ];
  }
}

/// Fecha corta en hora local, p. ej. 12/11/2026 09:15
String formatoFecha(DateTime fecha) {
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} '
      '${dos(fecha.hour)}:${dos(fecha.minute)}';
}

// ---------------------------------------------------------------------------
// Estado actual destacado
// ---------------------------------------------------------------------------

class _BannerEstado extends StatelessWidget {
  const _BannerEstado({required this.incidencia});
  final Incidencia incidencia;

  String get _descripcion => switch (incidencia.estado) {
    EstadoIncidencia.pendiente => 'En espera de que un operador la atienda',
    EstadoIncidencia.asignada =>
      'Asignada a ${incidencia.operador?.nombre ?? 'un operador'}',
    EstadoIncidencia.enProceso => 'El operador está trabajando en ella',
    EstadoIncidencia.finalizada => 'La falla ya se resolvió',
    EstadoIncidencia.cancelada => 'La incidencia se canceló',
  };

  @override
  Widget build(BuildContext context) {
    final e = estiloEstado(context, incidencia.estado);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: e.fondo,
        border: Border.all(color: e.borde, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: e.borde,
            child: Icon(e.icono, color: e.texto),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estado actual',
                  style: theme.textTheme.labelMedium?.copyWith(color: e.texto),
                ),
                Text(
                  incidencia.estado.etiqueta,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: e.texto,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _descripcion,
                  style: theme.textTheme.bodyMedium?.copyWith(color: e.texto),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ubicación
// ---------------------------------------------------------------------------

class _Ubicacion extends StatelessWidget {
  const _Ubicacion({required this.incidencia});
  final Incidencia incidencia;

  Future<void> _abrirMapa(BuildContext context) async {
    final lat = incidencia.latitud!.toStringAsFixed(6);
    final lon = incidencia.longitud!.toStringAsFixed(6);
    final url = Uri.parse(
      'https://www.openstreetmap.org/?mlat=$lat&mlon=$lon#map=18/$lat/$lon',
    );
    final abierto = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!abierto && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No se pudo abrir el mapa')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = incidencia;
    final texto = i.ubicacionTexto;

    if ((texto ?? '').isEmpty && !i.tieneCoordenadas) {
      return const Text('Sin ubicación registrada');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ((texto ?? '').isNotEmpty)
          _Dato(icono: Icons.place_outlined, etiqueta: 'Lugar', valor: texto!),
        if (i.tieneCoordenadas) ...[
          _Dato(
            icono: Icons.my_location,
            etiqueta: 'Coordenadas',
            valor:
                '${i.latitud!.toStringAsFixed(6)}, '
                '${i.longitud!.toStringAsFixed(6)}',
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _abrirMapa(context),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Abrir en el mapa'),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Galería de evidencias con vista ampliada
// ---------------------------------------------------------------------------

class _Galeria extends StatelessWidget {
  const _Galeria({required this.evidencias});
  final List<Evidencia> evidencias;

  void _ampliar(BuildContext context, int inicial) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            _VisorEvidencias(evidencias: evidencias, inicial: inicial),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (evidencias.isEmpty) return const Text('Sin evidencias');

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var n = 0; n < evidencias.length; n++)
          Tooltip(
            message: 'Ver imagen ${n + 1}',
            child: InkWell(
              key: ValueKey('evidencia-${evidencias[n].id}'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => _ampliar(context, n),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 104,
                  height: 104,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _Imagen(url: evidencias[n].url, fit: BoxFit.cover),
                      Positioned(
                        left: 4,
                        bottom: 4,
                        child: _EtiquetaTipo(evidencia: evidencias[n]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _VisorEvidencias extends StatefulWidget {
  const _VisorEvidencias({required this.evidencias, required this.inicial});
  final List<Evidencia> evidencias;
  final int inicial;

  @override
  State<_VisorEvidencias> createState() => _VisorEvidenciasState();
}

class _VisorEvidenciasState extends State<_VisorEvidencias> {
  late final PageController _paginas = PageController(
    initialPage: widget.inicial,
  );
  late int _actual = widget.inicial;

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final evidencia = widget.evidencias[_actual];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Cerrar',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_actual + 1} de ${widget.evidencias.length} · '
          '${evidencia.etiquetaTipo}',
        ),
      ),
      body: PageView.builder(
        controller: _paginas,
        itemCount: widget.evidencias.length,
        onPageChanged: (n) => setState(() => _actual = n),
        // Pellizcar o doble toque para acercar
        itemBuilder: (_, n) => InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Center(
            child: _Imagen(url: widget.evidencias[n].url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

class _Imagen extends StatelessWidget {
  const _Imagen({required this.url, required this.fit});
  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    // Las fotos subidas con el repositorio simulado traen la imagen
    // dentro de la URL (data:); esas se muestran desde la memoria
    if (url.startsWith('data:')) {
      return Image.memory(
        UriData.parse(url).contentAsBytes(),
        fit: fit,
        errorBuilder: _imagenRota,
      );
    }
    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (context, child, progreso) => progreso == null
          ? child
          : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      errorBuilder: _imagenRota,
    );
  }

  Widget _imagenRota(BuildContext context, Object error, StackTrace? stack) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _EtiquetaTipo extends StatelessWidget {
  const _EtiquetaTipo({required this.evidencia});
  final Evidencia evidencia;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        evidencia.etiquetaTipo,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Historial tipo línea de tiempo
// ---------------------------------------------------------------------------

class _LineaDeTiempo extends StatelessWidget {
  const _LineaDeTiempo({required this.entradas});
  final List<EntradaHistorial> entradas;

  @override
  Widget build(BuildContext context) {
    if (entradas.isEmpty) return const Text('Sin cambios registrados');

    return Column(
      children: [
        for (var n = 0; n < entradas.length; n++)
          _PuntoHistorial(
            entrada: entradas[n],
            esUltimo: n == entradas.length - 1,
          ),
      ],
    );
  }
}

class _PuntoHistorial extends StatelessWidget {
  const _PuntoHistorial({required this.entrada, required this.esUltimo});
  final EntradaHistorial entrada;
  final bool esUltimo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorLinea = theme.colorScheme.primary;
    final estado = entrada.estadoNuevo;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Punto y línea
          SizedBox(
            width: 24,
            child: Column(
              children: [
                const SizedBox(height: 4),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colorLinea,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!esUltimo)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: colorLinea.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Contenido
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: esUltimo ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entrada.accion.etiqueta,
                    style: theme.textTheme.titleSmall,
                  ),
                  if (entrada.accion == AccionHistorial.cambioEstado &&
                      estado != null) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        if (entrada.estadoAnterior != null) ...[
                          EstadoChip(estado: entrada.estadoAnterior!),
                          const Icon(Icons.arrow_forward, size: 16),
                        ],
                        EstadoChip(estado: estado),
                      ],
                    ),
                  ],
                  if ((entrada.comentario ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('“${entrada.comentario}”'),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    '${entrada.responsable.nombre} · ${formatoFecha(entrada.fecha)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Piezas comunes
// ---------------------------------------------------------------------------

class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.child});
  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titulo, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });
  final IconData icono;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          SizedBox(
            width: 104,
            child: Text(etiqueta, style: theme.textTheme.bodySmall),
          ),
          Expanded(child: Text(valor)),
        ],
      ),
    );
  }
}

class _CargandoSeccion extends StatelessWidget {
  const _CargandoSeccion();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(8),
      child: CircularProgressIndicator(),
    ),
  );
}

class _ErrorSeccion extends StatelessWidget {
  const _ErrorSeccion({required this.mensaje, required this.onReintentar});
  final String mensaje;
  final Future<void> Function() onReintentar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
        const SizedBox(width: 8),
        Expanded(child: Text(mensaje)),
        TextButton(onPressed: onReintentar, child: const Text('Reintentar')),
      ],
    );
  }
}

class _MensajeError extends StatelessWidget {
  const _MensajeError({required this.mensaje, required this.onReintentar});
  final String mensaje;
  final Future<void> Function() onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 40,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 8),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
