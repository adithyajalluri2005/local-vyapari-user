import 'package:flutter/material.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/core/theme/app_text_styles.dart';

class RatingBreakdown extends StatelessWidget {
  final double averageRating;
  final int totalCount;
  final Map<int, int> distribution;

  const RatingBreakdown({
    super.key,
    required this.averageRating,
    required this.totalCount,
    required this.distribution,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Section: Average Rating summary
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        averageRating > 0 ? averageRating.toStringAsFixed(1) : '—',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.star_rounded,
                        color: Colors.amber,
                        size: 30,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalCount ratings',
                  style: AppTextStyles.bodyMedium(context, color: cs.onSurfaceVariant, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Divider between left and right
          Container(
            height: 100,
            width: 1,
            color: cs.outline,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),

          // Right Section: Bars showing distribution
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(5, (index) {
                final starNum = 5 - index;
                final count = distribution[starNum] ?? 0;
                final percentage = totalCount > 0 ? (count / totalCount) : 0.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    children: [
                      // Star label
                      SizedBox(
                        width: 24,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '$starNum',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface,
                              ),
                            ),
                            Text(
                              '★',
                              style: TextStyle(
                                fontSize: 10,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Progress bar
                      Expanded(
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: cs.surfaceContainerHighest,
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: percentage,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                color: _getStarColor(starNum),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Count label
                      SizedBox(
                        width: 28,
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStarColor(int star) {
    switch (star) {
      case 5:
        return Colors.green[600]!;
      case 4:
        return Colors.green[400]!;
      case 3:
        return Colors.amber[500]!;
      case 2:
        return Colors.orange[400]!;
      case 1:
        return Colors.red[500]!;
      default:
        return Colors.grey;
    }
  }
}
