import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

abstract final class Nextrole {
  static const paper = Color(0xFFFAF9F6);
  static const ink = Color(0xFF17243B);
  static const blue = Color(0xFF3563E9);
  static const muted = Color(0xFF596477);
  static const lavender = Color(0xFFEEEAF8);
  static const apricot = Color(0xFFF9D8C0);
  static const line = Color(0xFFD8DCE4);
  static const error = Color(0xFFA52A36);

  static ThemeData get theme {
    final base = ThemeData(useMaterial3: true, fontFamily: 'Inter');
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: line),
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );
    return base.copyWith(
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(seedColor: blue).copyWith(
        primary: blue,
        onPrimary: Colors.white,
        surface: paper,
        onSurface: ink,
        error: error,
        outline: line,
      ),
      textTheme: base.textTheme
          .apply(bodyColor: ink, displayColor: ink)
          .copyWith(
            bodyMedium: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              height: 1.45,
              color: ink,
            ),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: blue,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: buttonShape,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          side: const BorderSide(color: line),
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: blue, width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: paper,
        indicatorColor: lavender,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}

class DesignIcon extends StatelessWidget {
  final String name;
  final Color? color;
  const DesignIcon(this.name, {super.key, this.color});
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/figma/$name.svg',
    width: name == 'event-marker' ? 10 : 20,
    height: name == 'event-marker' ? 10 : 20,
    excludeFromSemantics: true,
    colorFilter: color == null
        ? null
        : ColorFilter.mode(color!, BlendMode.srcIn),
  );
}

class Notice extends StatelessWidget {
  final String text;
  final bool error;
  const Notice(this.text, {super.key, this.error = false});
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: error ? const Color(0xFFFFECEE) : Nextrole.lavender,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DesignIcon('info'),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: error ? Nextrole.error : Nextrole.ink,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class EditorialTitle extends StatelessWidget {
  final String text;
  final double size;
  const EditorialTitle(this.text, {super.key, this.size = 40});
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      style: TextStyle(
        fontFamily: 'DM Serif Display',
        fontSize: size,
        height: 1.15,
        color: Nextrole.ink,
      ),
    ),
  );
}

class ScreenTitle extends StatelessWidget {
  final String text;
  final double size;
  const ScreenTitle(this.text, {super.key, this.size = 40});
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        height: 1.45,
        color: Nextrole.ink,
      ),
    ),
  );
}
