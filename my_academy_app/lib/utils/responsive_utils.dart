import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Centralized Responsive Utilities for Content-Aware & Constraint-Aware UI design.
class AppBreakpoints {
  // Reference breakpoints (logical pixels)
  static const double compactMax = 600.0;
  static const double mediumMax = 1024.0;

  // Typical minimum comfortable widths for UI components
  static const double minStatCardWidth = 180.0;
  static const double minFormFieldWidth = 240.0;
  static const double minActionButtonWidth = 140.0;
  static const double maxDialogWidth = 520.0;

  static bool isCompact(double width) => width < compactMax;
  static bool isMedium(double width) => width >= compactMax && width < mediumMax;
  static bool isExpanded(double width) => width >= mediumMax;
}

/// A Constraint-Aware Widget that dynamically chooses between a Row (horizontal)
/// and a Column (vertical) based on whether the container has enough `minRequiredWidth`.
class ConstraintAwareRowOrColumn extends StatelessWidget {
  final List<Widget> children;
  final double minRequiredWidth;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final double spacing;

  const ConstraintAwareRowOrColumn({
    super.key,
    required this.children,
    this.minRequiredWidth = 500.0,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.spacing = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fitsHorizontally = constraints.maxWidth >= minRequiredWidth;

        if (fitsHorizontally) {
          return Row(
            mainAxisAlignment: mainAxisAlignment,
            crossAxisAlignment: crossAxisAlignment,
            children: children,
          );
        }

        // Render vertically if space is tight
        return Column(
          mainAxisAlignment: mainAxisAlignment,
          crossAxisAlignment: crossAxisAlignment,
          children: children.expand((child) sync* {
            yield child;
            yield SizedBox(height: spacing);
          }).toList()..removeLast(),
        );
      },
    );
  }
}

/// An Adaptive Wrap widget that allows items to reflow naturally across lines
/// with specified horizontal and vertical spacing.
class AdaptiveWrap extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final WrapAlignment alignment;
  final WrapCrossAlignment crossAxisAlignment;

  const AdaptiveWrap({
    super.key,
    required this.children,
    this.spacing = 10.0,
    this.runSpacing = 10.0,
    this.alignment = WrapAlignment.start,
    this.crossAxisAlignment = WrapCrossAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      alignment: alignment,
      crossAxisAlignment: crossAxisAlignment,
      children: children,
    );
  }
}

/// A Constraint-Aware Grid layout builder that automatically calculates column count
/// based on available parent width and a minimum item width.
class AdaptiveConstraintGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final double itemHeight;
  final double spacing;

  const AdaptiveConstraintGrid({
    super.key,
    required this.children,
    this.minItemWidth = 180.0,
    this.itemHeight = 120.0,
    this.spacing = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        int crossAxisCount = (availableWidth / (minItemWidth + spacing)).floor();
        if (crossAxisCount < 1) crossAxisCount = 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            mainAxisExtent: itemHeight,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}

/// Helper method to create a dialog constraint box that safely bounds dialog width
/// based on available screen width.
BoxConstraints adaptiveDialogConstraints(BuildContext context, {double desiredWidth = 480.0}) {
  final screenWidth = MediaQuery.of(context).size.width;
  final maxWidth = math.min(desiredWidth, screenWidth - 32.0);
  return BoxConstraints(maxWidth: math.max(280.0, maxWidth));
}

/// Context extensions for quick constraint check
extension ResponsiveContext on BuildContext {
  bool get isCompact => MediaQuery.of(this).size.width < AppBreakpoints.compactMax;
  bool get isMedium =>
      MediaQuery.of(this).size.width >= AppBreakpoints.compactMax &&
      MediaQuery.of(this).size.width < AppBreakpoints.mediumMax;
  bool get isExpanded => MediaQuery.of(this).size.width >= AppBreakpoints.mediumMax;
}
