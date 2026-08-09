import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

/// Reusable Shimmer Skeleton Placeholder Widget
class ShimmerLoadingWidget extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerLoadingWidget({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade300,
      highlightColor: isDark ? const Color(0xFF334155) : Colors.grey.shade100,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  /// List Tile Skeleton Placeholder
  static Widget listTilePlaceholder(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const ShimmerLoadingWidget(width: 48, height: 48, borderRadius: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerLoadingWidget(width: double.infinity, height: 16, borderRadius: 8),
                const SizedBox(height: 8),
                ShimmerLoadingWidget(width: 120, height: 12, borderRadius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Student Card Grid/List Skeleton Placeholder
  static Widget studentCardPlaceholder(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const ShimmerLoadingWidget(width: 54, height: 54, borderRadius: 27),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShimmerLoadingWidget(width: 140, height: 16, borderRadius: 8),
                const SizedBox(height: 8),
                ShimmerLoadingWidget(width: 100, height: 12, borderRadius: 6),
              ],
            ),
          ),
          const ShimmerLoadingWidget(width: 60, height: 24, borderRadius: 12),
        ],
      ),
    );
  }

  /// Dashboard Stat Cards Skeleton Placeholder
  static Widget dashboardCardsPlaceholder(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: ShimmerLoadingWidget(width: double.infinity, height: 110, borderRadius: 16)),
        SizedBox(width: 12),
        Expanded(child: ShimmerLoadingWidget(width: double.infinity, height: 110, borderRadius: 16)),
      ],
    );
  }
}

/// Modern Inline Loading Button for forms & actions
class InlineLoadingButton extends StatelessWidget {
  final bool isLoading;
  final bool isSuccess;
  final String label;
  final String loadingLabel;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final bool isOutlined;
  final double verticalPadding;

  const InlineLoadingButton({
    super.key,
    required this.isLoading,
    this.isSuccess = false,
    required this.label,
    this.loadingLabel = 'Saving...',
    this.icon,
    this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.isOutlined = false,
    this.verticalPadding = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppTheme.primaryBlue;

    if (isOutlined) {
      return OutlinedButton(
        onPressed: (isLoading || isSuccess) ? null : onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: verticalPadding, horizontal: 16),
          side: BorderSide(color: bg),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _buildContent(context, isOutlinedText: true),
      );
    }

    return ElevatedButton(
      onPressed: (isLoading || isSuccess) ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        padding: EdgeInsets.symmetric(vertical: verticalPadding, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context, {bool isOutlinedText = false}) {
    final color = isOutlinedText ? (textColor ?? AppTheme.primaryBlue) : (textColor ?? Colors.white);

    if (isSuccess) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Text(
            'Saved ✓',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      );
    }

    if (isLoading) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            loadingLabel,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Image Upload Progress Overlay showing real percentage
class UploadProgressOverlay extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final String statusText;

  const UploadProgressOverlay({
    super.key,
    required this.progress,
    this.statusText = 'Uploading photo...',
  });

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).clamp(0, 100).toInt();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$statusText ($pct%)',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.secondaryGreen),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

/// Top Background Refresh Bar for quiet sync updates
class BackgroundRefreshBar extends StatelessWidget {
  final bool isRefreshing;
  final String label;

  const BackgroundRefreshBar({
    super.key,
    required this.isRefreshing,
    this.label = 'Updating...',
  });

  @override
  Widget build(BuildContext context) {
    if (!isRefreshing) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }
}
