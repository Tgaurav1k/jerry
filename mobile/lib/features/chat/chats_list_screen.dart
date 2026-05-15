import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:jerry_app/core/theme/app_colors.dart';
import 'package:jerry_app/features/chat/chat_provider.dart';
import 'package:jerry_app/features/chat/chat_thread_screen.dart';

class ChatsListScreen extends ConsumerWidget {
  const ChatsListScreen({super.key, this.embedded = false});

  final bool embedded;

  static const routePath = '/chats';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt      = Theme.of(context).textTheme;
    final chat    = ref.watch(chatProvider);
    final threads = chat.threadList;

    final content = CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Messages',
                  style: GoogleFonts.libreBaskerville(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
              const SizedBox(height: 4),
              Text('LEGAL COUNCIL CORRESPONDENCE',
                  style: tt.labelSmall?.copyWith(letterSpacing: 1.2, color: AppColors.secondary)),
            ]),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Icon(LucideIcons.search, size: 18, color: AppColors.outline),
                const SizedBox(width: 10),
                Text('Search conversations...', style: tt.bodyMedium?.copyWith(color: AppColors.outline)),
              ]),
            ),
          ),
        ),

        if (threads.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(children: [
                const Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.outline),
                const SizedBox(height: 12),
                Text(
                  'No conversations yet.\nBrowse lawyers and start a chat.',
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium?.copyWith(color: AppColors.secondary, height: 1.5),
                ),
              ]),
            ),
          )
        else
          SliverList.separated(
            itemCount: threads.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 74),
            itemBuilder: (context, i) {
              final t       = threads[i];
              final last    = t.lastMessage!;
              final name    = t.peerName.isNotEmpty ? t.peerName : (t.peerRole == 'LAWYER' ? 'Lawyer' : 'Client');
              final preview = last.content;
              final timeStr = DateFormat('h:mm a').format(last.createdAt.toLocal());
              final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
              final unread  = chat.unreadByThreadId[t.threadId] ?? 0;

              return InkWell(
                onTap: () => context.push(
                  ChatThreadScreen.routePath,
                  extra: ChatArgs(peerId: t.peerId, peerName: name, peerRole: t.peerRole),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.surfaceContainerHigh,
                          child: Text(initial,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                        ),
                        if (t.peerIsOnline)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: AppColors.onlineGreen,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.surface, width: 2.5),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(
                            child: Text(name,
                                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text(timeStr, style: tt.labelSmall?.copyWith(color: AppColors.outline, letterSpacing: 0.3)),
                        ]),
                        const SizedBox(height: 4),
                        if (unread > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.gold,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  unread > 1 ? '$unread new messages' : 'New message',
                                  style: tt.labelSmall?.copyWith(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Text(preview,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: tt.bodySmall?.copyWith(color: AppColors.secondary)),
                      ]),
                    ),
                  ]),
                ),
              );
            },
          ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(LucideIcons.star, size: 20, color: Colors.white),
                const SizedBox(height: 10),
                Text('Priority Counsel', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 4),
                Text('Instant access to senior legal associates for premium members.',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.darkTextMuted, height: 1.4)),
              ]),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(children: [
              Expanded(child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('DRAFTS', style: tt.labelSmall?.copyWith(letterSpacing: 0.8, color: AppColors.secondary)),
                  const SizedBox(height: 6),
                  Text('04', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
                ]),
              )),
              const SizedBox(width: 10),
              Expanded(child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('ARCHIVED', style: tt.labelSmall?.copyWith(letterSpacing: 0.8, color: AppColors.secondary)),
                  const SizedBox(height: 6),
                  Icon(LucideIcons.archive, size: 28, color: AppColors.onSurface),
                ]),
              )),
            ]),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );

    if (embedded) return content;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Messages'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: content,
    );
  }
}
