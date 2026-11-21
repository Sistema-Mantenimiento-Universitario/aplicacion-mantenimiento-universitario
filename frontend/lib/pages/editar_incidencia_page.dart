import 'package:flutter/material.dart';

import '../data/incidencias_repository.dart';
import '../models/incidencia.dart';
import '../models/usuario.dart';
import 'formulario_incidencia_page.dart';

// Abre el formulario en modo edición.
// Si llega la incidencia (desde el detalle) se usa directo; si no, como al
// recargar la página en web, se carga con el id de la URL
class EditarIncidenciaPage extends StatefulWidget {
  const EditarIncidenciaPage({
    super.key,
    required this.usuario,
    required this.repositorio,
    required this.idIncidencia,
    this.incidencia,
    this.onSesionExpirada,
  });

  final Usuario usuario;
  final IncidenciasRepository repositorio;
  final int idIncidencia;
  final Incidencia? incidencia;
  final VoidCallback? onSesionExpirada;

  @override
  State<EditarIncidenciaPage> createState() => _EditarIncidenciaPageState();
}

class _EditarIncidenciaPageState extends State<EditarIncidenciaPage> {
  Incidencia? _incidencia;
  String? _error;

  @override
  void initState() {
    super.initState();
    _incidencia = widget.incidencia;
    if (_incidencia == null) _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final incidencia = await widget.repositorio.obtenerIncidencia(
        widget.idIncidencia,
      );
      if (mounted) setState(() => _incidencia = incidencia);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.sesionExpirada) {
        Navigator.of(context).popUntil((ruta) => ruta.isFirst);
        widget.onSesionExpirada?.call();
        return;
      }
      setState(() => _error = e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    final incidencia = _incidencia;
    if (incidencia != null) {
      return FormularioIncidenciaPage(
        usuario: widget.usuario,
        repositorio: widget.repositorio,
        incidencia: incidencia,
        onSesionExpirada: widget.onSesionExpirada,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Editar incidencia')),
      body: Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 40,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 8),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _cargar,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// Se muestra si la URL de detalle o edición no trae el id de la incidencia
class IncidenciaNoIndicadaPage extends StatelessWidget {
  const IncidenciaNoIndicadaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Incidencia no indicada')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 40),
              const SizedBox(height: 8),
              const Text(
                'No se indicó qué incidencia abrir. '
                'Ábrela desde Mis incidencias.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((ruta) => ruta.isFirst),
                child: const Text('Ir al inicio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
