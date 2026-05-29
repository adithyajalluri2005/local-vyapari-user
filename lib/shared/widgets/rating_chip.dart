import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';

class RatingChip extends StatelessWidget {
  final double rating;
  final int? totalReviews;

  const RatingChip({super.key, required this.rating, this.totalReviews});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 12, color: AppColors.warning),
          const SizedBox(width: 3),
          Text(
            rating > 0 ? rating.toStringAsFixed(1) : 'New',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.warning,
            ),
          ),
          if (totalReviews != null && totalReviews! > 0) ...[
            const SizedBox(width: 3),
            Text(
              '($totalReviews)',
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: AppColors.textHint,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
