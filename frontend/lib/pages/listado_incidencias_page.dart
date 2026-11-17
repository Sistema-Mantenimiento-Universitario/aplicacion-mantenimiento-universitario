import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/incidencias_repository.dart';
import '../models/categoria.dart';
import '../models/estado_incidencia.dart';
import '../models/incidencia.dart';
import '../models/usuario.dart';
import '../theme/app_theme.dart';
import '../widgets/estado_chip.dart';
import 'rutas.dart';

// Listado de incidencias con búsqueda y filtros.
// El usuario ve solo sus incidencias y el operador todas
class ListadoIncidenciasPage extends StatefulWidget {
  const ListadoIncidenciasPage({
    super.key,
    required this.usuario,
    required this.repositorio,
    this.onSesionExpirada,
  });

  final Usuario usuario;
  final IncidenciasRepository repositorio;

  final VoidCallback? onSesionExpirada; // Se llama cuando la API responde 401, main.dart cierra la sesión.

  @override
  State<ListadoIncidenciasPage> createState() => _ListadoIncidenciasPageState();
}

class _ListadoIncidenciasPageState extends State<ListadoIncidenciasPage> {
  final _buscador = TextEditingController();

  // Espera a que el usuario deje de escribir para no hacer una petición por cada letra.
  Timer? _espera;

  EstadoIncidencia? _estado;
  int? _idCategoria;
  List<Categoria> _categorias = const [];

  List<Incidencia> _incidencias = const [];
  bool _cargando = true;
  String? _error;

  /// Número de la última petición. Si llegan respuestas antigua se ignoran
  int _peticion = 0;
  bool _saliendo = false;

  bool get _hayFiltros =>
      _buscador.text.trim().isNotEmpty ||
      _estado != null ||
      _idCategoria != null;

  @override
  void initState() {
    super.initState();
    _cargarCategorias();
    _cargar();
  }

  @override
  void dispose() {
    _espera?.cancel();
    _buscador.dispose();
    super.dispose();
  }

  Future<void> _cargarCategorias() async {
    try {
      final categorias = await widget.repositorio.obtenerCategorias();
      if (mounted) setState(() => _categorias = categorias);
    } on ApiException catch (e) {
      if (e.sesionExpirada) _sesionExpirada();
    }
  }

  Future<void> _cargar() async {
    _espera?.cancel();
    final peticion = ++_peticion;
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final lista = await widget.repositorio.obtenerIncidencias(
        texto: _buscador.text,
        estado: _estado,
        idCategoria: _idCategoria,
      );
      if (!mounted || peticion != _peticion) return;
      setState(() {
        _incidencias = lista;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted || peticion != _peticion) return;
      setState(() {
        _error = e.mensaje;
        _cargando = false;
      });
      if (e.sesionExpirada) _sesionExpirada();
    }
  }

