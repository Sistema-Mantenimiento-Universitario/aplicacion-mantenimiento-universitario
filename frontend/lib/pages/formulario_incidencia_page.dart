import 'package:flutter/material.dart';

import '../data/incidencias_repository.dart';
import '../models/categoria.dart';
import '../models/datos_incidencia.dart';
import '../models/estado_incidencia.dart';
import '../models/incidencia.dart';
import '../models/usuario.dart';

class FormularioIncidenciaPage extends StatefulWidget {
  const FormularioIncidenciaPage({
    super.key,
    required this.usuario,
    required this.repositorio,
    this.incidencia,
    this.onSesionExpirada,
  });

  final Usuario usuario;
  final IncidenciasRepository repositorio;

  // null cuando es una incidencia nueva
  final Incidencia? incidencia;

  // Se llama cuando la API responde 401, main.dart cierra la sesión
  final VoidCallback? onSesionExpirada;

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
  int? _idCategoria;

  List<Categoria> _categorias = const [];
  bool _cargandoCategorias = true;
  String? _errorCategorias;

  bool _guardando = false;
  bool _saliendo = false;

  // Después del primer intento de guardar los errores se actualizan al escribir
  bool _validarAlEscribir = false;

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
    _idCategoria = incidencia?.categoria.id;
    _cargarCategorias();
  }

  @override
  void dispose() {
    _titulo.dispose();
    _descripcion.dispose();
    _ubicacion.dispose();
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

  Future<void> _guardar() async {
    setState(() {
      _erroresServidor = const {};
      _validarAlEscribir = true;
    });
    if (!_formulario.currentState!.validate()) return;

    final ubicacion = _ubicacion.text.trim();
    final datos = DatosIncidencia(
      titulo: _titulo.text.trim(),
      descripcion: _descripcion.text.trim(),
      idCategoria: _idCategoria!,
      ubicacionTexto: ubicacion.isEmpty ? null : ubicacion,
    );

    setState(() => _guardando = true);
    try {
      final guardada = widget.esEdicion
          ? await widget.repositorio.editarIncidencia(
              widget.incidencia!.id,
              datos,
            )
          : await widget.repositorio.crearIncidencia(datos);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.esEdicion ? 'Cambios guardados' : 'Incidencia creada',
          ),
        ),
      );
      // Regresa a la pantalla anterior con la incidencia guardada
      Navigator.pop(context, guardada);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
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
      autovalidateMode: _validarAlEscribir
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _titulo,
            enabled: !_guardando,
            maxLength: LimitesIncidencia.tituloMax,
            textInputAction: TextInputAction.next,
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
          const SizedBox(height: 8),

          TextFormField(
            controller: _ubicacion,
            enabled: !_guardando,
            maxLength: LimitesIncidencia.ubicacionMax,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Ubicación',
              hintText: 'Ej. Edificio 3, planta baja',
              prefixIcon: Icon(Icons.place_outlined),
            ),
            onChanged: (_) => _quitarErrorServidor('ubicacion_texto'),
            validator: (valor) => _validarTexto(
              valor,
              campo: 'ubicacion_texto',
              nombre: 'la ubicación',
              minimo: LimitesIncidencia.ubicacionMin,
              maximo: LimitesIncidencia.ubicacionMax,
            ),
          ),
          const SizedBox(height: 16),
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
              _guardando
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
