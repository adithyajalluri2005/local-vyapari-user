import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/core/theme/app_sizes.dart';
import 'package:local_vyapari_user/core/theme/app_text_styles.dart';
import 'package:local_vyapari_user/core/theme/app_spacing.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/features/chat/providers/chat_provider.dart';
import 'package:local_vyapari_user/features/shops/providers/shop_details_provider.dart';
import 'package:local_vyapari_user/shared/models/chat_session.dart';

class ChatsListScreen extends ConsumerWidget {
  const ChatsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(userChatsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Chats',
          style: AppTextStyles.titleMedium(context, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: chatsAsync.when(
        data: (chats) {
          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  AppSpacing.verticalMd,
                  Text(
                    'No conversations yet',
                    style: AppTextStyles.titleMedium(context, color: Colors.grey[600]),
                  ),
                  AppSpacing.verticalSm,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Start chatting with local vendors directly from their shop details page!',
                      style: AppTextStyles.bodyMedium(context, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.symmetric(
              vertical: AppSizes.paddingMedium(context),
            ),
            itemCount: chats.length,
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              indent: 76,
              endIndent: 16,
            ),
            itemBuilder: (context, index) {
              return _ChatSessionTile(session: chats[index]);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text(
            'Failed to load chats: $err',
            style: AppTextStyles.bodyLarge(context, color: AppTheme.errorColor),
          ),
        ),
      ),
    );
  }
}

class _ChatSessionTile extends ConsumerWidget {
  final ChatSession session;

  const _ChatSessionTile({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopDetailsAsync = ref.watch(shopDetailsProvider(session.shopId));

    return shopDetailsAsync.when(
      data: (shop) {
        final name = shop?.shopName ?? (session.shopName.isNotEmpty ? session.shopName : 'Shop');
        final logo = shop?.shopLogo ?? session.shopLogo;
        return _buildTile(context, name, logo);
      },
      loading: () => _buildTile(
        context,
        session.shopName.isNotEmpty ? session.shopName : 'Loading shop...',
        session.shopLogo,
      ),
      error: (_, __) => _buildTile(
        context,
        session.shopName.isNotEmpty ? session.shopName : 'Shop',
        session.shopLogo,
      ),
    );
  }

  Widget _buildTile(BuildContext context, String name, String logoUrl) {
    final formattedTime = session.lastMessageTimestamp.millisecondsSinceEpoch == 0
        ? ''
        : _formatDateTime(session.lastMessageTimestamp);

    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.circular),
          color: Colors.grey[200],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.circular),
          child: logoUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: logoUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(color: Colors.white),
                  ),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.storefront_outlined,
                    color: Colors.grey,
                  ),
                )
              : const Icon(
                  Icons.storefront_outlined,
                  color: Colors.grey,
                  size: 24,
                ),
        ),
      ),
      title: Text(
        name,
        style: AppTextStyles.bodyLarge(
          context,
          fontWeight: session.unread ? FontWeight.bold : FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(
          session.lastMessageText.isNotEmpty ? session.lastMessageText : 'Start chatting',
          style: AppTextStyles.bodyMedium(
            context,
            color: session.unread
                ? Theme.of(context).colorScheme.onSurface
                : Colors.grey[600],
            fontWeight: session.unread ? FontWeight.w500 : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (formattedTime.isNotEmpty)
            Text(
              formattedTime,
              style: TextStyle(
                fontSize: 12,
                color: session.unread ? AppTheme.primaryColor : Colors.grey,
                fontWeight: session.unread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          if (session.unread) ...[
            AppSpacing.verticalSm,
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ],
      ),
      onTap: () {
        context.push('/chat', extra: {
          'shopId': session.shopId,
          'shopName': name,
          'shopLogo': logoUrl,
        });
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat('hh:mm a').format(dateTime);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(dateTime); // Weekday name
    } else {
      return DateFormat('dd/MM/yyyy').format(dateTime);
    }
  }
}
