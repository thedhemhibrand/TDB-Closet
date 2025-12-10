// lib/utils.dart
import 'package:flutter/material.dart';

// 🎨 BRAND COLORS
class DhemiColors {
  static const Color royalPurple = Color(0xFF5E006C);
  static const Color softPurple = Color(0xFFB07ABC);
  static const Color white = Colors.white;
  static const Color black = Colors.black;

  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF374151);
  static const Color gray900 = Color(0xFF111827);
}

// ✒️ TYPOGRAPHY
class DhemiText {
  // Cinzel
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

  // Montserrat
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

// 📐 Spacing Extensions
extension Spacing on num {
  SizedBox get h => SizedBox(height: toDouble());
  SizedBox get w => SizedBox(width: toDouble());
}

// 🧰 UTILITY FUNCTIONS — NEW & ENHANCED
class DhemiUtils {
  /// Safely convert any value to int (handles null, string, double, int)
  static int safeInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return fallback;
      // Handle "₦1,500" → 1500
      final cleaned = trimmed.replaceAll(RegExp(r'[^\d-]'), '');
      return int.tryParse(cleaned) ?? fallback;
    }
    return fallback;
  }

  /// Format currency: ₦1,250 | ₦12,500.00 → uses grouping, no decimals for whole numbers
  static String formatCurrency(int amount) {
    if (amount < 0) {
      return '-₦${(-amount).toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
    }
    return '₦${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  /// Format date for UI (used in ProfilePage order history)
  static String formatDate(DateTime? date) {
    if (date == null) return '—';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today, ${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');

  /// Safely truncate string with ellipsis
  static String truncate(String text, {int length = 30}) {
    if (text.length <= length) return text;
    return '${text.substring(0, length - 3)}...';
  }
}

// 🧱 REUSABLE WIDGETS
class DhemiWidgets {
  static Widget logo({double fontSize = 28}) {
    return Text(
      'THE DHEMHI BRAND',
      style: DhemiText.logo.copyWith(fontSize: fontSize),
      textAlign: TextAlign.center,
    );
  }

  static Widget header({
    required String title,
    String? subtitle,
    String? tagline,
  }) {
    final children = <Widget>[Text(title, style: DhemiText.header)];
    if (subtitle != null) {
      children
        ..add(4.h)
        ..add(Text(subtitle, style: DhemiText.subtitle));
    }
    if (tagline != null) {
      children
        ..add(6.h)
        ..add(Text(tagline, style: DhemiText.tagline));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  static Widget button({
    required String label,
    required VoidCallback onPressed,
    double fontSize = 16,
    double horizontalPadding = 24,
    double verticalPadding = 14,
    required int minHeight,
  }) {
    return SizedBox(
      height: minHeight.toDouble(),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedVectorButtonStyle(
          backgroundColor: DhemiColors.royalPurple,
          radius: 12,
        ),
        child: Text(
          label,
          style: DhemiText.bodyLarge.copyWith(
            fontSize: fontSize,
            color: DhemiColors.white,
          ),
        ),
      ),
    );
  }

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: DhemiText.bodyMedium.copyWith(fontSize: fontSize),
      ),
    );
  }

  // ✨ Modern quantity stepper
  static Widget quantityStepper({
    required int value,
    required int max,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
  }) {
    return Row(
      children: [
        _buildStepperButton(
          icon: Icons.remove,
          enabled: value > 1,
          onTap: onDecrement,
        ),
        12.w,
        Container(
          width: 56,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: DhemiColors.gray100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: DhemiColors.gray300),
          ),
          child: Text(
            '$value',
            style: DhemiText.bodyLarge.copyWith(fontSize: 18),
          ),
        ),
        12.w,
        _buildStepperButton(
          icon: Icons.add,
          enabled: value < max,
          onTap: onIncrement,
        ),
      ],
    );
  }

  static Widget _buildStepperButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled ? DhemiColors.gray200 : DhemiColors.gray50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: DhemiColors.gray300),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? DhemiColors.gray800 : DhemiColors.gray400,
        ),
      ),
    );
  }

  // ✨ Dot Indicator for carousels
  static Widget dotIndicator(int length, int currentIndex) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(length, (i) {
        return Container(
          width: i == currentIndex ? 20 : 8,
          height: 8,
          margin: EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: i == currentIndex
                ? DhemiColors.royalPurple
                : DhemiColors.gray300,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ✨ Helper for clean ElevatedButton styling
ButtonStyle ElevatedVectorButtonStyle({
  required Color backgroundColor,
  double radius = 12,
}) {
  return ElevatedButton.styleFrom(
    backgroundColor: backgroundColor,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    textStyle: const TextStyle(fontWeight: FontWeight.w600),
  );
}
