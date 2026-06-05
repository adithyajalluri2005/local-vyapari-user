import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/core/theme/app_text_styles.dart';
import 'package:local_vyapari_user/features/reviews/providers/reviews_provider.dart';
import 'package:local_vyapari_user/features/auth/providers/auth_provider.dart';
import 'package:local_vyapari_user/features/auth/models/auth_state.dart';

class RateItemBottomSheet extends ConsumerStatefulWidget {
  final String? shopId;
  final String? productId;
  final String name;
  final double? existingRating;
  final String? existingComment;

  const RateItemBottomSheet({
    super.key,
    this.shopId,
    this.productId,
    required this.name,
    this.existingRating,
    this.existingComment,
  }) : assert(shopId != null, 'shopId must be provided');

  @override
  ConsumerState<RateItemBottomSheet> createState() => _RateItemBottomSheetState();
}

class _RateItemBottomSheetState extends ConsumerState<RateItemBottomSheet> {
  late double _rating;
  late final TextEditingController _commentController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.existingRating ?? 5.0;
    _commentController = TextEditingController(text: widget.existingComment ?? '');
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    final authState = ref.read(authProvider);
    if (authState is! Authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('You must be signed in to submit a review.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final reviewsService = ref.read(reviewsServiceProvider);
      final userId = authState.user.uid;
      
      // Fallback to email prefix or Anonymous if displayName is empty
      final userDisplayName = authState.user.displayName != null && authState.user.displayName!.isNotEmpty
          ? authState.user.displayName!
          : (authState.user.email != null && authState.user.email!.isNotEmpty
              ? authState.user.email!.split('@').first
              : 'Anonymous User');

      if (widget.productId != null) {
        await reviewsService.submitProductReview(
          productId: widget.productId!,
          shopId: widget.shopId!,
          userId: userId,
          userDisplayName: userDisplayName,
          rating: _rating,
          comment: _commentController.text.trim(),
        );
      } else {
        await reviewsService.submitShopReview(
          shopId: widget.shopId!,
          userId: userId,
          userDisplayName: userDisplayName,
          rating: _rating,
          comment: _commentController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate successful submission
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Review submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit review: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      decoration: BoxDecoration(
        color: Theme.of(context).canvasColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Title
            Text(
              widget.existingRating != null ? 'Update your review' : 'Rate this item',
              style: AppTextStyles.titleMedium(context, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              widget.name,
              style: AppTextStyles.bodyLarge(context, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Star Rating Bar
            Center(
              child: RatingBar.builder(
                initialRating: _rating,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: true,
                itemCount: 5,
                itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                itemBuilder: (context, _) => const Icon(
                  Icons.star_rounded,
                  color: Colors.amber,
                ),
                onRatingUpdate: (rating) {
                  setState(() {
                    _rating = rating;
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                _getRatingText(context, _rating),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Review comment field
            TextField(
              controller: _commentController,
              maxLines: 4,
              maxLength: 300,
              decoration: InputDecoration(
                hintText: 'Share details of your experience...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            ElevatedButton(
              onPressed: _isLoading ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      widget.existingRating != null ? 'Update Review' : 'Submit Review',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingText(BuildContext context, double rating) {
    if (rating >= 4.8) return 'Excellent!';
    if (rating >= 4.0) return 'Very Good';
    if (rating >= 3.0) return 'Good';
    if (rating >= 2.0) return 'Fair';
    return 'Poor';
  }
}
