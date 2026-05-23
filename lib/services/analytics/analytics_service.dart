import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  Future<void> trackShopView(String vendorUid) async {
    try {
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      final ref = _db.ref('analytics/$vendorUid');

      await ref.update({
        'totals/views': ServerValue.increment(1),
        'daily/$todayStr/views': ServerValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error tracking shop view: $e');
    }
  }

  Future<void> trackProfileClick(String vendorUid) async {
    try {
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      final ref = _db.ref('analytics/$vendorUid');

      await ref.update({
        'totals/clicks': ServerValue.increment(1),
        'daily/$todayStr/clicks': ServerValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error tracking profile click: $e');
    }
  }
}
