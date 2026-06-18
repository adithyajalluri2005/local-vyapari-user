import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/features/chat/providers/chat_provider.dart';
import 'package:local_vyapari_user/services/cache/app_cache_manager.dart';
import 'package:local_vyapari_user/shared/widgets/skeleton_card.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String shopId;
  final String shopName;
  final String shopLogo;

  const ChatScreen({
    super.key,
    required this.shopId,
    required this.shopName,
    this.shopLogo = '',
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final hasText = _ctrl.text.trim().isNotEmpty;
      if (hasText != _canSend) setState(() => _canSend = hasText);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatServiceProvider).markAsRead(widget.shopId);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollCtrl.hasClients) {
        if (animated) {
          _scrollCtrl.animateTo(
            0.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        } else {
          _scrollCtrl.jumpTo(0.0);
        }
      }
    });
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    ref.read(chatServiceProvider).sendMessage(
      shopId: widget.shopId,
      text: text,
      shopName: widget.shopName,
      shopLogo: widget.shopLogo,
    );
    _ctrl.clear();
    _scrollToBottom();
  }

  Future<void> _confirmDelete() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text('Delete conversation?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text(
          'This action cannot be undone.',
          style: GoogleFonts.poppins(fontSize: 13, color: isDark ? Colors.white70 : AppColors.textSecondary),
        ),
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
    if (ok == true) {
      await ref.read(chatServiceProvider).deleteChat(widget.shopId);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(chatMessagesProvider(widget.shopId), (previous, next) {
      if (next.hasValue && next.value!.isNotEmpty) {
        ref.read(chatServiceProvider).markAsRead(widget.shopId);
        final prevCount = previous?.value?.length ?? 0;
        if (next.value!.length > prevCount) {
          _scrollToBottom();
        }
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messagesAsync = ref.watch(chatMessagesProvider(widget.shopId));
    final currentUserId = ref.watch(userIdProvider);
    final isTablet = Responsive.isTablet(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkScaffold : AppColors.background,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            // Shop avatar
            Container(
              width: isTablet ? 40.0 : 34.0,
              height: isTablet ? 40.0 : 34.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
              child: ClipOval(
                child: widget.shopLogo.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: widget.shopLogo,
                        fit: BoxFit.cover,
                        cacheManager: AppCacheManager(),
                        errorWidget: (_, _, _) => _AvatarFallback(name: widget.shopName),
                      )
                    : _AvatarFallback(name: widget.shopName),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.shopName,
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 17.0 : 15.0,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error.withValues(alpha: 0.8),
            ),
            tooltip: 'Delete chat',
            onPressed: _confirmDelete,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border.withValues(alpha: 0.5)),
        ),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: messagesAsync.when(
              loading: () => const SkeletonChatMessages(),
              error: (err, _) => Center(
                child: Text('Could not load messages',
                    style: GoogleFonts.poppins(color: AppColors.error)),
              ),
              data: (messages) {
                if (messages.isEmpty) return _EmptyChat(shopName: widget.shopName);

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom(animated: false);
                });

                final hPad = Responsive.horizontalPadding(context);
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: ListView.builder(
                  controller: _scrollCtrl,
                  reverse: true,
                  padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[messages.length - 1 - index];
                    final isMe = msg.senderId == currentUserId;
                    final showDate = index == messages.length - 1 ||
                        !_sameDay(
                          messages[messages.length - 1 - index].timestamp,
                          messages[messages.length - 2 - index].timestamp,
                        );

                    return Column(
                      children: [
                        if (showDate) _DateDivider(date: msg.timestamp),
                        _MessageBubble(
                          text: msg.text,
                          time: msg.timestamp,
                          isMe: isMe,
                          isDark: isDark,
                        ),
                      ],
                    );
                  },
                ),
                  ),
                );
              },
            ),
          ),

          // Input bar
          _InputBar(
            ctrl: _ctrl,
            canSend: _canSend,
            onSend: _send,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.day == b.day && a.month == b.month && a.year == b.year;
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final String text;
  final DateTime time;
  final bool isMe;
  final bool isDark;

  const _MessageBubble({
    required this.text,
    required this.time,
    required this.isMe,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = Responsive.isTablet(context);
    final isSmall = Responsive.isSmallPhone(context);
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.72,
        ),
        child: Container(
          margin: EdgeInsets.only(
            bottom: 6,
            left: isMe ? (isTablet ? 72.0 : 48.0) : 0,
            right: isMe ? 0 : (isTablet ? 72.0 : 48.0),
          ),
          padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16.0 : 14.0,
              vertical: isTablet ? 12.0 : 10.0),
          decoration: BoxDecoration(
            color: isMe
                ? AppColors.primary
                : isDark
                    ? AppColors.darkElevated
                    : AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
              bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
            ),
            boxShadow: isMe
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 15.0 : (isSmall ? 13.0 : 14.0),
                  color: isMe
                      ? Colors.white
                      : isDark
                          ? Colors.white
                          : AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('hh:mm a').format(time),
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 11.0 : (isSmall ? 9.0 : 10.0),
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.6)
                      : AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Date divider ──────────────────────────────────────────────────────────────

class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    String label;
    if (diff == 0) {
      label = 'Today';
    } else if (diff == 1) {
      label = 'Yesterday';
    } else {
      label = DateFormat('dd MMM yyyy').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.border, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textHint,
              ),
            ),
          ),
          Expanded(child: Divider(color: AppColors.border, height: 1)),
        ],
      ),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool canSend;
  final VoidCallback onSend;
  final bool isDark;

  const _InputBar({
    required this.ctrl,
    required this.canSend,
    required this.onSend,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = Responsive.isTablet(context);
    final hPad = Responsive.horizontalPadding(context);
    final btnSize = isTablet ? 48.0 : 42.0;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
      ),
      padding: EdgeInsets.fromLTRB(
        hPad,
        10,
        hPad,
        MediaQuery.paddingOf(context).bottom + 10,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkElevated : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(
                      color: isDark ? Colors.white10 : AppColors.border,
                      width: 0.7,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: ctrl,
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 15.0 : 14.0,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type a message…',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: isTablet ? 15.0 : 14.0,
                        color: AppColors.textHint,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      isDense: true,
                    ),
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: btnSize,
                height: btnSize,
                decoration: BoxDecoration(
                  color: canSend ? AppColors.primary : AppColors.border,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: canSend ? onSend : null,
                  icon: Icon(Icons.send_rounded,
                      size: isTablet ? 20.0 : 18.0, color: Colors.white),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty chat ────────────────────────────────────────────────────────────────

class _EmptyChat extends StatelessWidget {
  final String shopName;
  const _EmptyChat({required this.shopName});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTablet = Responsive.isTablet(context);
    final isSmall = Responsive.isSmallPhone(context);
    final boxSize = isTablet ? 88.0 : (isSmall ? 60.0 : 72.0);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: boxSize,
              height: boxSize,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: isTablet ? 40.0 : (isSmall ? 26.0 : 32.0),
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Start the conversation',
              style: GoogleFonts.poppins(
                fontSize: isTablet ? 18.0 : (isSmall ? 14.0 : 16.0),
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Say hello to $shopName',
              style: GoogleFonts.poppins(
                  fontSize: isTablet ? 14.0 : (isSmall ? 12.0 : 13.0),
                  color: AppColors.textHint),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Avatar fallback ───────────────────────────────────────────────────────────

class _AvatarFallback extends StatelessWidget {
  final String name;
  const _AvatarFallback({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.1),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'S',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
