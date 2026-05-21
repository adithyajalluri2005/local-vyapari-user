import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';

class SearchIndexerService {
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> syncShopsToFirestore() async {
    try {
      final snapshot = await _rtdb.ref().child('shop').get();
      if (snapshot.exists && snapshot.value != null) {
        final shopsMap = snapshot.value as Map<dynamic, dynamic>;
        
        final batch = _firestore.batch();
        final collection = _firestore.collection('searchable_shops');

        for (final entry in shopsMap.entries) {
          final shopId = entry.key as String;
          final shopData = entry.value as Map<dynamic, dynamic>;
          final shop = Shop.fromRTDB(shopId, shopData);

          final geoFirePoint = GeoFirePoint(GeoPoint(shop.location.latitude, shop.location.longitude));
          
          batch.set(collection.doc(shopId), {
            'shopId': shop.id,
            'shopName': shop.shopName,
            'description': shop.description,
            'location': {
              'address': shop.location.address,
              'city': shop.location.city,
            },
            'geo': geoFirePoint.data,
          }, SetOptions(merge: true));
        }

        await batch.commit();
        print('Successfully synced ${shopsMap.length} shops to Firestore for search.');
      }
    } catch (e) {
      print('Error syncing shops to Firestore: $e');
    }
  }
}

final searchIndexerServiceProvider = Provider((ref) => SearchIndexerService());
