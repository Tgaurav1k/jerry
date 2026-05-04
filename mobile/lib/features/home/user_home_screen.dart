import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:jerry_app/core/network/api_client.dart';
import 'package:jerry_app/core/theme/app_colors.dart';
import 'package:jerry_app/features/lawyers/lawyer_detail_screen.dart';
import 'package:jerry_app/features/lawyers/lawyer_models.dart';
import 'package:jerry_app/shared/widgets/bento_card.dart';

/// Lawyer Directory — fetches approved lawyers from NestJS API.
class UserDiscoverTab extends ConsumerStatefulWidget {
  const UserDiscoverTab({super.key});

  @override
  ConsumerState<UserDiscoverTab> createState() => UserDiscoverTabState();
}

class UserDiscoverTabState extends ConsumerState<UserDiscoverTab> {
  List<LawyerSummary> _items = [];
  String? _error;
  bool _loading = true;
  int  _selectedFilter = 0;

  static const _filters = ['All', 'Criminal', 'Family', 'Tax', 'Corporate', 'Property'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void refresh() => _load();

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final resp = await ref.read(apiClientProvider).get('/lawyers');
      final list = (resp['data'] as List<dynamic>? ?? []);
      _items = list.map((e) => LawyerSummary.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: _loading
          ? ListView(children: const [
              SizedBox(height: 120),
              Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
            ])
          : _error != null
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(_error!, style: const TextStyle(color: AppColors.error)),
                    const SizedBox(height: 12),
                    Text('Could not load lawyers. Check your connection.', style: tt.bodyMedium),
                  ],
                )
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 48,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          itemCount: _filters.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final selected = i == _selectedFilter;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedFilter = i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                                decoration: BoxDecoration(
                                  color: selected ? AppColors.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
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
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 8)),

                    if (_items.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _FeaturedLawyerCard(
                            lawyer: _items.first,
                            onTap: () => context.push(LawyerDetailScreen.routePath, extra: _items.first),
                          ),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 8)),

                    if (_items.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: BentoCard(
                            padding: const EdgeInsets.all(20),
                            onTap: () => context.push(LawyerDetailScreen.routePath, extra: _items.first),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(
                                'Why ${_items.first.fullName.split(' ').last}?',
                                style: GoogleFonts.libreBaskerville(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.onSurface),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ranked #1 in federal cases for three consecutive years. Precision, authority, and unmatched track records.',
                                style: tt.bodyMedium?.copyWith(color: AppColors.secondary),
                              ),
                              const SizedBox(height: 12),
                              Row(children: [
                                Text(
                                  '${_items.first.avgRating > 4.5 ? "99%" : "${(_items.first.avgRating * 20).round()}%"}',
                                  style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.onSurface),
                                ),
                                const SizedBox(width: 8),
                                Text('SUCCESS\nRATE', style: tt.labelSmall?.copyWith(fontWeight: FontWeight.w700, height: 1.2, letterSpacing: 0.5)),
                              ]),
                            ]),
                          ),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 24)),

                    if (_items.length > 1)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(children: [
                            Text('Available Counsel', style: GoogleFonts.libreBaskerville(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                            const Spacer(),
                            Text('View All Experts', style: tt.labelMedium?.copyWith(color: AppColors.secondary)),
                          ]),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 12)),

                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList.separated(
                        itemCount: _items.length > 1 ? _items.length - 1 : 0,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final l = _items[i + 1];
                          return _LawyerListCard(lawyer: l, onTap: () => context.push(LawyerDetailScreen.routePath, extra: l));
                        },
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
    );
  }
}

class _FeaturedLawyerCard extends StatelessWidget {
  const _FeaturedLawyerCard({required this.lawyer, required this.onTap});
  final LawyerSummary lawyer;
  final VoidCallback  onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(color: AppColors.darkBg, borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          Container(
            height: 260, width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [AppColors.darkCard, AppColors.darkBg],
              ),
            ),
            child: Stack(children: [
              Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [AppColors.darkCardElevated, AppColors.darkSurface],
                    ),
                  ),
                  child: Icon(LucideIcons.user, color: AppColors.darkTextMuted, size: 48),
                ),
              ])),
              Positioned(
                bottom: 60, left: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Text('TOP RATED', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: Colors.white)),
                ),
              ),
              Positioned(
                bottom: 0, left: 20, right: 20,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(lawyer.fullName, style: GoogleFonts.libreBaskerville(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(
                    '${lawyer.city ?? 'Lead Partner'}, ${lawyer.state ?? 'Criminal Defense'}',
                    style: GoogleFonts.libreBaskerville(fontSize: 13, fontStyle: FontStyle.italic, color: AppColors.goldLight),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

class _LawyerListCard extends StatelessWidget {
  const _LawyerListCard({required this.lawyer, required this.onTap});
  final LawyerSummary lawyer;
  final VoidCallback  onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return BentoCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(14)),
            child: Icon(LucideIcons.user, color: AppColors.secondary, size: 24),
          ),
          if (lawyer.isOnline)
            Positioned(
              right: -1, bottom: -1,
              child: Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  color: AppColors.onlineGreen, shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ]),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(lawyer.fullName, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            '${lawyer.city ?? ''}${lawyer.state != null ? ' & ${lawyer.state}' : ''} Law',
            style: GoogleFonts.libreBaskerville(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.goldDim),
          ),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(LucideIcons.star, size: 12, color: AppColors.primary),
            const SizedBox(width: 4),
            Text('${lawyer.avgRating}', style: tt.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: AppColors.onSurface)),
          ]),
        ),
      ]),
    );
  }
}
