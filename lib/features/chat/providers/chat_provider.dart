import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/shared/models/chat_message.dart';

final chatMessagesProvider = StreamProvider.family<List<ChatMessage>, String>((ref, shopId) {
  final userId = FirebaseAuth.instance.currentUser?.uid;
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

final chatServiceProvider = Provider((ref) => ChatService());

class ChatService {
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  Future<void> sendMessage(String shopId, String text) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
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
        }
      };

      await _rtdb.ref().update(updates);
    }
  }
}
