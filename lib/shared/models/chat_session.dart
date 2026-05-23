class ChatSession {
  final String shopId;
  final String shopName;
  final String shopLogo;
  final String lastMessageText;
  final DateTime lastMessageTimestamp;
  final bool unread;

  ChatSession({
    required this.shopId,
    required this.shopName,
    required this.shopLogo,
    required this.lastMessageText,
    required this.lastMessageTimestamp,
    required this.unread,
  });

  factory ChatSession.fromRTDB(String shopId, Map<dynamic, dynamic> map) {
    final lastMsg = map['lastMessage'] as Map? ?? {};
    return ChatSession(
      shopId: shopId,
      shopName: map['shopName']?.toString() ?? '',
      shopLogo: map['shopLogo']?.toString() ?? '',
      lastMessageText: lastMsg['text']?.toString() ?? '',
      lastMessageTimestamp: DateTime.fromMillisecondsSinceEpoch(
        lastMsg['timestamp'] is int ? lastMsg['timestamp'] : 0,
      ),
      unread: lastMsg['unread'] == true,
    );
  }
}
