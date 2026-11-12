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
}