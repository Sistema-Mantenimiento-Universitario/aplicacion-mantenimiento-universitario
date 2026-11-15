import 'package:flutter/material.dart';

import '../models/usuario.dart';
import '../theme/app_theme.dart';

/// F6 · Pantalla de perfil y configuración.
class PerfilPage extends StatelessWidget {
  const PerfilPage({
    super.key,
    required this.usuario,
    required this.onCerrarSesion,
  });

  final Usuario usuario;

  /// Borra la sesión local; `main.dart` muestra entonces el login.
  final VoidCallback onCerrarSesion;

  Future<void> _confirmarCerrarSesion(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Tendrás que volver a iniciar sesión para usar la aplicación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;

    // Cierra las pantallas abiertas para que quede visible el login.
    Navigator.of(context).popUntil((ruta) => ruta.isFirst);
    onCerrarSesion();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorError = theme.colorScheme.error;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Encabezado
                  Center(
                    child: CircleAvatar(
                      radius: 40,
                      child: Text(
                        usuario.nombre.isNotEmpty
                            ? usuario.nombre[0].toUpperCase()
                            : '?',
                        style: theme.textTheme.headlineMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    usuario.nombre,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),

                  // Datos del usuario
                  Text(
                    'Datos de la cuenta',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: const Text('Nombre'),
                          subtitle: Text(usuario.nombre),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.email_outlined),
                          title: const Text('Correo'),
                          subtitle: Text(usuario.correo),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(
                            usuario.esOperador
                                ? Icons.support_agent
                                : Icons.badge_outlined,
                          ),
                          title: const Text('Rol'),
                          subtitle: Text(usuario.rol.etiqueta),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Preferencias
                  Text('Preferencias', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tema', style: theme.textTheme.titleSmall),
                          const SizedBox(height: 8),
                          ValueListenableBuilder<ThemeMode>(
                            valueListenable: modoTema,
                            builder: (context, modo, _) =>
                                SegmentedButton<ThemeMode>(
                                  showSelectedIcon: false,
                                  segments: const [
                                    ButtonSegment(
                                      value: ThemeMode.system,
                                      icon: Icon(
                                        Icons.brightness_auto_outlined,
                                      ),
                                      label: Text('Sistema'),
                                    ),
                                    ButtonSegment(
                                      value: ThemeMode.light,
                                      icon: Icon(Icons.light_mode_outlined),
                                      label: Text('Claro'),
                                    ),
                                    ButtonSegment(
                                      value: ThemeMode.dark,
                                      icon: Icon(Icons.dark_mode_outlined),
                                      label: Text('Oscuro'),
                                    ),
                                  ],
                                  selected: {modo},
                                  onSelectionChanged: (seleccion) =>
                                      modoTema.value = seleccion.first,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Se guarda en este dispositivo.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Cerrar sesión
                  OutlinedButton.icon(
                    onPressed: () => _confirmarCerrarSesion(context),
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar sesión'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorError,
                      side: BorderSide(color: colorError),
                      minimumSize: const Size.fromHeight(48),
                    ),
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
