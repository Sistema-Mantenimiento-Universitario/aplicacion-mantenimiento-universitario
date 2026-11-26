import 'package:flutter/material.dart';

import '../data/incidencias_repository.dart';
import '../models/categoria.dart';
import '../models/datos_incidencia.dart';
import '../models/estado_incidencia.dart';
import '../models/incidencia.dart';
import '../models/usuario.dart';
import '../services/servicio_imagenes.dart';
import '../services/servicio_ubicacion.dart';

class FormularioIncidenciaPage extends StatefulWidget {
  const FormularioIncidenciaPage({
    super.key,
    required this.usuario,
    required this.repositorio,
    this.incidencia,
    this.onSesionExpirada,
    this.servicioUbicacion = const ServicioUbicacion(),
    this.servicioImagenes,
  });

  final Usuario usuario;
  final IncidenciasRepository repositorio;

  // null cuando es una incidencia nueva
  final Incidencia? incidencia;

  // Se llama cuando la API responde 401, main.dart cierra la sesión
  final VoidCallback? onSesionExpirada;

  // GPS y cámara
  final ServicioUbicacion servicioUbicacion;
  final ServicioImagenes? servicioImagenes;

  bool get esEdicion => incidencia != null;

  @override
  State<FormularioIncidenciaPage> createState() =>
      _FormularioIncidenciaPageState();
}

class _FormularioIncidenciaPageState extends State<FormularioIncidenciaPage> {
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _titulo;
  late final TextEditingController _descripcion;
  late final TextEditingController _ubicacion;
  late final TextEditingController _latitud;
  late final TextEditingController _longitud;
  int? _idCategoria;

  // Para volver a validar la ubicación en texto cuando cambian las coordenadas
  final _campoUbicacion = GlobalKey<FormFieldState<String>>();

  late final ServicioImagenes _imagenes =
      widget.servicioImagenes ?? ServicioImagenes();

  List<Categoria> _categorias = const [];
  bool _cargandoCategorias = true;
  String? _errorCategorias;

  bool _guardando = false;
  bool _subiendoFotos = false;
  bool _saliendo = false;

  // GPS
  bool _buscandoUbicacion = false;
  String? _avisoUbicacion;

  // Fotos elegidas que se subirán al guardar
  final List<FotoSeleccionada> _fotos = [];
  String? _avisoFotos;

  // Errores por campo que devolvió el backend (400)
  Map<String, String> _erroresServidor = const {};

  // Solo se puede editar una incidencia pendiente y del usuario que la creó
  bool get _puedeEditar {
    final incidencia = widget.incidencia;
    return incidencia == null ||
        (incidencia.estado == EstadoIncidencia.pendiente &&
            incidencia.reportadoPor.id == widget.usuario.id);
  }

  @override
  void initState() {
    super.initState();
    // En modo edición los campos empiezan con los datos de la incidencia
    final incidencia = widget.incidencia;
    _titulo = TextEditingController(text: incidencia?.titulo);
    _descripcion = TextEditingController(text: incidencia?.descripcion);
    _ubicacion = TextEditingController(text: incidencia?.ubicacionTexto);
    _latitud = TextEditingController(
      text: incidencia?.latitud?.toStringAsFixed(6),
    );
    _longitud = TextEditingController(
      text: incidencia?.longitud?.toStringAsFixed(6),
    );
    _idCategoria = incidencia?.categoria.id;
    _cargarCategorias();
  }

  @override
  void dispose() {
    _titulo.dispose();
    _descripcion.dispose();
    _ubicacion.dispose();
    _latitud.dispose();
    _longitud.dispose();
    super.dispose();
  }

  Future<void> _cargarCategorias() async {
    setState(() {
      _cargandoCategorias = true;
      _errorCategorias = null;
    });

    try {
      final categorias = await widget.repositorio.obtenerCategorias();
      if (!mounted) return;
      setState(() {
        // Solo se puede elegir una categoría activa
        _categorias = categorias.where((c) => c.activa).toList();
        if (!_categorias.any((c) => c.id == _idCategoria)) {
          _idCategoria = null;
        }
        _cargandoCategorias = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCategorias = e.mensaje;
        _cargandoCategorias = false;
      });
      if (e.sesionExpirada) _sesionExpirada();
    }
  }

  // Número escrito en un campo acepta coma o punto decimal
  static double? _numero(TextEditingController campo) =>
      double.tryParse(campo.text.trim().replaceAll(',', '.'));

  bool get _hayCoordenadas =>
      _numero(_latitud) != null && _numero(_longitud) != null;

