import 'package:flutter/material.dart';

/// Paleta de la aplicación
/// (coolors.co/fefced-faf2b5-f0d200-e2b2ff-a767ff).
class AppColors {
  static const crema = Color(0xFFFEFCED);
  static const amarilloClaro = Color(0xFFFAF2B5);
  static const amarillo = Color(0xFFF0D200);
  static const lilaClaro = Color(0xFFE2B2FF);
  static const morado = Color(0xFFA767FF);

  /// Texto oscuro, como el de la referencia.
  static const texto = Color(0xFF2D2A3A);
  static const blanco = Colors.white;

  // Modo oscuro (derivados de la paleta, con tinte morado)
  static const fondoOscuro = Color(0xFF1C1A24);
  static const superficieOscura = Color(0xFF262333);
  static const bordeOscuro = Color(0xFF3D3752);
}

/// Modo de tema actual. Empieza siguiendo al sistema operativo/navegador.
final ValueNotifier<ThemeMode> modoTema = ValueNotifier(ThemeMode.system);

/// Botón para alternar entre modo claro y oscuro.
class BotonTema extends StatelessWidget {
  const BotonTema({super.key});

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: oscuro ? 'Modo claro' : 'Modo oscuro',
      icon: Icon(oscuro ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: () =>
          modoTema.value = oscuro ? ThemeMode.light : ThemeMode.dark,
    );
  }
}

class AppTheme {
  static ThemeData get claro {
    const esquema = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.morado,
      onPrimary: AppColors.blanco,
      primaryContainer: AppColors.lilaClaro,
      onPrimaryContainer: AppColors.texto,
      secondary: AppColors.amarillo,
      onSecondary: AppColors.texto,
      secondaryContainer: AppColors.amarilloClaro,
      onSecondaryContainer: AppColors.texto,
      tertiary: AppColors.lilaClaro,
      onTertiary: AppColors.texto,
      error: Color(0xFFB3261E),
      onError: AppColors.blanco,
      surface: AppColors.crema,
      onSurface: AppColors.texto,
    );

    return ThemeData(
      colorScheme: esquema,
      scaffoldBackgroundColor: AppColors.crema,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.amarillo,
        foregroundColor: AppColors.texto,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.blanco,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.lilaClaro),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.lilaClaro,
        labelStyle: TextStyle(color: AppColors.texto),
        side: BorderSide.none,
      ),
      listTileTheme: const ListTileThemeData(iconColor: AppColors.morado),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.morado),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.morado,
        foregroundColor: AppColors.blanco,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.morado,
          foregroundColor: AppColors.blanco,
        ),
      ),
    );
  }

  static ThemeData get oscuro {
    const esquema = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.lilaClaro,
      onPrimary: AppColors.texto,
      primaryContainer: AppColors.morado,
      onPrimaryContainer: AppColors.blanco,
      secondary: AppColors.amarillo,
      onSecondary: AppColors.texto,
      secondaryContainer: Color(0xFF4A4100),
      onSecondaryContainer: AppColors.amarilloClaro,
      tertiary: AppColors.morado,
      onTertiary: AppColors.blanco,
      error: Color(0xFFF2B8B5),
      onError: Color(0xFF601410),
      surface: AppColors.fondoOscuro,
      onSurface: AppColors.crema,
    );

    return ThemeData(
      colorScheme: esquema,
      scaffoldBackgroundColor: AppColors.fondoOscuro,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.superficieOscura,
        foregroundColor: AppColors.amarillo,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: AppColors.amarillo, width: 2)),
      ),
      cardTheme: CardThemeData(
        color: AppColors.superficieOscura,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.bordeOscuro),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.morado,
        labelStyle: TextStyle(color: AppColors.blanco),
        iconTheme: IconThemeData(color: AppColors.blanco),
        side: BorderSide.none,
      ),
      listTileTheme: const ListTileThemeData(iconColor: AppColors.lilaClaro),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.lilaClaro),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.morado,
        foregroundColor: AppColors.blanco,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.morado,
          foregroundColor: AppColors.blanco,
        ),
      ),
    );
  }
}