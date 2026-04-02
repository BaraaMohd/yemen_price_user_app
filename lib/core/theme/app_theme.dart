import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF0D5D8C);
  static const Color secondaryColor = Color(0xFF2E7D6B);
  static const Color tertiaryColor = Color(0xFFCE8A2E);

  static const Color _lightScaffold = Color(0xFFF2F6FA);
  static const Color _darkScaffold = Color(0xFF0A0E13); // Deeper black for higher contrast
  static const Color _lightCard = Colors.white;
  static const Color _darkCard = Color(0xFF121A22); // Slightly darker card for better text pop

  static TextTheme _buildTextTheme(TextTheme base) {
    return GoogleFonts.cairoTextTheme(base);
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final scheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      secondary: secondaryColor,
      tertiary: tertiaryColor,
      brightness: brightness,
    );
    final isDark = brightness == Brightness.dark;

    return base.copyWith(
      colorScheme: scheme.copyWith(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: tertiaryColor,
      ),
      primaryColor: primaryColor,
      scaffoldBackgroundColor: isDark ? _darkScaffold : _lightScaffold,
      cardColor: isDark ? _darkCard : _lightCard,
      textTheme: _buildTextTheme(base.textTheme),
      dividerColor: isDark ? const Color(0xFF2A3642) : const Color(0xFFD6DEE7),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : scheme.onSurface),
        titleTextStyle: GoogleFonts.cairo(
          color: isDark ? Colors.white : scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      iconTheme: IconThemeData(color: isDark ? Colors.white : scheme.onSurface.withValues(alpha: 0.85)),
      cardTheme: CardThemeData(
        color: isDark ? _darkCard : _lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
          ),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 20),
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.secondary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.45)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1B252F) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.cairo(
          color: isDark ? Colors.white70 : scheme.onSurface.withValues(alpha: 0.55),
          fontSize: 13,
        ),
        labelStyle: GoogleFonts.cairo(
          color: isDark ? Colors.white : scheme.onSurface.withValues(alpha: 0.8),
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? const Color(0xFF1B2733) : Colors.white,
        selectedColor: scheme.primary.withValues(alpha: 0.14),
        disabledColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
        labelStyle: GoogleFonts.cairo(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF1E2935) : const Color(0xFF163247),
        contentTextStyle: GoogleFonts.cairo(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? const Color(0xFF15212B) : Colors.white,
        modalBackgroundColor: isDark ? const Color(0xFF15212B) : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
 dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF182430) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: GoogleFonts.cairo(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
        contentTextStyle: GoogleFonts.cairo(color: scheme.onSurface, fontSize: 14),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurface.withValues(alpha: 0.65),
        indicatorColor: scheme.primary,
        labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.w800),
        unselectedLabelStyle: GoogleFonts.cairo(fontWeight: FontWeight.w600),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return isDark ? const Color(0xFFCFD8E3) : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.secondary;
          }
          return scheme.outline.withValues(alpha: 0.35);
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
      ),
    );
  }

  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);
}
