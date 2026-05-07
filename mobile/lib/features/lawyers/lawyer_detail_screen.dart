import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:jerry_app/core/network/api_client.dart';
import 'package:jerry_app/core/theme/app_colors.dart';
import 'package:jerry_app/features/call/video_call_screen.dart';
import 'package:jerry_app/features/chat/chat_provider.dart';
import 'package:jerry_app/features/chat/chat_thread_screen.dart';
import 'package:jerry_app/features/lawyers/lawyer_models.dart';
import 'package:jerry_app/shared/widgets/bento_card.dart';
import 'package:jerry_app/shared/widgets/rating_modal.dart';

class LawyerDetailScreen extends ConsumerStatefulWidget {
  const LawyerDetailScreen({super.key, required this.lawyer});

  static const routePath = '/lawyer-detail';

  final LawyerSummary lawyer;

  @override
  ConsumerState<LawyerDetailScreen> createState() => _LawyerDetailScreenState();
}

class _LawyerDetailScreenState extends ConsumerState<LawyerDetailScreen> {
  bool _loading = false;

  Future<void> _startChat() async {
    if (!mounted) return;
    final storage  = ref.read(tokenStorageProvider);
    final myId     = await storage.getUserId() ?? '';
    final threadId = ChatNotifier.computeThreadId(myId, widget.lawyer.id);

    ref.read(chatProvider.notifier).ensureThread(
      threadId: threadId,
      peerId:   widget.lawyer.id,
      peerRole: 'LAWYER',
      peerName: widget.lawyer.fullName,
    );

    if (!mounted) return;
    context.push(
      ChatThreadScreen.routePath,
      extra: ChatArgs(
        peerId:   widget.lawyer.id,
        peerName: widget.lawyer.fullName,
        peerRole: 'LAWYER',
      ),
    );
  }

  Future<void> _startVideo() async {
    setState(() => _loading = true);
    try {
      final api  = ref.read(apiClientProvider);
      final resp = await api.post('/call/initiate', data: {
        'lawyerId': widget.lawyer.id,
        'type':     'VIDEO',
      });

      final data           = resp['data'] as Map<String, dynamic>;
      final consultationId = data['consultationId'] as String;
      final channelName    = data['agoraChannelName'] as String? ?? '';
      final agoraToken     = data['agoraToken'] as String? ?? '';
      final uid            = (data['uid'] as num?)?.toInt() ?? 0;

      if (!mounted) return;
      await context.push(
        VideoCallScreen.routePath,
        extra: VideoCallArgs(
          consultationId: consultationId,
          channelId:      channelName,
          token:          agoraToken,
          uid:            uid,
        ),
      );

      if (!mounted) return;
      final result = await RatingModal.show(
        context,
        lawyerName:     widget.lawyer.fullName,
        consultationId: consultationId,
      );

      if (result != null && result.stars > 0 && mounted) {
        try {
          await api.post('/ratings/consultations/$consultationId', data: {
            'stars': result.stars,
            if (result.reviewText != null) 'reviewText': result.reviewText,
          });
        } catch (_) {}
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['message'] ?? e.message ?? 'Failed to start call';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$msg')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l  = widget.lawyer;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          BentoCard(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(24)),
                child: Icon(LucideIcons.user, color: AppColors.secondary, size: 36),
              ),
              const SizedBox(height: 16),
              Text(l.fullName, style: tt.headlineMedium),
              const SizedBox(height: 4),
              Text(
                '${l.city ?? ''}${l.state != null ? ', ${l.state}' : ''}',
                style: tt.bodyMedium?.copyWith(color: AppColors.secondary),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: l.isOnline
                      ? AppColors.onlineGreen.withValues(alpha: 0.1)
                      : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: l.isOnline ? AppColors.onlineGreen : AppColors.outline,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l.isOnline ? 'Online' : 'Offline',
                    style: tt.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: l.isOnline ? AppColors.onlineGreen : AppColors.outline,
                    ),
                  ),
                ]),
              ),
            ]),
          ),

          const SizedBox(height: 16),

          Row(children: [
            Expanded(child: BentoCard(
              color: AppColors.surfaceContainerLow,
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Icon(LucideIcons.star, size: 20, color: AppColors.primary),
                const SizedBox(height: 8),
                Text('${l.avgRating}', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                Text('${l.totalRatings} reviews', style: tt.labelSmall),
              ]),
            )),
            const SizedBox(width: 12),
            Expanded(child: BentoCard(
              color: AppColors.surfaceContainerLow,
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Icon(LucideIcons.briefcase, size: 20, color: AppColors.primary),
                const SizedBox(height: 8),
                Text('${l.yearsExperience}', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                Text('Years exp', style: tt.labelSmall),
              ]),
            )),
          ]),

          const SizedBox(height: 16),

          BentoCard(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('LANGUAGES', style: tt.labelMedium?.copyWith(letterSpacing: 0.8, fontWeight: FontWeight.w600, color: AppColors.secondary)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: l.languagesSpoken.map((lang) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(9999)),
                  child: Text(lang, style: tt.labelMedium?.copyWith(color: AppColors.onSurface)),
                )).toList(),
              ),
            ]),
          ),

          const SizedBox(height: 24),

          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _startChat,
                icon: const Icon(LucideIcons.messageSquare, size: 16),
                label: const Text('Message'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.onSurface,
                  side: const BorderSide(color: AppColors.outlineVariant),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (!l.isOnline || _loading) ? null : _startVideo,
                icon: Icon(LucideIcons.video, size: 16),
                label: Text(_loading ? 'Starting…' : 'Video call'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ]),

          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
