import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/ui_helpers.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Border? border;
  final double borderRadius;
  final List<BoxShadow>? shadows;
  final Gradient? gradient;

  const CustomCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.border,
    this.borderRadius = 18.0,
    this.shadows,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = backgroundColor ?? (isDark ? Theme.of(context).colorScheme.surface : Colors.white);
    final cardShadows = shadows ?? UIHelpers.cardShadow(context);
    final radius = BorderRadius.circular(borderRadius);

    Widget cardContent = Container(
      margin: margin,
      padding: padding ?? UIHelpers.paddingAll16,
      decoration: BoxDecoration(
        color: gradient == null ? cardBg : null,
        gradient: gradient,
        borderRadius: radius,
        border: border ??
            Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
              width: 1,
            ),
        boxShadow: cardShadows,
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: cardContent,
        ),
      ).animate().fadeIn(duration: 250.ms).scale(begin: const Offset(0.98, 0.98), end: const Offset(1, 1));
    }

    return cardContent;
  }
}
