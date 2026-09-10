import 'package:flutter/material.dart';
import 'app_theme.dart';

class UIHelpers {
  // Padding & Spacing
  static const double p4 = 4.0;
  static const double p8 = 8.0;
  static const double p12 = 12.0;
  static const double p16 = 16.0;
  static const double p20 = 20.0;
  static const double p24 = 24.0;
  static const double p32 = 32.0;

  static const EdgeInsets paddingAll16 = EdgeInsets.all(p16);
  static const EdgeInsets paddingAll20 = EdgeInsets.all(p20);
  static const EdgeInsets paddingScreen = EdgeInsets.symmetric(horizontal: p16, vertical: p12);

  // Border Radius
  static final BorderRadius r8 = BorderRadius.circular(8);
  static final BorderRadius r12 = BorderRadius.circular(12);
  static final BorderRadius r16 = BorderRadius.circular(16);
  static final BorderRadius r20 = BorderRadius.circular(20);
  static final BorderRadius r24 = BorderRadius.circular(24);

  // Soft Premium Shadows
  static List<BoxShadow> cardShadow(BuildContext context) {
    return AppTheme.cardShadow(context);
  }

  // Premium Header Decoration
  static BoxDecoration headerGradientDecoration(BuildContext context) {
    return BoxDecoration(
      gradient: AppTheme.headerGradient(context),
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
    );
  }

  // Glassmorphic / Subtle Overlay Container
  static BoxDecoration glassDecoration(BuildContext context) {
    final tokens = AppTheme.tokens(context);
    return BoxDecoration(
      color: tokens.isGlass
          ? tokens.card
          : (tokens.isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.85)),
      borderRadius: r16,
      border: Border.all(
        color: tokens.border,
        width: 1.2,
      ),
      boxShadow: tokens.cardShadow,
    );
  }

  // Custom Toast/Snackbar Helper
  static void showCustomSnackBar(BuildContext context, String message, {bool isError = false, IconData? icon}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? AppTheme.warningRed : AppTheme.primaryDarkBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: r12),
        content: Row(
          children: [
            Icon(
              icon ?? (isError ? Icons.error_outline : Icons.check_circle_outline),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