  void _alEscribir(String _) {
    setState(() {}); // Muestra u oculta el botón para borrar la búsqueda
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 400), _cargar);
  }

  void _borrarBusqueda() {
    _buscador.clear();
    _cargar();
  }

  void _quitarFiltros() {
    _buscador.clear();
    setState(() {
      _estado = null;
      _idCategoria = null;
    });
    _cargar();
  }

  Future<void> _abrirDetalle(Incidencia incidencia) async {
    await Navigator.pushNamed(
      context,
      Rutas.detalleIncidencia,
      arguments: incidencia.id,
    );
    // Al volver se recarga, en caso de que la incidencia tuviera un cambio en el detalle
    if (mounted) _cargar();
  }

  // Token expirado: Se cierran las pantallas abiertas para que
  // el login quede visible y se cierra la sesión
  void _sesionExpirada() {
    if (_saliendo || !mounted) return;
    _saliendo = true;
    Navigator.of(context).popUntil((ruta) => ruta.isFirst);
    widget.onSesionExpirada?.call();
  }

  // Ancho a partir del cual los filtros se muestran a un lado de la lista
  static const _anchoWeb = 720.0;

  // Cuántos filtros de la hoja hay activos (para el número del botón)
  int get _filtrosActivos =>
      (_estado == null ? 0 : 1) + (_idCategoria == null ? 0 : 1);

  void _aplicarFiltros(EstadoIncidencia? estado, int? idCategoria) {
    setState(() {
      _estado = estado;
      _idCategoria = idCategoria;
    });
    _cargar();
  }

  // Celular
  Future<void> _abrirFiltros() async {
    final resultado = await showModalBottomSheet<(EstadoIncidencia?, int?)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _HojaFiltros(
        estado: _estado,
        idCategoria: _idCategoria,
        categorias: _categorias,
      ),
    );
    if (resultado == null) return;
    _aplicarFiltros(resultado.$1, resultado.$2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.usuario.esOperador ? 'Incidencias' : 'Mis incidencias',
        ),
        actions: [
          const BotonTema(),
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _cargar,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) =>
            constraints.maxWidth >= _anchoWeb ? _vistaWeb() : _vistaCelular(),
      ),
    );
  }

  // Celular
  Widget _vistaCelular() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(child: _buscadorCampo()),
              const SizedBox(width: 8),
              Badge(
                isLabelVisible: _filtrosActivos > 0,
                label: Text('$_filtrosActivos'),
                child: OutlinedButton.icon(
                  onPressed: _abrirFiltros,
                  icon: const Icon(Icons.tune),
                  label: const Text('Filtros'),
                ),
              ),
            ],
          ),
        ),
        _resumenFiltros(),
        _barraCarga(),
        Expanded(child: _listaConRefresco()),
      ],
    );
  }

  // Web y pantallas anchas
  Widget _vistaWeb() {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 280,
              child: ListView(
                key: const ValueKey('panel-filtros'),
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Filtra tus resultados',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _buscadorCampo(),
                  const SizedBox(height: 16),
                  _SeccionFiltro<EstadoIncidencia>(
                    titulo: 'Estado',
                    opciones: [
                      for (final e in EstadoIncidencia.values) (e, e.etiqueta),
                    ],
                    seleccionado: _estado,
                    estilo: (e) => estiloEstado(context, e),
                    comoLista: true,
                    onCambiar: (estado) =>
                        _aplicarFiltros(estado, _idCategoria),
                  ),
                  if (_categorias.isNotEmpty) ...[
                    const Divider(height: 32),
                    _SeccionFiltro<int>(
                      titulo: 'Categoría',
                      opciones: [for (final c in _categorias) (c.id, c.nombre)],
                      seleccionado: _idCategoria,
                      comoLista: true,
                      onCambiar: (id) => _aplicarFiltros(_estado, id),
                    ),
                  ],
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Text(
                      _textoCantidad(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  _resumenFiltros(),
                  _barraCarga(),
                  Expanded(child: _listaConRefresco()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _textoCantidad() {
    if (_error != null) return '';
    if (_cargando && _incidencias.isEmpty) return 'Cargando…';
    return _incidencias.length == 1
        ? '1 incidencia'
        : '${_incidencias.length} incidencias';
  }

  Widget _buscadorCampo() {
    return TextField(
      controller: _buscador,
      onChanged: _alEscribir,
      onSubmitted: (_) => _cargar(),
      textInputAction: TextInputAction.search,
      // `q`: máximo 100 caracteres (docs/api.md).
      inputFormatters: [LengthLimitingTextInputFormatter(100)],
      decoration: InputDecoration(
        hintText: 'Buscar incidencias',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _buscador.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Borrar búsqueda',
                icon: const Icon(Icons.clear),
                onPressed: _borrarBusqueda,
              ),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _resumenFiltros() {
    if (!_hayFiltros) return const SizedBox(height: 8);

    final categoria = _categorias
        .where((c) => c.id == _idCategoria)
        .firstOrNull;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (_estado != null)
            if (_estado != null)
              _ChipAplicado(
                texto: _estado!.etiqueta,
                estilo: estiloEstado(context, _estado!),
                onQuitar: () => _aplicarFiltros(null, _idCategoria),
              ),
          if (categoria != null)
            _ChipAplicado(
              texto: categoria.nombre,
              onQuitar: () => _aplicarFiltros(_estado, null),
            ),
          TextButton.icon(
            onPressed: _quitarFiltros,
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Limpiar filtros'),
          ),
        ],
      ),
    );
  }

  Widget _barraCarga() {
    return SizedBox(
      height: 4,
      child: _cargando && _incidencias.isNotEmpty
          ? const LinearProgressIndicator()
          : null,
    );
  }

  Widget _listaConRefresco() {
    return RefreshIndicator(onRefresh: _cargar, child: _contenido());
  }

  Widget _contenido() {
    // Primera carga: Todavía no hay nada que mostrar
    if (_cargando && _incidencias.isEmpty && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _Mensaje(
        icono: Icons.cloud_off,
        color: Theme.of(context).colorScheme.error,
        texto: _error!,
        accion: TextButton.icon(
          onPressed: _cargar,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      );
    }

    if (_incidencias.isEmpty) {
      return _Mensaje(
        icono: Icons.inbox_outlined,
        texto: _hayFiltros
            ? 'No hay incidencias con esos filtros'
            : widget.usuario.esOperador
            ? 'No hay incidencias registradas'
            : 'Aún no has reportado incidencias',
        accion: _hayFiltros
            ? TextButton(
                onPressed: _quitarFiltros,
                child: const Text('Limpiar filtros'),
              )
            : null,
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: _incidencias.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final incidencia = _incidencias[index];
        return _TarjetaIncidencia(
          incidencia: incidencia,
          mostrarReportante: widget.usuario.esOperador,
          onTap: () => _abrirDetalle(incidencia),
        );
      },
    );
  }
}

// Widgets auxiliares

class _TarjetaIncidencia extends StatelessWidget {
  const _TarjetaIncidencia({
    required this.incidencia,
    required this.mostrarReportante,
    required this.onTap,
  });

  final Incidencia incidencia;
  final bool mostrarReportante;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        title: Text(
          incidencia.titulo,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${incidencia.categoria.nombre}   '
              '${_formatearFecha(incidencia.fechaCreacion)}',
            ),
            if (mostrarReportante)
              Text('Reportó: ${incidencia.reportadoPor.nombre}'),
            const SizedBox(height: 6),
            EstadoChip(estado: incidencia.estado),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({
    required this.icono,
    required this.texto,
    this.color,
    this.accion,
  });

  final IconData icono;
  final String texto;
  final Color? color;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 32),
        Icon(icono, size: 48, color: color),
        const SizedBox(height: 12),
        Text(texto, textAlign: TextAlign.center),
        if (accion != null) ...[
          const SizedBox(height: 8),
          Center(child: accion),
        ],
      ],
    );
  }
}

