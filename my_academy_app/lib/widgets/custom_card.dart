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
  final bool enableAnimation;

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
    this.enableAnimation = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = backgroundColor ?? (isDark ? Theme.of(context).colorScheme.surface : Colors.white);
    final cardShadows = shadows ?? UIHelpers.cardShadow(context);
    final radius = BorderRadius.circular(borderRadius);

    final borderSide = border?.top ??
        BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
          width: 1,
        );

    Widget cardContent = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: cardShadows,
      ),
      child: Material(
        color: gradient == null ? cardBg : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: borderSide,
        ),
        clipBehavior: Clip.antiAlias,
        child: Container(
          padding: padding ?? UIHelpers.paddingAll16,
          decoration: gradient != null ? BoxDecoration(gradient: gradient) : null,
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      final inkCard = Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: cardContent,
        ),
      );

      if (enableAnimation) {
        return inkCard.animate().fadeIn(duration: 250.ms).scale(begin: const Offset(0.98, 0.98), end: const Offset(1, 1));
      }
      return inkCard;
    }

    return cardContent;
  }
}
