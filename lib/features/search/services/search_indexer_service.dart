import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';

/// [SearchIndexerService]
/// 
/// @deprecated Client-side database sync of the entire database collection to Firestore
/// is deprecated to ensure secure database writes, minimize API quota consumption, and
/// prevent concurrency issues.
/// 
/// Production indexes must be managed via backend Firebase Cloud Functions onRTDBUpdate triggers.
@deprecated
class SearchIndexerService {
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> syncShopsToFirestore() async {
    // Deprecated: Disabling sync to enforce backend-driven indexing
    return;
  }
}

final searchIndexerServiceProvider = Provider((ref) => SearchIndexerService());
