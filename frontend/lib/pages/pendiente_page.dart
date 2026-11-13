import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pantalla provisional para las rutas cuyas funcionalidades aún no se
/// implementan. Sustitúyela por la pantalla real en `main.dart`.
class PendientePage extends StatelessWidget {
  const PendientePage({super.key, required this.titulo});
  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        actions: const [BotonTema()],
      ),
      body: const Center(child: Text('Pantalla en construcción')),
    );
  }
}