import 'package:flutter/material.dart';

import '../models/estado_incidencia.dart';
import '../theme/app_theme.dart';

// Colores e icono de un estado, ya ajustados al tema claro u oscuro
typedef EstiloEstado = ({
  IconData icono,
  Color fondo,
  Color borde,
  Color texto,
});

EstiloEstado estiloEstado(BuildContext context, EstadoIncidencia estado) {
  final theme = Theme.of(context);
  final oscuro = theme.brightness == Brightness.dark;
  final (icono, fondo, acento) = EstadoChip._estilo(estado);

  return (
    icono: icono,
    // En modo oscuro se usa un tinte del color de acento sobre la superficie.
    fondo: oscuro
        ? Color.alphaBlend(
            acento.withValues(alpha: 0.25),
            AppColors.superficieOscura,
          )
        : fondo,
    borde: acento,
    texto: oscuro ? theme.colorScheme.onSurface : AppColors.texto,
  );
}

class EstadoChip extends StatelessWidget {
  const EstadoChip({super.key, required this.estado});

  final EstadoIncidencia estado;

  @override
  Widget build(BuildContext context) {
    final e = estiloEstado(context, estado);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: e.fondo,
        border: Border.all(color: e.borde),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(e.icono, size: 14, color: e.texto),
          const SizedBox(width: 4),
          Text(
            estado.etiqueta,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: e.texto),
          ),
        ],
      ),
    );
  }

  static (IconData, Color, Color) _estilo(EstadoIncidencia estado) =>
      switch (estado) {
        EstadoIncidencia.pendiente => (
          Icons.schedule,
          AppColors.amarilloClaro,
          AppColors.amarillo,
        ),
        EstadoIncidencia.asignada => (
          Icons.assignment_ind_outlined,
          AppColors.lilaClaro,
          AppColors.morado,
        ),
        EstadoIncidencia.enProceso => (
          Icons.build_outlined,
          AppColors.blanco,
          AppColors.amarillo,
        ),
        EstadoIncidencia.finalizada => (
          Icons.check,
          AppColors.blanco,
          AppColors.morado,
        ),
        EstadoIncidencia.cancelada => (
          Icons.block,
          AppColors.blanco,
          AppColors.lilaClaro,
        ),
      };
}