String _formatearFecha(DateTime fecha) {
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} '
      '${dos(fecha.hour)}:${dos(fecha.minute)}';
}

class _SeccionFiltro<T> extends StatelessWidget {
  const _SeccionFiltro({
    required this.titulo,
    required this.opciones,
    required this.seleccionado,
    required this.onCambiar,
    this.estilo,
    this.comoLista = false,
  });

  final String titulo;

  // (valor, texto) de cada opción.
  final List<(T, String)> opciones;
  final T? seleccionado;
  final ValueChanged<T?> onCambiar;

  // Colores de cada opción (los estados)
  final EstiloEstado Function(T valor)? estilo;
  final bool comoLista;
  void _tocar(T valor) => onCambiar(valor == seleccionado ? null : valor);

  // Chip de la hoja del celular
  Widget _chip(BuildContext context, T valor, String texto) {
    final colores = Theme.of(context).colorScheme;
    final elegido = valor == seleccionado;
    final e = estilo?.call(valor);

    final fondo = e?.fondo ?? colores.surface;
    final borde = e?.borde ?? colores.outline;
    final colorTexto = e?.texto ?? colores.onSurface;

    return ChoiceChip(
      avatar: e == null ? null : Icon(e.icono, size: 16, color: colorTexto),
      label: Text(texto),
      labelStyle: TextStyle(
        color: colorTexto,
        fontWeight: elegido ? FontWeight.bold : null,
      ),
      backgroundColor: fondo,
      // Elegido: el mismo color, un poco más intenso.
      selectedColor: Color.alphaBlend(borde.withValues(alpha: 0.35), fondo),
      showCheckmark: false,
      side: BorderSide(color: borde, width: elegido ? 2 : 1),
      selected: elegido,
      onSelected: (_) => _tocar(valor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final encabezado = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(titulo, style: theme.textTheme.titleSmall),
    );

    if (comoLista) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          encabezado,
          for (final (valor, texto) in opciones)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: estilo == null ? null : _IconoEstado(estilo!(valor)),
              title: Text(texto,
                style: valor == seleccionado
                    ? const TextStyle(fontWeight: FontWeight.bold)
                    : null,
              ),
              selected: valor == seleccionado,
              selectedTileColor: theme.colorScheme.primary.withValues(
                alpha: 0.12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onTap: () => _tocar(valor),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        encabezado,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (valor, texto) in opciones) _chip(context, valor, texto),
          ],
        ),
      ],
    );
  }
}