  // Pide la ubicación al GPS y la escribe en los campos de coordenadas
  Future<void> _usarMiUbicacion() async {
    setState(() {
      _buscandoUbicacion = true;
      _avisoUbicacion = null;
    });
    try {
      final coordenadas = await widget.servicioUbicacion.obtenerUbicacion();
      if (!mounted) return;
      setState(() {
        _latitud.text = coordenadas.latitud.toStringAsFixed(6);
        _longitud.text = coordenadas.longitud.toStringAsFixed(6);
      });
      _alCambiarCoordenadas();
    } on UbicacionException catch (e) {
      if (mounted) setState(() => _avisoUbicacion = e.mensaje);
    } finally {
      if (mounted) setState(() => _buscandoUbicacion = false);
    }
  }

  // Con coordenadas, la ubicación en texto deja de ser obligatoria
  void _alCambiarCoordenadas() {
    _quitarErrorServidor('latitud');
    _quitarErrorServidor('longitud');
    final campo = _campoUbicacion.currentState;
    if (campo != null && campo.hasError) campo.validate();
  }

  // Abre la cámara o la galería y agrega la foto a la lista
  Future<void> _agregarFoto(Future<FotoSeleccionada?> Function() elegir) async {
    setState(() => _avisoFotos = null);
    try {
      final foto = await elegir();
      if (foto == null || !mounted) return;
      setState(() => _fotos.add(foto));
    } on ImagenException catch (e) {
      if (mounted) setState(() => _avisoFotos = e.mensaje);
    }
  }

