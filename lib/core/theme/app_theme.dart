import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/entities/app_settings.dart';

/// Neon accent colors shared by every theme.
class Neon {
  static const cyan = Color(0xFF00E5FF);
  static const purple = Color(0xFFB026FF);
  static const green = Color(0xFF00FF9D);
  static const lime = Color(0xFF7CFF4F);
  static const amber = Color(0xFFFFC23D);
  static const red = Color(0xFFFF3D57);
  static const orange = Color(0xFFFF7A2F);

  static const idle = LinearGradient(colors: [cyan, purple]);
  static const charging = LinearGradient(colors: [green, cyan]);
  static const hot = LinearGradient(colors: [orange, red]);

  static LinearGradient forState({required bool charging, required bool hot}) =>
      hot ? Neon.hot : (charging ? Neon.charging : Neon.idle);

  static Color accent({required bool charging, required bool hot}) => hot ? red : (charging ? green : cyan);
}

/// Surface colors that change between dark / light / AMOLED.
@immutable
class VoltPalette extends ThemeExtension<VoltPalette> {
  final List<Color> background;
  final Color glass;
  final Color glassBorder;
  final Color textMuted;

  const VoltPalette({required this.background, required this.glass, required this.glassBorder, required this.textMuted});

  static VoltPalette of(BuildContext context) => Theme.of(context).extension<VoltPalette>()!;

  @override
  VoltPalette copyWith({List<Color>? background, Color? glass, Color? glassBorder, Color? textMuted}) => VoltPalette(
        background: background ?? this.background,
        glass: glass ?? this.glass,
        glassBorder: glassBorder ?? this.glassBorder,
        textMuted: textMuted ?? this.textMuted,
      );

  @override
  VoltPalette lerp(VoltPalette? other, double t) {
    if (other == null) return this;
    return VoltPalette(
      background: List.generate(background.length, (i) => Color.lerp(background[i], other.background[i], t)!),
      glass: Color.lerp(glass, other.glass, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
    );
  }
}

class AppTheme {
  static TextStyle digits({double size = 16, FontWeight weight = FontWeight.w700, Color? color}) =>
      GoogleFonts.orbitron(fontSize: size, fontWeight: weight, color: color, letterSpacing: 0.5);

  static ThemeData build(AppThemeMode mode) {
    final dark = mode != AppThemeMode.light;
    final palette = switch (mode) {
      AppThemeMode.dark => const VoltPalette(
          background: [Color(0xFF070B18), Color(0xFF0E1230), Color(0xFF1A0B2E)],
          glass: Color(0x14FFFFFF),
          glassBorder: Color(0x33FFFFFF),
          textMuted: Color(0xB3FFFFFF),
        ),
      AppThemeMode.amoled => const VoltPalette(
          background: [Colors.black, Colors.black, Color(0xFF05000A)],
          glass: Color(0x0FFFFFFF),
          glassBorder: Color(0x26FFFFFF),
          textMuted: Color(0x99FFFFFF),
        ),
      AppThemeMode.light => const VoltPalette(
          background: [Color(0xFFF2F6FF), Color(0xFFE9EEFF), Color(0xFFF5ECFF)],
          glass: Color(0x99FFFFFF),
          glassBorder: Color(0x33000000),
          textMuted: Color(0x99000000),
        ),
    };
    final scheme = ColorScheme.fromSeed(
      seedColor: Neon.cyan,
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: dark ? Neon.cyan : const Color(0xFF0091A8),
      secondary: Neon.purple,
      error: Neon.red,
      surface: palette.background.first,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: scheme.brightness);
    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      extensions: [palette],
      appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.glass,
        indicatorColor: Neon.cyan.withValues(alpha: 0.18),
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      }),
    );
  }
}
