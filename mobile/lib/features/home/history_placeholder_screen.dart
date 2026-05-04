import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:jerry_app/core/network/api_client.dart';
import 'package:jerry_app/core/theme/app_colors.dart';
import 'package:jerry_app/shared/widgets/bento_card.dart';

class HistoryPlaceholderScreen extends ConsumerStatefulWidget {
  const HistoryPlaceholderScreen({super.key});

  @override
  ConsumerState<HistoryPlaceholderScreen> createState() => _HistoryPlaceholderScreenState();
}

class _HistoryPlaceholderScreenState extends ConsumerState<HistoryPlaceholderScreen> {
  int _selectedFilter = 0;
  static const _filters = ['All', 'Chat', 'Voice', 'Video'];

  List<Map<String, dynamic>> _all = [];
  bool _loading = true;
  String? _role;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _role ??= await ref.read(tokenStorageProvider).getRole();
      final resp = await ref.read(apiClientProvider).get('/consultations/my');
      final items = (resp['data']['items'] as List<dynamic>? ?? []);
      _all = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filtered {
    if (_selectedFilter == 0) return _all;
    const typeMap = ['', 'CHAT', 'VOICE', 'VIDEO'];
    final t = typeMap[_selectedFilter];
    return _all.where((c) => (c['type'] as String?) == t).toList();
  }

  Widget _buildEntry(Map<String, dynamic> item) {
    final isUser = _role != 'LAWYER';
    final peer = isUser
        ? (item['lawyer'] as Map<String, dynamic>? ?? {})
        : (item['user']   as Map<String, dynamic>? ?? {});
    final peerName = peer['fullName'] as String? ?? 'Unknown';

    final type = item['type'] as String? ?? 'VIDEO';
    String typeLabel, specialty;
    IconData typeIcon;
    switch (type) {
      case 'CHAT':
        typeLabel = 'CHAT SESSION'; typeIcon = LucideIcons.messageSquare;
        specialty = 'Chat Consultation';
      case 'VOICE':
        typeLabel = 'VOICE CALL'; typeIcon = LucideIcons.phone;
        specialty = 'Voice Consultation';
      default:
        typeLabel = 'VIDEO CALL'; typeIcon = LucideIcons.video;
        specialty = 'Video Consultation';
    }

    final startedAt = DateTime.tryParse(item['startedAt'] as String? ?? '');
    final endedAtRaw = item['endedAt'];
    final endedAt   = endedAtRaw != null ? DateTime.tryParse(endedAtRaw as String) : null;
    final date = startedAt != null
        ? DateFormat('MMMM d, yyyy').format(startedAt.toLocal())
        : 'Unknown date';
    String? duration;
    if (startedAt != null && endedAt != null) {
      final mins = endedAt.difference(startedAt).inMinutes;
      if (mins > 0) duration = '$mins mins';
    }

    final ratingData = item['rating'] as Map<String, dynamic>?;
    final rating      = (ratingData?['stars'] as num?)?.toDouble() ?? 0.0;
    final description = ratingData?['reviewText'] as String?;

    return _ConsultationEntry(
      name:              peerName,
      specialty:         specialty,
      type:              typeLabel,
      typeIcon:          typeIcon,
      date:              date,
      duration:          duration,
      rating:            rating,
      description:       description,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt       = Theme.of(context).textTheme;
    final filtered = _filtered;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          // ── Header ──
          Text(
            'Consultation\nHistory',
            style: GoogleFonts.libreBaskerville(
              fontSize: 32, fontWeight: FontWeight.w700,
              color: AppColors.onSurface, height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A comprehensive log of your legal advisory sessions. Review notes, ratings, and follow-up actions from past engagements.',
            style: tt.bodyMedium?.copyWith(color: AppColors.secondary, height: 1.5),
          ),
          const SizedBox(height: 16),

          // ── Filter chips ──
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final selected = i == _selectedFilter;
                return GestureDetector(
                  onTap: () => setState(() => _selectedFilter = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      border: selected ? null : Border.all(color: AppColors.outlineVariant),
                    ),
                    child: Text(
                      _filters[i],
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500,
                        color: selected ? Colors.white : AppColors.onSurface,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // ── Consultation list ──
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
            )
          else if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(children: [
                const Icon(LucideIcons.fileText, size: 48, color: AppColors.outline),
                const SizedBox(height: 12),
                Text(
                  'No consultations yet.',
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium?.copyWith(color: AppColors.secondary),
                ),
              ]),
            )
          else
            ...filtered.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildEntry(item),
            )),

          const SizedBox(height: 16),

          // ── Upcoming follow-up card (UI showcase) ──
          BentoCard(
            color: AppColors.surfaceContainerLow,
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(LucideIcons.scale, size: 28, color: AppColors.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    'UPCOMING FOLLOW-UP',
                    style: tt.labelSmall?.copyWith(letterSpacing: 0.8, color: AppColors.secondary),
                  ),
                  const SizedBox(height: 4),
                  Text('David Chen', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text('Family Law', style: tt.bodySmall?.copyWith(color: AppColors.secondary)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('NOV 02', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text('SCHEDULED', style: tt.labelSmall?.copyWith(color: AppColors.secondary, letterSpacing: 0.5)),
              ]),
              const SizedBox(width: 8),
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.onSurface, width: 1.5),
                ),
                child: Icon(LucideIcons.arrowRight, size: 16, color: AppColors.onSurface),
              ),
            ]),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _ConsultationEntry extends StatelessWidget {
  const _ConsultationEntry({
    required this.name,
    required this.specialty,
    required this.type,
    required this.typeIcon,
    required this.date,
    this.duration,
    required this.rating,
    this.showReviewButton = false,
    this.description,
  });

  final String   name;
  final String   specialty;
  final String   type;
  final IconData typeIcon;
  final String   date;
  final String?  duration;
  final double   rating;
  final bool     showReviewButton;
  final String?  description;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return BentoCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Type badge row
        Row(children: [
          Icon(typeIcon, size: 16, color: AppColors.secondary),
          const Spacer(),
          Text(
            type,
            style: tt.labelSmall?.copyWith(
              letterSpacing: 0.8, color: AppColors.secondary, fontWeight: FontWeight.w600,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        // Lawyer info
        Row(children: [
          CircleAvatar(
            radius: 22, backgroundColor: AppColors.surfaceContainerHigh,
            child: Icon(LucideIcons.user, size: 18, color: AppColors.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              Text(specialty, style: tt.bodySmall?.copyWith(color: AppColors.secondary)),
            ]),
          ),
        ]),
        if (description != null && description!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(description!, style: tt.bodySmall?.copyWith(color: AppColors.secondary, height: 1.4)),
        ],
        const SizedBox(height: 12),
        // Date + rating row
        Row(children: [
          Icon(LucideIcons.calendar, size: 12, color: AppColors.outline),
          const SizedBox(width: 4),
          Text(
            '$date${duration != null ? " · $duration" : ""}',
            style: tt.labelSmall?.copyWith(fontWeight: FontWeight.w600, color: AppColors.onSurface),
          ),
          const Spacer(),
          if (rating > 0)
            Row(mainAxisSize: MainAxisSize.min, children: [
              ...List.generate(5, (i) => Icon(
                Icons.star, size: 14,
                color: i < rating.round() ? AppColors.onSurface : AppColors.outlineVariant,
              )),
              const SizedBox(width: 4),
              Text('$rating', style: tt.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
            ]),
        ]),
        if (showReviewButton) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              child: Text(
                'REVIEW CONSULTATION NOTES',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}
