import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FeedbackService {
  final _firestore = FirebaseFirestore.instance;

  Future<void> submitFeedback({
    required String userId,
    required String userEmail,
    required String type,
    required String message,
  }) async {
    await _firestore.collection('feedback').add({
      'userId': userId,
      'userEmail': userEmail,
      'type': type,
      'message': message,
      'platform': kIsWeb ? 'web' : Platform.operatingSystem,
      'status': 'new',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
