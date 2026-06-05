import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/shared/widgets/skeleton_card.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/features/chat/providers/chat_provider.dart';
import 'package:local_vyapari_user/services/cache/app_cache_manager.dart';
import 'package:local_vyapari_user/shared/models/chat_session.dart';
import 'package:local_vyapari_user/shared/widgets/app_animations.dart';

class ChatsListScreen extends ConsumerWidget {
  const ChatsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatsAsync = ref.watch(userChatsStreamProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkScaffold : AppColors.background,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'My Chats',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border.withValues(alpha: 0.5)),
        ),
      ),
      body: chatsAsync.when(
        skipLoadingOnReload: true,
        loading: () => const SkeletonListView(),
        error: (err, _) => _ErrorView(message: err.toString()),
        data: (chats) {
          if (chats.isEmpty) return const _EmptyView();

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 90),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              return FadeInSlide(
                delay: Duration(milliseconds: 50 * index),
                child: _ChatTile(
                  session: chat,
                  onDelete: () async {
                    final ok = await _confirmDelete(context, chat.shopName);
                    if (ok == true) {
                      await ref.read(chatServiceProvider).deleteChat(chat.shopId);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, String shopName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(
          'Delete conversation?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
          'Your chat with ${shopName.isNotEmpty ? shopName : 'Shop'} will be removed from your list.',
          style: GoogleFonts.poppins(fontSize: 13, color: isDark ? Colors.white70 : AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: isDark ? Colors.white70 : AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.poppins(color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Chat tile ─────────────────────────────────────────────────────────────────

class _ChatTile extends StatelessWidget {
  final ChatSession session;
  final VoidCallback onDelete;

  const _ChatTile({required this.session, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = session.shopName.isNotEmpty ? session.shopName : 'Shop';
    final logo = session.shopLogo;
    final time = _formatTime(session.lastMessageTimestamp);

    return Dismissible(
      key: Key(session.shopId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
      ),
      confirmDismiss: (_) async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            title: Text('Delete conversation?',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
            content: Text('This will remove the chat from your list.',
                style: GoogleFonts.poppins(fontSize: 13, color: isDark ? Colors.white70 : AppColors.textSecondary)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: GoogleFonts.poppins(color: isDark ? Colors.white70 : AppColors.textSecondary)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Delete',
                    style: GoogleFonts.poppins(color: AppColors.error, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
        return ok ?? false;
      },
      onDismissed: (_) => onDelete(),
      child: ScaleOnTap(
        onTap: () => context.push('/chat', extra: {
          'shopId': session.shopId,
          'shopName': name,
          'shopLogo': logo,
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkScaffold : AppColors.background,
            border: Border(
              bottom: BorderSide(
                color: AppColors.border.withValues(alpha: 0.5),
                width: 0.7,
              ),
            ),
          ),
          child: Row(
            children: [
              // Avatar
              _ShopAvatar(logo: logo, name: name),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: session.unread ? FontWeight.w700 : FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      session.lastMessageText.isNotEmpty
                          ? session.lastMessageText
                          : 'Say hello 👋',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: session.unread
                            ? (isDark ? Colors.white : AppColors.textPrimary)
                            : AppColors.textHint,
                        fontWeight:
                            session.unread ? FontWeight.w500 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Trailing
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (time.isNotEmpty)
                    Text(
                      time,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: session.unread ? Colors.white : AppColors.textHint,
                        fontWeight: session.unread ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  if (session.unread) ...[
                    const SizedBox(height: 5),
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    if (dt.millisecondsSinceEpoch == 0) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return DateFormat('hh:mm a').format(dt);
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return DateFormat('EEEE').format(dt);
    return DateFormat('dd/MM/yy').format(dt);
  }
}

class _ShopAvatar extends StatelessWidget {
  final String logo;
  final String name;
  const _ShopAvatar({required this.logo, required this.name});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? AppColors.darkElevated : AppColors.surfaceElevated,
      ),
      child: ClipOval(
        child: logo.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: logo,
                fit: BoxFit.cover,
                cacheManager: AppCacheManager(),
                placeholder: (_, _) => Shimmer.fromColors(
                  baseColor: AppColors.border,
                  highlightColor: AppColors.surfaceElevated,
                  child: Container(color: Colors.white),
                ),
                errorWidget: (_, _, _) => _Fallback(name: name),
              )
            : _Fallback(name: name),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  final String name;
  const _Fallback({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.1),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'S',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── States ────────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 36,
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No conversations yet',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a chat from any shop page to talk directly with local vendors.',
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textHint),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Could not load chats',
        style: GoogleFonts.poppins(color: AppColors.error, fontSize: 14),
      ),
    );
  }
}