  Future<void> _guardar() async {
    setState(() {
      _erroresServidor = const {};
    });
    if (!_formulario.currentState!.validate()) return;

    final ubicacion = _ubicacion.text.trim();
    final latitud = _numero(_latitud);
    final longitud = _numero(_longitud);
    final datos = DatosIncidencia(
      titulo: _titulo.text.trim(),
      descripcion: _descripcion.text.trim(),
      idCategoria: _idCategoria!,
      ubicacionTexto: ubicacion.isEmpty ? null : ubicacion,
      latitud: latitud == null ? null : ServicioUbicacion.redondear(latitud),
      longitud: longitud == null ? null : ServicioUbicacion.redondear(longitud),
    );

    setState(() => _guardando = true);
    try {
      final guardada = widget.esEdicion
          ? await widget.repositorio.editarIncidencia(
              widget.incidencia!.id,
              datos,
            )
          : await widget.repositorio.crearIncidencia(datos);

      var mensaje = widget.esEdicion
          ? 'Cambios guardados'
          : 'Incidencia creada';

      // Las fotos se suben después con el id de la incidencia
      if (_fotos.isNotEmpty) {
        if (mounted) setState(() => _subiendoFotos = true);
        try {
          await widget.repositorio.subirEvidencias(guardada.id, _fotos);
        } on ApiException catch (e) {
          if (e.sesionExpirada) rethrow;
          mensaje =
              '$mensaje, pero no se pudieron subir las fotos (${e.mensaje}). '
              'Puedes agregarlas desde Editar';
        }
      }
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensaje)));
      // Regresa a la pantalla anterior con la incidencia guardada
      Navigator.pop(context, guardada);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _subiendoFotos = false;
        _erroresServidor = e.errores;
      });
      if (e.sesionExpirada) {
        _sesionExpirada();
        return;
      }
      // Muestra los errores del backend debajo de cada campo
      if (e.errores.isNotEmpty) _formulario.currentState!.validate();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  // Token expirado: se cierran las pantallas abiertas y se cierra la sesión
  void _sesionExpirada() {
    if (_saliendo || !mounted) return;
    _saliendo = true;
    Navigator.of(context).popUntil((ruta) => ruta.isFirst);
    widget.onSesionExpirada?.call();
  }

  // Al corregir un campo se quita el error que había mandado el backend
  void _quitarErrorServidor(String campo) {
    if (!_erroresServidor.containsKey(campo)) return;
    setState(() {
      _erroresServidor = Map.of(_erroresServidor)..remove(campo);
    });
  }

  // Valida un texto obligatorio con mínimo y máximo de caracteres
  String? _validarTexto(
    String? valor, {
    required String campo,
    required String nombre,
    required int minimo,
    required int maximo,
  }) {
    final errorServidor = _erroresServidor[campo];
    if (errorServidor != null) return errorServidor;

    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return 'Escribe $nombre';
    if (texto.length < minimo) return 'Debe tener al menos $minimo caracteres';
    if (texto.length > maximo) return 'Debe tener máximo $maximo caracteres';
    return null;
  }

  // La ubicación en texto es obligatoria solo si no hay coordenadas
  String? _validarUbicacion(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty && _erroresServidor['ubicacion_texto'] == null) {
      return _hayCoordenadas
          ? null
          : 'Escribe la ubicación o usa tu ubicación actual';
    }
    return _validarTexto(
      valor,
      campo: 'ubicacion_texto',
      nombre: 'la ubicación',
      minimo: LimitesIncidencia.ubicacionMin,
      maximo: LimitesIncidencia.ubicacionMax,
    );
  }

  // Coordenada opcional: Si se escribe una también se pide la otra
  String? _validarCoordenada(
    TextEditingController campo, {
    required String clave,
    required double maximo,
    required TextEditingController otra,
    required String nombre,
  }) {
    final errorServidor = _erroresServidor[clave];
    if (errorServidor != null) return errorServidor;

    final texto = campo.text.trim();
    if (texto.isEmpty) {
      return otra.text.trim().isEmpty ? null : 'Escribe también $nombre';
    }
    final valor = _numero(campo);
    if (valor == null) return 'Escribe un número';
    if (valor < -maximo || valor > maximo) {
      return 'Debe estar entre -${maximo.toInt()} y ${maximo.toInt()}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.esEdicion ? 'Editar incidencia' : 'Nueva incidencia',
        ),
      ),
      body: SafeArea(
        child: Center(
          // En pantallas anchas el formulario no se estira de lado a lado
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: _contenido(),
          ),
        ),
      ),
    );
  }

  Widget _contenido() {
    if (!_puedeEditar) {
      return const _Aviso(
        icono: Icons.lock_outline,
        mensaje: 'Solo puedes editar incidencias pendientes que tú reportaste',
      );
    }
    if (_cargandoCategorias) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorCategorias != null) {
      return _Aviso(
        icono: Icons.cloud_off_outlined,
        mensaje: _errorCategorias!,
        onReintentar: _cargarCategorias,
      );
    }

    return Form(
      key: _formulario,
      autovalidateMode: AutovalidateMode.onUnfocus,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _titulo,
            enabled: !_guardando,
            maxLength: LimitesIncidencia.tituloMax,
            textInputAction: TextInputAction.next,
            autovalidateMode: AutovalidateMode.onUserInteractionIfError,
            decoration: const InputDecoration(
              labelText: 'Título',
              hintText: 'Ej. Lámpara fundida en el pasillo',
              prefixIcon: Icon(Icons.title),
            ),
            onChanged: (_) => _quitarErrorServidor('titulo'),
            validator: (valor) => _validarTexto(
              valor,
              campo: 'titulo',
              nombre: 'el título',
              minimo: LimitesIncidencia.tituloMin,
              maximo: LimitesIncidencia.tituloMax,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _idCategoria,
            autovalidateMode: AutovalidateMode.onUserInteractionIfError,
            decoration: const InputDecoration(
              labelText: 'Categoría',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: [
              for (final categoria in _categorias)
                DropdownMenuItem(
                  value: categoria.id,
                  child: Text(categoria.nombre),
                ),
            ],
            onChanged: _guardando
                ? null
                : (valor) {
                    setState(() => _idCategoria = valor);
                    _quitarErrorServidor('id_categoria');
                  },
            validator: (valor) =>
                _erroresServidor['id_categoria'] ??
                (valor == null ? 'Elige una categoría' : null),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _descripcion,
            enabled: !_guardando,
            minLines: 3,
            maxLines: 6,
            maxLength: LimitesIncidencia.descripcionMax,
            keyboardType: TextInputType.multiline,
            autovalidateMode: AutovalidateMode.onUserInteractionIfError,
            decoration: const InputDecoration(
              labelText: 'Descripción',
              hintText: '¿Qué pasa y desde cuándo?',
              alignLabelWithHint: true,
            ),
            onChanged: (_) => _quitarErrorServidor('descripcion'),
            validator: (valor) => _validarTexto(
              valor,
              campo: 'descripcion',
              nombre: 'la descripción',
              minimo: LimitesIncidencia.descripcionMin,
              maximo: LimitesIncidencia.descripcionMax,
            ),
          ),
          const SizedBox(height: 16),
          ..._seccionUbicacion(),
          const SizedBox(height: 16),
          ..._seccionFotos(),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _guardando ? null : _guardar,
            icon: _guardando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              _subiendoFotos
                  ? 'Subiendo fotos…'
                  : _guardando
                  ? 'Guardando…'
                  : widget.esEdicion
                  ? 'Guardar cambios'
                  : 'Crear incidencia',
            ),
          ),
        ],
      ),
    );
  }

  // Ubicación: texto, coordenadas (GPS o a mano) o ambas
  List<Widget> _seccionUbicacion() {
    return [
      TextFormField(
        key: _campoUbicacion,
        controller: _ubicacion,
        enabled: !_guardando,
        maxLength: LimitesIncidencia.ubicacionMax,
        autovalidateMode: AutovalidateMode.onUserInteractionIfError,
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(
          labelText: 'Ubicación',
          hintText: 'Ej. Edificio 3, planta baja',
          prefixIcon: Icon(Icons.place_outlined),
        ),
        onChanged: (_) => _quitarErrorServidor('ubicacion_texto'),
        validator: _validarUbicacion,
      ),
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              controller: _latitud,
              enabled: !_guardando,
              autovalidateMode: AutovalidateMode.onUserInteractionIfError,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Latitud',
                hintText: 'Ej. 21.913600',
              ),
              onChanged: (_) => _alCambiarCoordenadas(),
              validator: (_) => _validarCoordenada(
                _latitud,
                clave: 'latitud',
                maximo: LimitesIncidencia.latitudMax,
                otra: _longitud,
                nombre: 'la latitud',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _longitud,
              enabled: !_guardando,
              autovalidateMode: AutovalidateMode.onUserInteractionIfError,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Longitud',
                hintText: 'Ej. -102.315800',
              ),
              onChanged: (_) => _alCambiarCoordenadas(),
              validator: (_) => _validarCoordenada(
                _longitud,
                clave: 'longitud',
                maximo: LimitesIncidencia.longitudMax,
                otra: _latitud,
                nombre: 'la longitud',
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: _guardando || _buscandoUbicacion ? null : _usarMiUbicacion,
          icon: _buscandoUbicacion
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location),
          label: Text(
            _buscandoUbicacion ? 'Buscando ubicación…' : 'Usar mi ubicación',
          ),
        ),
      ),
      if (_avisoUbicacion != null) _AvisoSeccion(mensaje: _avisoUbicacion!),
    ];
  }

  // Fotos: Cámara en el celular. En web y escritorio, elegir un archivo
  List<Widget> _seccionFotos() {
    final theme = Theme.of(context);
    final lleno = _fotos.length >= LimitesIncidencia.fotosMax;
    final desactivado = _guardando || lleno;

    return [
      Text(
        'Fotos (opcional) · ${_fotos.length} de ${LimitesIncidencia.fotosMax}',
        style: theme.textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      if (_fotos.isNotEmpty) ...[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var n = 0; n < _fotos.length; n++)
              _MiniaturaFoto(
                foto: _fotos[n],
                onQuitar: _guardando
                    ? null
                    : () => setState(() => _fotos.removeAt(n)),
              ),
          ],
        ),
        const SizedBox(height: 8),
      ],
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (_imagenes.hayCamara)
            OutlinedButton.icon(
              onPressed: desactivado
                  ? null
                  : () => _agregarFoto(_imagenes.tomarFoto),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Tomar foto'),
            ),
          OutlinedButton.icon(
            onPressed: desactivado
                ? null
                : () => _agregarFoto(_imagenes.elegirDeGaleria),
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(_imagenes.hayCamara ? 'Galería' : 'Elegir imagen'),
          ),
        ],
      ),
      if (_avisoFotos != null) _AvisoSeccion(mensaje: _avisoFotos!),
    ];
  }
}

