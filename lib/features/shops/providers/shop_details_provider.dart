import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';

final shopDetailsProvider = FutureProvider.family<Shop?, String>((ref, shopId) async {
  final event = await FirebaseDatabase.instance.ref('shop/$shopId').once();
  final snapshot = event.snapshot;
  if (snapshot.value is! Map) return null;
  try {
    final shopData = Map<dynamic, dynamic>.from(snapshot.value as Map);
    return Shop.fromRTDB(shopId, shopData);
  } catch (e) {
    // Malformed shop record → treat as not found rather than crashing.
    debugPrint('Error parsing shop $shopId: $e');
    return null;
  }
  // Network/permission failures intentionally propagate so the screen can show
  // an error state via AsyncValue.error.
});

final shopDetailsStreamProvider = StreamProvider.family<Shop?, String>((ref, shopId) {
  return FirebaseDatabase.instance.ref('shop/$shopId').onValue.map((event) {
    final snapshot = event.snapshot;
    if (snapshot.value is! Map) return null;
    final shopData = Map<dynamic, dynamic>.from(snapshot.value as Map);
    return Shop.fromRTDB(shopId, shopData);
  });
});
