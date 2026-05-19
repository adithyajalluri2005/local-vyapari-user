import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_shops_provider.dart';
import 'package:local_vyapari_user/shared/models/offer.dart';

final nearbyOffersProvider = StreamProvider<List<Offer>>((ref) {
  final shopsAsyncValue = ref.watch(nearbyShopsProvider);

  return shopsAsyncValue.when(
    data: (shops) {
      if (shops.isEmpty) return Stream.value([]);

      final shopIds = shops.map((s) => s.id).take(10).toList(); // Firestore array-contains-any limit is 10
      final now = DateTime.now();

      return FirebaseFirestore.instance
          .collection('offers')
          .where('shopId', whereIn: shopIds)
          .where('isActive', isEqualTo: true)
          // Ideally, we'd also filter by endDate >= now, but Firestore limits inequality filters 
          // to a single field. We'll filter end date client side.
          .snapshots()
          .map((snapshot) {
        final offers = snapshot.docs
            .map((doc) => Offer.fromFirestore(doc))
            .where((offer) =>
                (offer.endDate == null || offer.endDate!.isAfter(now)) &&
                (offer.startDate == null || offer.startDate!.isBefore(now)))
            .toList();
        
        offers.sort((a, b) => b.discountPercentage.compareTo(a.discountPercentage));
        return offers;
      });
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});
