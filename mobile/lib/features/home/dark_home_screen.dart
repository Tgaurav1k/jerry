import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:jerry_app/core/theme/app_colors.dart';

/// Dark luxury Home tab — matches Stitch screenshots 1-6.
/// "Unrivaled Legal Authority" hero, Senior Partners, practice areas, quote.
class DarkHomeScreen extends StatelessWidget {
  const DarkHomeScreen({super.key, this.onConsult});

  final VoidCallback? onConsult;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.darkBg,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ══════════════════════════════════════
          // HERO SECTION
          // ══════════════════════════════════════
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF1A1A1A),
                  AppColors.darkBg,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Lady Justice statue
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/justice_statue.png',
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Label
                Text(
                  'THE CHAMBERS OF EXCELLENCE',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.0,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(height: 12),

                // Main heading
                Text(
                  'Unrivaled\nLegal\nAuthority',
                  style: GoogleFonts.libreBaskerville(
                    fontSize: 42,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 24),

                // Gold CTA button
                GestureDetector(
                  onTap: onConsult,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'CONSULT WITH JERRY',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: AppColors.darkBg,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Avatar stack
                Row(
                  children: [
                    ...List.generate(3, (i) => Align(
                      widthFactor: 0.7,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.darkCard,
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: Color.lerp(
                            const Color(0xFF3A3A3A),
                            const Color(0xFF555555),
                            i / 2,
                          ),
                          child: Icon(LucideIcons.user, size: 12, color: AppColors.darkTextMuted),
                        ),
                      ),
                    )),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.darkCard,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '+24',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkTextMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Gold separator line
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(height: 1, color: AppColors.gold.withValues(alpha: 0.3)),
          ),

          // ══════════════════════════════════════
          // SENIOR PARTNERS
          // ══════════════════════════════════════
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Senior Partners',
                    style: GoogleFonts.libreBaskerville(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onConsult,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'VIEW REGISTRY',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: AppColors.darkTextMuted,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(LucideIcons.arrowRight, size: 14, color: AppColors.darkTextMuted),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'The most distinguished minds in contemporary law.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.darkTextMuted, height: 1.4),
            ),
          ),

          const SizedBox(height: 16),

          // Arthur St. Claire card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _SeniorPartnerCard(
              name: 'Arthur St.\nClaire',
              badge: 'PREMIER PARTNER',
              description: 'Specializing in Global Corporate Litigation and Sovereign Asset Protection. With over three decades of precedent-setting victories.',
              stat1: '98.4%',
              stat1Label: 'WIN RATE',
              stat2: '450+',
              stat2Label: 'CASES FILED',
            ),
          ),

          const SizedBox(height: 16),

          // Eleanor Vance card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF333333)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Portrait with initials
                  Center(
                    child: Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF3A3530), Color(0xFF252220)],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'EV',
                          style: GoogleFonts.libreBaskerville(
                            fontSize: 48,
                            fontWeight: FontWeight.w700,
                            color: AppColors.gold.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Eleanor Vance',
                    style: GoogleFonts.libreBaskerville(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Intellectual Property & Digital Rights Vanguard.',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.darkTextMuted, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Divider(color: const Color(0xFF333333), height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        '\$1,200/hr',
                        style: GoogleFonts.libreBaskerville(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          color: AppColors.gold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF444444)),
                        ),
                        child: Icon(Icons.add, size: 16, color: AppColors.darkTextMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Gold separator line
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(height: 1, color: AppColors.gold.withValues(alpha: 0.3)),
          ),

          const SizedBox(height: 20),

          // ══════════════════════════════════════
          // PRACTICE AREAS
          // ══════════════════════════════════════
          ..._buildPracticeAreas(),

          const SizedBox(height: 20),

          // Gold separator line
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(height: 1, color: AppColors.gold.withValues(alpha: 0.3)),
          ),

          const SizedBox(height: 20),

          // ══════════════════════════════════════
          // LIBRARY IMAGE
          // ══════════════════════════════════════
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/justice_statue.png',
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                color: Colors.black.withValues(alpha: 0.3),
                colorBlendMode: BlendMode.darken,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // ══════════════════════════════════════
          // FOUNDER QUOTE
          // ══════════════════════════════════════
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '99',
                  style: GoogleFonts.libreBaskerville(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                    height: 0.8,
                  ),
                ),
                const SizedBox(height: 16),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.libreBaskerville(
                      fontSize: 22,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                      height: 1.4,
                    ),
                    children: [
                      const TextSpan(text: '"Law is not just about the rules. It is about the '),
                      TextSpan(
                        text: 'precision',
                        style: TextStyle(color: AppColors.gold),
                      ),
                      const TextSpan(text: ' of their execution and the '),
                      TextSpan(
                        text: 'weight',
                        style: TextStyle(color: AppColors.gold),
                      ),
                      const TextSpan(text: ' of the authority behind them."'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(width: 24, height: 1, color: AppColors.darkTextMuted),
                    const SizedBox(width: 12),
                    Text(
                      'JULIAN JERRY, FOUNDER',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: AppColors.darkTextMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bottom padding for nav
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  List<Widget> _buildPracticeAreas() {
    final areas = [
      ('LITIGATION', 'Supreme Court Experts', LucideIcons.scale),
      ('ADVISORY', 'Wealth Management', LucideIcons.fileText),
      ('DEFENSE', 'White Collar Defense', LucideIcons.shield),
    ];

    return areas.map((area) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(area.$3, size: 20, color: AppColors.gold),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    area.$1,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: AppColors.gold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    area.$2,
                    style: GoogleFonts.libreBaskerville(
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}

class _SeniorPartnerCard extends StatelessWidget {
  const _SeniorPartnerCard({
    required this.name,
    required this.badge,
    required this.description,
    required this.stat1,
    required this.stat1Label,
    required this.stat2,
    required this.stat2Label,
  });

  final String name, badge, description, stat1, stat1Label, stat2, stat2Label;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge
                Row(
                  children: [
                    Icon(LucideIcons.star, size: 12, color: AppColors.gold),
                    const SizedBox(width: 6),
                    Text(
                      badge,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Name + portrait area
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.libreBaskerville(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ),
                    // Portrait with initials
                    Container(
                      width: 80,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF3A3530), Color(0xFF252220)],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'AS',
                          style: GoogleFonts.libreBaskerville(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.gold.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Description
                Text(
                  description,
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.darkTextMuted, height: 1.5),
                ),
                const SizedBox(height: 16),
                // Stats
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stat1, style: GoogleFonts.libreBaskerville(fontSize: 24, fontStyle: FontStyle.italic, color: AppColors.gold)),
                        Text(stat1Label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1.0, color: AppColors.darkTextMuted)),
                      ],
                    ),
                    const SizedBox(width: 32),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stat2, style: GoogleFonts.libreBaskerville(fontSize: 24, fontStyle: FontStyle.italic, color: AppColors.gold)),
                        Text(stat2Label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1.0, color: AppColors.darkTextMuted)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Gold bottom line
          Container(height: 2, color: AppColors.gold),
        ],
      ),
    );
  }
}