// Ícono del estado en un círculo con sus colores (panel web)
class _IconoEstado extends StatelessWidget {
  const _IconoEstado(this.estilo);

  final EstiloEstado estilo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: estilo.fondo,
        shape: BoxShape.circle,
        border: Border.all(color: estilo.borde),
      ),
      child: Icon(estilo.icono, size: 14, color: estilo.texto),
    );
  }
}

class _ChipAplicado extends StatelessWidget {
  const _ChipAplicado({
    required this.texto,
    required this.onQuitar,
    this.estilo,
  });

  final String texto;
  final VoidCallback onQuitar;
  final EstiloEstado? estilo;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final colorTexto = estilo?.texto ?? colores.onSurface;

    return InputChip(
      avatar: estilo == null
          ? null
          : Icon(estilo!.icono, size: 16, color: colorTexto),
      label: Text(texto),
      labelStyle: TextStyle(color: colorTexto),
      backgroundColor: estilo?.fondo ?? colores.surface,
      side: BorderSide(color: estilo?.borde ?? colores.outline),
      deleteIconColor: colorTexto,
      deleteButtonTooltipMessage: 'Quitar filtro',
      onDeleted: onQuitar,
    );
  }
}

// Hoja que sube desde abajo en el celular
class _HojaFiltros extends StatefulWidget {
  const _HojaFiltros({
    required this.estado,
    required this.idCategoria,
    required this.categorias,
  });

  final EstadoIncidencia? estado;
  final int? idCategoria;
  final List<Categoria> categorias;

  @override
  State<_HojaFiltros> createState() => _HojaFiltrosState();
}

class _HojaFiltrosState extends State<_HojaFiltros> {
  late EstadoIncidencia? _estado = widget.estado;
  late int? _idCategoria = widget.idCategoria;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Filtros',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _estado = null;
                    _idCategoria = null;
                  }),
                  child: const Text('Limpiar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _SeccionFiltro<EstadoIncidencia>(
              titulo: 'Estado',
              opciones: [
                for (final e in EstadoIncidencia.values) (e, e.etiqueta),
              ],
              seleccionado: _estado,
              estilo: (e) => estiloEstado(context, e),
              onCambiar: (estado) => setState(() => _estado = estado),
            ),
            if (widget.categorias.isNotEmpty) ...[
              const Divider(height: 32),
              _SeccionFiltro<int>(
                titulo: 'Categoría',
                opciones: [for (final c in widget.categorias) (c.id, c.nombre)],
                seleccionado: _idCategoria,
                onCambiar: (id) => setState(() => _idCategoria = id),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context, (_estado, _idCategoria)),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Ver resultados'),
            ),
          ],
        ),
      ),
    );
  }
}
