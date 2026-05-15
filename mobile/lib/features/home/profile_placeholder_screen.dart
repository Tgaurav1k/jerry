import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:jerry_app/core/auth/session_bridge.dart';
import 'package:jerry_app/core/network/api_client.dart';
import 'package:jerry_app/core/theme/app_colors.dart';
import 'package:jerry_app/features/onboarding/welcome_screen.dart';
import 'package:jerry_app/shared/widgets/bento_card.dart';

/// Profile page — matches Stitch design with case success stats,
/// case archives, featured content, and account management.
class ProfilePlaceholderScreen extends ConsumerStatefulWidget {
  const ProfilePlaceholderScreen({super.key});

  @override
  ConsumerState<ProfilePlaceholderScreen> createState() => _ProfilePlaceholderScreenState();
}

class _ProfilePlaceholderScreenState extends ConsumerState<ProfilePlaceholderScreen> {
  String? _role;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final role = await ref.read(tokenStorageProvider).getRole();
      if (mounted) setState(() => _role = role);
    });
  }

  Future<void> _signOut() async {
    final storage = ref.read(tokenStorageProvider);
    final refreshToken = await storage.getRefreshToken();
    try {
      await ref.read(apiClientProvider).post('/auth/logout', data: {'refreshToken': refreshToken});
    } catch (_) {}
    await storage.clear();
    SessionBridge.notifySessionCleared();
    if (!mounted) return;
    context.go(WelcomeScreen.routePath);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final isLawyer = _role == 'LAWYER';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        // ── Status label ──
        Text(
          isLawyer ? 'STATUS: ADVOCATE' : 'STATUS: CLIENT',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(height: 6),

        // ── Name ──
        Text(
          'Jerry A. Sterling',
          style: GoogleFonts.libreBaskerville(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Corporate Litigation  ·  Tax Strategy',
          style: tt.bodySmall?.copyWith(color: AppColors.secondary),
        ),
        const SizedBox(height: 8),
        Divider(color: AppColors.surfaceContainerHigh, height: 1),
        const SizedBox(height: 6),
        Text(
          "MEMBER SINCE '24",
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: AppColors.outline,
          ),
        ),

        const SizedBox(height: 24),

        // ── Case Success stat ──
        BentoCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CASE SUCCESS',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '94',
                    style: GoogleFonts.inter(
                      fontSize: 64,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                      height: 1.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '%',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: Icon(LucideIcons.trendingUp, size: 20, color: AppColors.onSurface),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.surfaceContainerHigh,
                    child: Icon(LucideIcons.user, size: 14, color: AppColors.secondary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Based on 47 resolved consultations across all practice areas.',
                      style: tt.bodySmall?.copyWith(color: AppColors.secondary, height: 1.4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Case Archives ──
        Row(
          children: [
            Text(
              'Case Archives',
              style: GoogleFonts.libreBaskerville(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.arrowUpDown, size: 12, color: AppColors.secondary),
                  const SizedBox(width: 4),
                  Text('Sort', style: tt.labelSmall?.copyWith(color: AppColors.secondary)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _CaseArchiveEntry(
          title: 'Sterling v. Nash (2024)',
          subtitle: 'Corporate dispute resolution',
          trailing: Icon(LucideIcons.chevronRight, size: 16, color: AppColors.outlineVariant),
        ),
        const SizedBox(height: 8),
        _CaseArchiveEntry(
          title: 'Robinson Dispute #402',
          subtitle: 'Property boundary mediation',
          trailing: Icon(LucideIcons.chevronRight, size: 16, color: AppColors.outlineVariant),
        ),

        const SizedBox(height: 24),

        // ── Featured content card ──
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The 2024\nJurisprudence Review',
                style: GoogleFonts.libreBaskerville(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _PillButton(label: 'DOWNLOAD', onTap: () {}),
                  const SizedBox(width: 8),
                  _PillButton(label: 'SHARE', onTap: () {}),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Account Management ──
        Text(
          'Account Management',
          style: GoogleFonts.libreBaskerville(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        _AccountTile(icon: LucideIcons.settings, label: 'Settings', onTap: () {}),
        _AccountTile(icon: LucideIcons.bell, label: 'Notifications', onTap: () {}),
        _AccountTile(icon: LucideIcons.lock, label: 'Privacy & Security', onTap: () {}),
        _AccountTile(icon: LucideIcons.helpCircle, label: 'Help & Support', onTap: () {}),

        const SizedBox(height: 16),

        // ── Log out ──
        OutlinedButton.icon(
          onPressed: _signOut,
          icon: Icon(LucideIcons.logOut, size: 18),
          label: const Text('LOG OUT'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.onSurface,
            side: const BorderSide(color: AppColors.outlineVariant),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8),
          ),
        ),

        // Padding for floating nav
        const SizedBox(height: 100),
      ],
    );
  }
}

class _CaseArchiveEntry extends StatelessWidget {
  const _CaseArchiveEntry({required this.title, required this.subtitle, required this.trailing});

  final String title, subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.secondary),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.secondary),
            const SizedBox(width: 14),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurface,
                  ),
            ),
            const Spacer(),
            Icon(LucideIcons.chevronRight, size: 16, color: AppColors.outlineVariant),
          ],
        ),
      ),
    );
  }
}
