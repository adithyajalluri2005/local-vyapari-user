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

final chatMessagesProvider = StreamProvider.family<List<ChatMessage>, String>((ref, shopId) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return Stream.value([]);

  final dbRef = FirebaseDatabase.instance.ref('chats/$userId/$shopId/messages');
  return dbRef.onValue.map((event) {
    final snapshot = event.snapshot;
    if (!snapshot.exists || snapshot.value == null) return [];

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

final userChatsStreamProvider = StreamProvider<List<ChatSession>>((ref) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return Stream.value([]);

  final dbRef = FirebaseDatabase.instance.ref('chats/$userId');
  return dbRef.onValue.map((event) {
    final snapshot = event.snapshot;
    if (!snapshot.exists || snapshot.value == null) return [];

    final List<ChatSession> sessions = [];
    final map = snapshot.value as Map<dynamic, dynamic>;
    map.forEach((key, value) {
      if (value is Map) {
        sessions.add(ChatSession.fromRTDB(key.toString(), value));
      }
    });

    // Sort by last message timestamp (newest first)
    sessions.sort((a, b) => b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp));
    return sessions;
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
      'text': text.trim(),
      'timestamp': timestamp,
    };

    final messageRef = _rtdb.ref('chats/$userId/$shopId/messages').push();
    final messageId = messageRef.key;

    if (messageId != null) {
      final Map<String, dynamic> updates = {
        'chats/$userId/$shopId/messages/$messageId': messageData,
        'chats/$shopId/$userId/messages/$messageId': messageData,
        'chats/$userId/$shopId/lastMessage': {
          'text': text.trim(),
          'timestamp': timestamp,
          'unread': false,
        },
        'chats/$shopId/$userId/lastMessage': {
          'text': text.trim(),
          'timestamp': timestamp,
          'unread': true,
        },
        'chats/$shopId/$userId/userName': user?.email ?? 'Customer',
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
}

