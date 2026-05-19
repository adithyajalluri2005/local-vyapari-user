import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_shops_provider.dart';
import 'package:local_vyapari_user/shared/models/product.dart';

final nearbyProductsProvider = StreamProvider<List<Product>>((ref) {
  final shopsAsyncValue = ref.watch(nearbyShopsProvider);

  return shopsAsyncValue.when(
    data: (shops) {
      if (shops.isEmpty) return Stream.value([]);

      final shopIds = shops.map((s) => s.id).take(10).toList(); // Firestore array-contains-any limit is 10

      return FirebaseFirestore.instance
          .collection('products')
          .where('shopId', whereIn: shopIds)
          .where('isActive', isEqualTo: true)
          .where('isOutOfStock', isEqualTo: false)
          .limit(20)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => Product.fromFirestore(doc))
            .toList();
      });
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});
