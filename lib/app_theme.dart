import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primaryDark = Color(0xFF306D29);
  static const Color primaryLight = Color(0xFFA8DF8E);
  static const Color accentPink = Color(0xFFF891BB);
  static const Color warmCard = Color(0xFFFFE8CD);
  static const Color bgTint = Color(0xFFCAE8BD);
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textMid = Color(0xFF6B6B6B);
  static const Color textLight = Color(0xFFAAAAAA);
  static const Color white = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF7FAF5);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFFF8C00);
  static const Color error = Color(0xFFD32F2F);
  static const Color info = Color(0xFF1976D2);
  static const Color statusPending = Color(0xFFFF8C00);
  static const Color statusPacked = Color(0xFF1976D2);
  static const Color statusOutForDelivery = Color(0xFF7B1FA2);
  static const Color statusDelivered = Color(0xFF2E7D32);
  static const Color statusCancelled = Color(0xFFD32F2F);
}

class AppTextStyles {
  static TextStyle display({Color color = AppColors.textDark}) =>
      GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: color,
      );
  static TextStyle heading1({Color color = AppColors.textDark}) =>
      GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: color,
      );
  static TextStyle heading2({Color color = AppColors.textDark}) =>
      GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: color,
      );
  static TextStyle title({Color color = AppColors.textDark}) =>
      GoogleFonts.poppins(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: color,
      );
  static TextStyle body({Color color = AppColors.textDark}) =>
      GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: color,
      );
  static TextStyle bodyMedium({Color color = AppColors.textDark}) =>
      GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: color,
      );
  static TextStyle bodySemiBold({Color color = AppColors.textDark}) =>
      GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: color,
      );
  static TextStyle caption({Color color = AppColors.textMid}) =>
      GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color,
      );
  static TextStyle captionMedium({Color color = AppColors.textMid}) =>
      GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color,
      );
  static TextStyle price({Color color = AppColors.primaryDark}) =>
      GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: color,
      );
  static TextStyle button({Color color = AppColors.white}) =>
      GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.5,
      );
}

class AppDecorations {
  static BoxDecoration card({Color? color, double radius = 16}) =>
      BoxDecoration(
        color: color ?? AppColors.cardBg,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );
  static BoxDecoration elevatedCard({Color? color, double radius = 20}) =>
      BoxDecoration(
        color: color ?? AppColors.cardBg,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      );
  static BoxDecoration primaryGradient({double radius = 20}) => BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    gradient: const LinearGradient(
      colors: [AppColors.primaryDark, Color(0xFF4CAF50)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    boxShadow: [
      BoxShadow(
        color: AppColors.primaryDark.withValues(alpha: 0.3),
        blurRadius: 15,
        offset: const Offset(0, 6),
      ),
    ],
  );
  static BoxDecoration warmCard({double radius = 16}) => BoxDecoration(
    color: AppColors.warmCard,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: AppColors.warning.withValues(alpha: 0.12),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );
  static BoxDecoration inputField() => BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: AppColors.bgTint, width: 1.5),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
  static BoxDecoration pill({Color? color, Color? borderColor}) =>
      BoxDecoration(
        color: color ?? AppColors.bgTint,
        borderRadius: BorderRadius.circular(100),
        border: borderColor != null ? Border.all(color: borderColor) : null,
      );
}

class AppButtonStyles {
  static ButtonStyle primary({double radius = 100}) => ElevatedButton.styleFrom(
    backgroundColor: AppColors.primaryDark,
    foregroundColor: AppColors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
  );
  static ButtonStyle secondary({double radius = 100}) =>
      ElevatedButton.styleFrom(
        backgroundColor: AppColors.bgTint,
        foregroundColor: AppColors.primaryDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      );
  static ButtonStyle danger({double radius = 100}) => ElevatedButton.styleFrom(
    backgroundColor: AppColors.error,
    foregroundColor: AppColors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
  );
  static ButtonStyle orange({double radius = 100}) => ElevatedButton.styleFrom(
    backgroundColor: AppColors.warning,
    foregroundColor: AppColors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
  );
}

class AppTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryDark,
      primary: AppColors.primaryDark,
      secondary: AppColors.warning,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.surface,
    textTheme: GoogleFonts.poppinsTextTheme(),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primaryDark,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: AppTextStyles.heading2(color: AppColors.white),
      iconTheme: const IconThemeData(color: AppColors.white),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: AppButtonStyles.primary(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.bgTint),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.bgTint, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primaryDark, width: 2),
      ),
      filled: true,
      fillColor: AppColors.white,
      hintStyle: AppTextStyles.body(color: AppColors.textLight),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.textDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primaryLight,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
    ),
  );
}
