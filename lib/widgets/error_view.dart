import 'package:flutter/material.dart';
import '../utils/error_utils.dart';

/// Reusable full-page or section error state widget
class ErrorView extends StatelessWidget {
  final dynamic error;
  final String? title;
  final String? message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;
  final Color? iconColor;

  const ErrorView({
    super.key,
    this.error,
    this.title,
    this.message,
    this.onRetry,
    this.retryLabel = 'Try Again',
    this.icon = Icons.cloud_off_rounded,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayMessage = message ?? (error != null ? ErrorUtils.getFriendlyMessage(error) : 'Something went wrong.');
    final primaryColor = iconColor ?? theme.colorScheme.error;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: primaryColor),
            ),
            const SizedBox(height: 18),
            Text(
              title ?? 'Unable to Load Data',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              displayMessage,
              style: TextStyle(
                fontSize: 14,
                color: theme.brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(retryLabel),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact inline error banner for forms, cards, and modal dialogs
class InlineErrorBanner extends StatelessWidget {
  final dynamic error;
  final String? message;
  final VoidCallback? onDismiss;
  final EdgeInsetsGeometry margin;

  const InlineErrorBanner({
    super.key,
    this.error,
    this.message,
    this.onDismiss,
    this.margin = const EdgeInsets.only(bottom: 16),
  });

  @override
  Widget build(BuildContext context) {
    final display = message ?? (error != null ? ErrorUtils.getFriendlyMessage(error) : 'An error occurred.');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3F1919) : const Color(0xFFFEF2F2),
        border: Border.all(color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              display,
              style: TextStyle(
                color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: onDismiss,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(Icons.close_rounded, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A media placeholder when diagrams, maps, or charts fail to load
class MediaErrorPlaceholder extends StatelessWidget {
  final VoidCallback? onRetry;
  final double height;

  const MediaErrorPlaceholder({
    super.key,
    this.onRetry,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF26262E) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined, size: 36, color: Colors.grey[500]),
          const SizedBox(height: 8),
          Text(
            'Failed to load diagram / image',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reload Image', style: TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }
}
