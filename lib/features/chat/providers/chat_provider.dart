import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/features/auth/providers/auth_provider.dart';
import 'package:local_vyapari_user/features/auth/models/auth_state.dart';
import 'package:local_vyapari_user/shared/models/chat_message.dart';
import 'package:local_vyapari_user/shared/models/chat_session.dart';

final userIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authProvider);
  if (authState is Authenticated) {
    return authState.user.uid;
  }
  return FirebaseAuth.instance.currentUser?.uid;
});

final chatMessagesProvider = StreamProvider.autoDispose.family<List<ChatMessage>, String>((ref, shopId) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return Stream.value([]);

  final dbRef = FirebaseDatabase.instance
      .ref('chats/$userId/$shopId/messages')
      .orderByChild('timestamp')
      .limitToLast(50);
  return dbRef.onValue.map((event) {
    final snapshot = event.snapshot;
    if (!snapshot.exists || snapshot.value is! Map) return [];

    final List<ChatMessage> messages = [];
    final map = snapshot.value as Map<dynamic, dynamic>;
    map.forEach((key, value) {
      if (value is Map) {
        messages.add(ChatMessage.fromRTDB(key.toString(), value));
      }
    });

    // Sort by chronological order (oldest first)
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return messages;
  });
});

final userChatsStreamProvider = StreamProvider.autoDispose<List<ChatSession>>((ref) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return Stream.value([]);

  final dbRef = FirebaseDatabase.instance.ref('chats/$userId');
  return dbRef.onValue.asyncMap((event) async {
    final snapshot = event.snapshot;
    if (!snapshot.exists || snapshot.value is! Map) return <ChatSession>[];

    final List<ChatSession> sessions = [];
    final map = snapshot.value as Map<dynamic, dynamic>;
    map.forEach((key, value) {
      if (value is Map) {
        final session = ChatSession.fromRTDB(key.toString(), value);
        // Only show chat session if the logged-in user is the customer
        final customerId = value['customerId']?.toString() ?? value['lastMessage']?['customerId']?.toString();
        if (customerId != null && customerId != userId) return;
        sessions.add(session);
      }
    });

    sessions.sort((a, b) => b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp));

    // Fetch fresh shop logos from Firestore so vendor photo changes are reflected
    final shopIds = sessions.map((s) => s.shopId).toList();
    if (shopIds.isEmpty) return sessions;

    try {
      final firestore = FirebaseFirestore.instance;
      final logoMap = <String, String>{};
      for (var i = 0; i < shopIds.length; i += 30) {
        final chunk = shopIds.sublist(i, (i + 30).clamp(0, shopIds.length));
        final snap = await firestore
            .collection('searchable_shops')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          final logo = doc.data()['shopLogo']?.toString() ?? '';
          if (logo.isNotEmpty) logoMap[doc.id] = logo;
        }
      }
      return sessions
          .map((s) => logoMap.containsKey(s.shopId) ? s.copyWith(shopLogo: logoMap[s.shopId]) : s)
          .toList();
    } catch (_) {
      return sessions;
    }
  });
});

final chatServiceProvider = Provider((ref) => ChatService());

class ChatService {
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  Future<void> sendMessage({
    required String shopId,
    required String text,
    String? shopName,
    String? shopLogo,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;
    if (userId == null || text.trim().isEmpty) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final messageData = {
      'senderId': userId,
      'receiverId': shopId,
      'vendorId': shopId,
      'customerId': userId,
      'shopId': shopId,
      'text': text.trim(),
      'timestamp': timestamp,
    };

    final messageRef = _rtdb.ref('chats/$userId/$shopId/messages').push();
    final messageId = messageRef.key;

    if (messageId != null) {
      final Map<String, dynamic> updates = {
        'chats/$userId/$shopId/vendorId': shopId,
        'chats/$userId/$shopId/customerId': userId,
        'chats/$userId/$shopId/shopId': shopId,
        'chats/$userId/$shopId/messages/$messageId': messageData,
        'chats/$userId/$shopId/lastMessage': {
          'text': text.trim(),
          'timestamp': timestamp,
          'senderId': userId,
          'vendorId': shopId,
          'customerId': userId,
          'shopId': shopId,
          'unread': false,
        },
        'chats/$shopId/$userId/vendorId': shopId,
        'chats/$shopId/$userId/customerId': userId,
        'chats/$shopId/$userId/shopId': shopId,
        'chats/$shopId/$userId/messages/$messageId': messageData,
        'chats/$shopId/$userId/lastMessage': {
          'text': text.trim(),
          'timestamp': timestamp,
          'senderId': userId,
          'vendorId': shopId,
          'customerId': userId,
          'shopId': shopId,
          'unread': true,
        },
        'chats/$shopId/$userId/userName': user?.displayName != null && user!.displayName!.isNotEmpty ? user.displayName! : 'Customer',
      };

      if (shopName != null && shopName.isNotEmpty) {
        updates['chats/$userId/$shopId/shopName'] = shopName;
      }
      if (shopLogo != null && shopLogo.isNotEmpty) {
        updates['chats/$userId/$shopId/shopLogo'] = shopLogo;
      }

      await _rtdb.ref().update(updates);
    }
  }

  Future<void> markAsRead(String shopId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    try {
      await _rtdb.ref('chats/$userId/$shopId/lastMessage/unread').set(false);
    } catch (e) {
      // Handle or ignore write exceptions on read marking
    }
  }

  Future<void> deleteChat(String shopId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    try {
      await _rtdb.ref('chats/$userId/$shopId').remove();
    } catch (e) {
      // Handle or ignore write exceptions on deletion
    }
  }
}

