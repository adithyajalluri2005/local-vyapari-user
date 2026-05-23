import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';

final shopDetailsProvider = FutureProvider.family<Shop?, String>((ref, shopId) async {
  try {
    final event = await FirebaseDatabase.instance.ref('shop/$shopId').once();
    final snapshot = event.snapshot;
    if (snapshot.exists && snapshot.value != null) {
      final shopData = Map<dynamic, dynamic>.from(snapshot.value as Map<dynamic, dynamic>);
      return Shop.fromRTDB(shopId, shopData);
    }
  } catch (e) {
    // Return null or handle error
  }
  return null;
});

final shopDetailsStreamProvider = StreamProvider.family<Shop?, String>((ref, shopId) {
  return FirebaseDatabase.instance.ref('shop/$shopId').onValue.map((event) {
    final snapshot = event.snapshot;
    if (snapshot.exists && snapshot.value != null) {
      final shopData = Map<dynamic, dynamic>.from(snapshot.value as Map<dynamic, dynamic>);
      return Shop.fromRTDB(shopId, shopData);
    }
    return null;
  });
});
