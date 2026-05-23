import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/core/theme/app_text_styles.dart';

class ReviewCard extends StatefulWidget {
  final String userName;
  final double rating;
  final String comment;
  final DateTime createdAt;

  const ReviewCard({
    super.key,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  bool _isExpanded = false;
  static const int _maxLinesLimit = 3;

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('dd MMM yyyy').format(widget.createdAt);
    
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row with User avatar, name and date
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  child: Text(
                    widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'U',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.userName,
                        style: AppTextStyles.bodyLarge(context, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        formattedDate,
                        style: AppTextStyles.bodyMedium(context, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                // Stars Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getRatingColor(widget.rating).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.rating.toStringAsFixed(1),
                        style: TextStyle(
                          color: _getRatingColor(widget.rating),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.star,
                        color: _getRatingColor(widget.rating),
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.comment.isNotEmpty) ...[
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final textSpan = TextSpan(
                    text: widget.comment,
                    style: AppTextStyles.bodyLarge(context, color: Colors.grey[800], height: 1.4),
                  );

                  final textPainter = TextPainter(
                    text: textSpan,
                    textDirection: TextDirection.ltr,
                    maxLines: _maxLinesLimit,
                  );

                  textPainter.layout(maxWidth: constraints.maxWidth);
                  final isLongText = textPainter.didExceedMaxLines;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSize(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeInOut,
                        alignment: Alignment.topLeft,
                        child: Text(
                          widget.comment,
                          style: AppTextStyles.bodyLarge(context, color: Colors.grey[800], height: 1.4),
                          maxLines: _isExpanded ? null : _maxLinesLimit,
                          overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                        ),
                      ),
                      if (isLongText) ...[
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isExpanded = !_isExpanded;
                            });
                          },
                          child: Text(
                            _isExpanded ? 'Show Less' : 'Read More',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4.0) return Colors.green[700]!;
    if (rating >= 3.0) return Colors.amber[800]!;
    return Colors.red[600]!;
  }
}
