// lib/utils.dart
import 'package:flutter/material.dart';

// 🎨 BRAND COLORS
class DhemiColors {
  // Primary Brand
  static const Color royalPurple = Color(0xFF5E006C); // Main Brand Color
  static const Color softPurple = Color(0xFFB07ABC);   // Accent for taglines

  // Neutrals (for text, borders, backgrounds)
  static const Color white = Colors.white;
  static const Color black = Colors.black;

  // Grayscale (commonly used in UI)
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF1F2937);
  static const Color gray900 = Color(0xFF111827);
}

// ✒️ TYPOGRAPHY STYLES — Assumes fonts are added in pubspec.yaml:
//   - Cinzel (Bold, SemiBold)
//   - Montserrat (Light, Regular)
class DhemiText {
  // 🖋️ Primary: Cinzel (Serif) — Titles, Logo
  static TextStyle logo = const TextStyle(
    fontFamily: 'Cinzel',
    fontWeight: FontWeight.bold,
    fontSize: 32,
    color: DhemiColors.royalPurple,
  );

  static TextStyle header = const TextStyle(
    fontFamily: 'Cinzel',
    fontWeight: FontWeight.bold,
    fontSize: 26,
    color: DhemiColors.royalPurple,
  );

  static TextStyle headlineMedium = const TextStyle(
    fontFamily: 'Cinzel',
    fontWeight: FontWeight.bold,
    fontSize: 24,
    color: DhemiColors.royalPurple,
  );

  static TextStyle headlineSmall = const TextStyle(
    fontFamily: 'Cinzel',
    fontWeight: FontWeight.bold,
    fontSize: 20,
    color: DhemiColors.royalPurple,
  );

  // 📝 Secondary: Montserrat (Sans-Serif) — Body, Buttons, Labels
  static TextStyle bodyLarge = const TextStyle(
    fontFamily: 'Montserrat',
    fontWeight: FontWeight.w600,
    fontSize: 16,
    color: DhemiColors.royalPurple,
  );

  static TextStyle bodyMedium = const TextStyle(
    fontFamily: 'Montserrat',
    fontWeight: FontWeight.w500,
    fontSize: 16,
    color: DhemiColors.royalPurple,
  );

  static TextStyle body = const TextStyle(
    fontFamily: 'Montserrat',
    fontWeight: FontWeight.w400,
    fontSize: 16,
    color: DhemiColors.royalPurple,
  );

  static TextStyle bodySmall = const TextStyle(
    fontFamily: 'Montserrat',
    fontWeight: FontWeight.w400,
    fontSize: 14,
    color: DhemiColors.royalPurple,
  );

  static TextStyle subtitle = const TextStyle(
    fontFamily: 'Montserrat',
    fontWeight: FontWeight.w400,
    fontSize: 18,
    color: DhemiColors.royalPurple,
  );

  static TextStyle tagline = const TextStyle(
    fontFamily: 'Montserrat',
    fontWeight: FontWeight.w300,
    fontStyle: FontStyle.italic,
    fontSize: 16,
    color: DhemiColors.softPurple,
  );
}

// 📐 Spacing Extensions (e.g., 16.h or 8.w)
extension Spacing on num {

  SizedBox get h => SizedBox(height: toDouble());
  SizedBox get w => SizedBox(width: toDouble());
}

// 🧱 Reusable Widget Builders
class DhemiWidgets {
  /// Dhemi Logo: "THE DHEMHI BRAND"
  static Widget logo({double fontSize = 28}) {
    return Text(
      'THE DHEMHI BRAND',
      style: DhemiText.logo.copyWith(fontSize: fontSize),
      textAlign: TextAlign.center,
    );
  }

  /// Header with optional subtitle & tagline
  static Widget header({
    required String title,
    String? subtitle,
    String? tagline,
  }) {
    final children = <Widget>[
      Text(title, style: DhemiText.header),
    ];

    if (subtitle != null) {
      children.add(4.h);
      children.add(Text(subtitle, style: DhemiText.subtitle));
    }

    if (tagline != null) {
      children.add(6.h);
      children.add(Text(tagline, style: DhemiText.tagline));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  /// Solid Brand Button
  static Widget button({
    required String label,
    required VoidCallback onPressed,
    double fontSize = 16,
    double horizontalPadding = 24,
    double verticalPadding = 14,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: DhemiColors.royalPurple,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
      ),
      child: Text(
        label,
        style: DhemiText.bodyLarge.copyWith(
          fontSize: fontSize,
          color: DhemiColors.white,
        ),
      ),
    );
  }

  /// Outlined Brand Button
  static Widget outlinedButton({
    required String label,
    required VoidCallback onPressed,
    double fontSize = 16,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: DhemiColors.royalPurple, width: 2),
        foregroundColor: DhemiColors.royalPurple,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        label,
        style: DhemiText.bodyMedium.copyWith(fontSize: fontSize),
      ),
    );
  }
}