// Vista previa de una foto elegida, con botón para quitarla
class _MiniaturaFoto extends StatelessWidget {
  const _MiniaturaFoto({required this.foto, required this.onQuitar});

  final FotoSeleccionada foto;
  final VoidCallback? onQuitar;

  void _ampliar(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _VistaFoto(foto: foto),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            // Image.memory funciona en todas las plataformas, también en web
            child: Tooltip(
              message: 'Ver foto',
              child: GestureDetector(
                onTap: () => _ampliar(context),
                // Hero: la miniatura "vuela" a la vista en grande
                child: Hero(
                  tag: foto,
                  // Image.memory funciona en todas las plataformas
                  child: Image.memory(foto.bytes, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: IconButton.filledTonal(
              tooltip: 'Quitar foto',
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              onPressed: onQuitar,
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  }
}

class _VistaFoto extends StatelessWidget {
  const _VistaFoto({required this.foto});

  final FotoSeleccionada foto;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Vista previa'),
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 4,
          child: Hero(
            tag: foto,
            child: Image.memory(foto.bytes, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

// Mensaje de error debajo de una sección (GPS o fotos)
class _AvisoSeccion extends StatelessWidget {
  const _AvisoSeccion({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(mensaje, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}

// Mensaje centrado con icono y, si se indica, botón para reintentar
class _Aviso extends StatelessWidget {
  const _Aviso({required this.icono, required this.mensaje, this.onReintentar});

  final IconData icono;
  final String mensaje;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
            if (onReintentar != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
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
