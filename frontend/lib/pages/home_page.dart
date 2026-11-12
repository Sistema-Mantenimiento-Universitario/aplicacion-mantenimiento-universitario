import 'package:flutter/material.dart';

import '../data/incidencias_repository.dart';
import '../models/usuario.dart';
import '../theme/app_theme.dart';
import 'rutas.dart';

/// F5 · Pantalla principal según el rol.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.usuario,
    required this.repositorio,
    this.onCerrarSesion,
  });

  final Usuario usuario;
  final IncidenciasRepository repositorio;
  final VoidCallback? onCerrarSesion;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<Map<String, int>> _resumen;

  @override
  void initState() {
    super.initState();
    _resumen = widget.repositorio.obtenerResumenPorEstado();
  }

  void _cargar() {
    setState(() {
      _resumen = widget.repositorio.obtenerResumenPorEstado();
    });
  }

  Future<void> _refrescar() async {
    _cargar();
    try {
      await _resumen;
    } catch (_) {
      // El error se muestra en el FutureBuilder.
    }
  }

  Future<void> _ir(String ruta) async {
    await Navigator.pushNamed(context, ruta, arguments: widget.usuario);
    // Al volver (p. ej. tras crear una incidencia) se actualiza el resumen.
    if (mounted) _cargar();
  }

  List<_Acceso> get _accesos {
    if (widget.usuario.esOperador) {
      return const [
        _Acceso(
          icono: Icons.admin_panel_settings_outlined,
          titulo: 'Administración de incidencias',
          subtitulo: 'Revisa, asigna y cambia el estado de las incidencias',
          ruta: Rutas.adminIncidencias,
        ),
      ];
    }
    return const [
      _Acceso(
        icono: Icons.add_circle_outline,
        titulo: 'Nueva incidencia',
        subtitulo: 'Reporta un problema',
        ruta: Rutas.nuevaIncidencia,
      ),
      _Acceso(
        icono: Icons.list_alt_outlined,
        titulo: 'Mis incidencias',
        subtitulo: 'Consulta el estado de tus reportes',
        ruta: Rutas.misIncidencias,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _cargar,
          ),
          if (widget.onCerrarSesion != null)
            IconButton(
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.logout),
              onPressed: widget.onCerrarSesion,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refrescar,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Saludo(usuario: widget.usuario),
            const SizedBox(height: 24),
            Text('Resumen de incidencias', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            FutureBuilder<Map<String, int>>(
              future: _resumen,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SizedBox(
                    height: 140,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return _ErrorResumen(
                    mensaje: snap.error.toString(),
                    onReintentar: _cargar,
                  );
                }
                return _Resumen(conteo: snap.data ?? const {});
              },
            ),
            const SizedBox(height: 24),
            Text('Accesos', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final acceso in _accesos)
              Card(
                child: ListTile(
                  leading: Icon(acceso.icono,
                      color: theme.colorScheme.primary, size: 32),
                  title: Text(acceso.titulo),
                  subtitle: Text(acceso.subtitulo),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _ir(acceso.ruta),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets auxiliares
// ---------------------------------------------------------------------------

class _Acceso {
  const _Acceso({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.ruta,
  });
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final String ruta;
}

class _Saludo extends StatelessWidget {
  const _Saludo({required this.usuario});
  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          child: Text(
            usuario.nombre.isNotEmpty ? usuario.nombre[0].toUpperCase() : '?',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hola, ${usuario.nombre}',
                  style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Chip(
                label: Text(usuario.rol.etiqueta),
                avatar: Icon(
                  usuario.esOperador ? Icons.support_agent : Icons.person,
                  size: 18,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.conteo});
  final Map<String, int> conteo;

  @override
  Widget build(BuildContext context) {
    if (conteo.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No hay incidencias registradas')),
        ),
      );
    }

    final total = conteo.values.fold<int>(0, (a, b) => a + b);
    final estados = conteo.keys.toList()
      ..sort((a, b) {
        final c = _InfoEstado.de(a).orden.compareTo(_InfoEstado.de(b).orden);
        return c != 0 ? c : a.compareTo(b);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Total: $total', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.8,
          children: [
            for (final e in estados)
              _TarjetaEstado(info: _InfoEstado.de(e), cantidad: conteo[e]!),
          ],
        ),
      ],
    );
  }
}

class _TarjetaEstado extends StatelessWidget {
  const _TarjetaEstado({required this.info, required this.cantidad});
  final _InfoEstado info;
  final int cantidad;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: info.fondo,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: info.acento),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: info.acento,
                  child: Icon(info.icono, size: 16, color: info.sobreAcento),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(info.etiqueta,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge),
                ),
              ],
            ),
            Text('$cantidad',
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _ErrorResumen extends StatelessWidget {
  const _ErrorResumen({required this.mensaje, required this.onReintentar});
  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.cloud_off, color: color, size: 32),
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

/// Etiqueta, icono y colores de cada estado. Ajusta los nombres a los
/// valores exactos que devuelve tu API.
class _InfoEstado {
  const _InfoEstado({
    required this.etiqueta,
    required this.icono,
    required this.fondo,
    required this.acento,
    required this.sobreAcento,
    required this.orden,
  });

  final String etiqueta;
  final IconData icono;
  final Color fondo;
  final Color acento;
  final Color sobreAcento;
  final int orden;

  static _InfoEstado de(String estado) {
    switch (estado.toLowerCase().replaceAll(' ', '_')) {
      case 'abierta':
      case 'abierto':
      case 'nueva':
      case 'pendiente':
        return const _InfoEstado(
          etiqueta: 'Abiertas',
          icono: Icons.error_outline,
          fondo: AppColors.amarilloClaro,
          acento: AppColors.amarillo,
          sobreAcento: AppColors.texto,
          orden: 0,
        );
      case 'en_proceso':
      case 'en_progreso':
      case 'asignada':
        return const _InfoEstado(
          etiqueta: 'En proceso',
          icono: Icons.autorenew,
          fondo: AppColors.lilaClaro,
          acento: AppColors.morado,
          sobreAcento: AppColors.blanco,
          orden: 1,
        );
      case 'resuelta':
        return const _InfoEstado(
          etiqueta: 'Resueltas',
          icono: Icons.check,
          fondo: AppColors.blanco,
          acento: AppColors.morado,
          sobreAcento: AppColors.blanco,
          orden: 2,
        );
      case 'cerrada':
        return const _InfoEstado(
          etiqueta: 'Cerradas',
          icono: Icons.lock_outline,
          fondo: AppColors.blanco,
          acento: AppColors.amarillo,
          sobreAcento: AppColors.texto,
          orden: 3,
        );
      default:
        final texto = estado.replaceAll('_', ' ');
        return _InfoEstado(
          etiqueta: texto.isEmpty
              ? 'Sin estado'
              : texto[0].toUpperCase() + texto.substring(1),
          icono: Icons.label_outline,
          fondo: AppColors.blanco,
          acento: AppColors.lilaClaro,
          sobreAcento: AppColors.texto,
          orden: 99,
        );
    }
  }
}