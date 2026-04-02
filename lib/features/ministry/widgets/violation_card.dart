import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/config.dart';
import '../../../core/l10n/app_localizations.dart';

class ViolationCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final Function(String) onStatusChanged;
  final bool isUpdating;

  const ViolationCard({
    super.key,
    required this.report,
    required this.onStatusChanged,
    this.isUpdating = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = report['status'] ?? 'جديد';
    final isResolved = status == 'تم الضبط' || status == 'بلاغ كاذب';
    final statusColor = _getStatusColor(context, status);
    final imageUrl = _resolveImageUrl(report['image_url']?.toString());
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
        ),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image or Placeholder
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 70,
                    height: 70,
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: hasImage
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.broken_image,
                                  color: Colors.grey,
                                ),
                          )
                        : const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report['shop_name'] ?? 'متجر غير معروف',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        "${report['product']} - ${report['price_seen']} ر.ي",
                        style: GoogleFonts.cairo(
                          color: scheme.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      if (report['notes'] != null &&
                          report['notes'].toString().isNotEmpty)
                        Text(
                          report['notes'],
                          style: GoogleFonts.cairo(
                            color: Theme.of(context).hintColor,
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          status,
                          style: GoogleFonts.cairo(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!isResolved) ...[
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isUpdating)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else ...[
                    TextButton(
                      onPressed: () => onStatusChanged("بلاغ كاذب"),
                      child: Text(
                        context.tr("تجاهل"),
                        style: GoogleFonts.cairo(
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: () => onStatusChanged("تم الضبط"),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 32),
                      ),
                      child: Text(
                        context.tr("تم الضبط"),
                        style: GoogleFonts.cairo(fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(BuildContext context, String status) {
    switch (status) {
      case 'جديد':
        return Theme.of(context).colorScheme.error;
      case 'قيد المراجعة':
        return Colors.orange.shade700;
      case 'تم الضبط':
        return Colors.green.shade700;
      case 'بلاغ كاذب':
        return Theme.of(context).hintColor;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String? _resolveImageUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return null;
    final normalized = rawUrl.replaceAll('\\', '/');
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return normalized;
    }
    if (normalized.startsWith('/')) {
      return '${AppConfig.baseUrl}$normalized';
    }
    if (normalized.startsWith('uploads/')) {
      return '${AppConfig.baseUrl}/$normalized';
    }
    return normalized;
  }
}
