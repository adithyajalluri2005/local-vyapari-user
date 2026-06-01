import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/features/chat/presentation/screens/chat_screen.dart';
import 'package:local_vyapari_user/features/chat/providers/chat_provider.dart';
import 'package:local_vyapari_user/shared/models/chat_message.dart';

class MockChatService implements ChatService {
  @override
  Future<void> markAsRead(String shopId) async {}

  @override
  Future<void> sendMessage({
    required String shopId,
    required String text,
    String? shopName,
    String? shopLogo,
  }) async {}

  @override
  Future<void> deleteChat(String shopId) async {}
}

void main() {
  testWidgets('ChatScreen shows placeholder when message list is empty', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatMessagesProvider('shop_123').overrideWith((ref) => Stream.value([])),
          userIdProvider.overrideWith((ref) => 'user_xyz'),
          chatServiceProvider.overrideWith((ref) => MockChatService()),
        ],
        child: const MaterialApp(
          home: ChatScreen(shopId: 'shop_123', shopName: 'Super Mart'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify empty state placeholder
    expect(find.text('Start the conversation'), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
  });

  testWidgets('ChatScreen renders messages list', (WidgetTester tester) async {
    final mockMessages = [
      ChatMessage(
        id: 'msg_1',
        senderId: 'user_xyz',
        text: 'Hello, is this item available?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      ChatMessage(
        id: 'msg_2',
        senderId: 'shop_123',
        text: 'Yes, we have 10 units in stock.',
        timestamp: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatMessagesProvider('shop_123').overrideWith((ref) => Stream.value(mockMessages)),
          userIdProvider.overrideWith((ref) => 'user_xyz'),
          chatServiceProvider.overrideWith((ref) => MockChatService()),
        ],
        child: const MaterialApp(
          home: ChatScreen(shopId: 'shop_123', shopName: 'Super Mart'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify messages text is on screen
    expect(find.text('Hello, is this item available?'), findsOneWidget);
    expect(find.text('Yes, we have 10 units in stock.'), findsOneWidget);
  });
}
