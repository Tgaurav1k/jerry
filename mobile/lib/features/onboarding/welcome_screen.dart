import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:jerry_app/features/auth/login_screen.dart';

/// Public marketing landing — first screen after splash. Matches product homepage copy.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  static const routePath = '/welcome';
  static const routeName = 'welcome';

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _black = Color(0xFF0A0A0A);
  static const _muted = Color(0xFF525252);
  static const _cardBg = Color(0xFFF7F7F8);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _goLogin({String? intent}) {
    if (intent == null) {
      context.go(LoginScreen.routePath);
    } else {
      context.go('${LoginScreen.routePath}?intent=$intent');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.interTextTheme(Theme.of(context).textTheme);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: _MarketingDrawer(
        onHome: () {
          Navigator.of(context).pop();
          _scroll.animateTo(
            0,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
          );
        },
        onSignIn: () {
          Navigator.of(context).pop();
          _goLogin();
        },
        onGetStartedClient: () {
          Navigator.of(context).pop();
          _goLogin(intent: 'client');
        },
        onJoinLawyer: () {
          Navigator.of(context).pop();
          _goLogin(intent: 'lawyer');
        },
      ),
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverToBoxAdapter(
            child: _HeroSection(
              textTheme: textTheme,
              onOpenMenu: () => _scaffoldKey.currentState?.openDrawer(),
              onLogIn: () => _goLogin(),
              onGetStarted: () => _goLogin(intent: 'client'),
              onLawyerCta: () => _goLogin(intent: 'lawyer'),
            ),
          ),
          SliverToBoxAdapter(
            child: ColoredBox(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FeatureCard(
                      bg: _cardBg,
                      icon: LucideIcons.scale,
                      title: 'Find the right specialist',
                      body:
                          'Filter by criminal, civil, family, property, tax — and ten more practice areas. Every lawyer is license-verified.',
                    ),
                    const SizedBox(height: 12),
                    _FeatureCard(
                      bg: _cardBg,
                      icon: LucideIcons.badgeCheck,
                      title: 'License-verified',
                      body: 'Every advocate is reviewed.',
                    ),
                    const SizedBox(height: 12),
                    _FeatureCard(
                      bg: _cardBg,
                      icon: LucideIcons.messageCircle,
                      title: 'Chat first',
                      body: 'Start with a quick text consult.',
                    ),
                    const SizedBox(height: 12),
                    _FeatureCard(
                      bg: _cardBg,
                      icon: LucideIcons.phone,
                      title: 'Voice when needed',
                      body: 'One tap to a private call.',
                    ),
                    const SizedBox(height: 12),
                    _FeatureCard(
                      bg: _cardBg,
                      icon: LucideIcons.video,
                      title: 'Video for clarity',
                      body: 'Face-to-face when it matters.',
                    ),
                    const SizedBox(height: 28),
                    _StatsRow(textTheme: textTheme),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E5E5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Are you a lawyer?',
                            style: textTheme.titleMedium?.copyWith(
                              color: _black,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Build a direct client book without marketing spend. Set your availability, take consultations from anywhere in India.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: _muted,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: _black,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              onPressed: () => _goLogin(intent: 'lawyer'),
                              child: const Text('Join as a lawyer'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: GestureDetector(
                        onLongPress: () => _goLogin(intent: 'admin'),
                        child: Text(
                          '© 2026 jerry · Calm legal help, on demand.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(color: const Color(0xFF9CA3AF)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.textTheme,
    required this.onOpenMenu,
    required this.onLogIn,
    required this.onGetStarted,
    required this.onLawyerCta,
  });

  final TextTheme textTheme;
  final VoidCallback onOpenMenu;
  final VoidCallback onLogIn;
  final VoidCallback onGetStarted;
  final VoidCallback onLawyerCta;

  static const _black = Color(0xFF0A0A0A);

  @override
  Widget build(BuildContext context) {
    const heroAsset = 'assets/images/hero_justice.png';

    // Use a Container with background + foreground layered via decoration,
    // and a Column for content so nothing ever overlaps.
    const gold = Color(0xFFC8A84E);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage(heroAsset),
          fit: BoxFit.cover,
          alignment: Alignment(0, -0.15),
        ),
      ),
      child: Container(
        // Dark gradient overlay
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.75),
              Colors.black.withValues(alpha: 0.55),
              Colors.black.withValues(alpha: 0.85),
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Nav bar ──
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: onOpenMenu,
                        child: const Icon(Icons.menu, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Icon(LucideIcons.scale, size: 18, color: gold),
                      const SizedBox(width: 6),
                      Text(
                        'jerry',
                        style: GoogleFonts.libreBaskerville(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                          color: gold,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: onLogIn,
                        child: Text(
                          'Log in',
                          style: textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: onGetStarted,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: gold,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('Get Started', style: GoogleFonts.inter(color: _black, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Badge ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: gold.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.shield, size: 12, color: gold),
                      const SizedBox(width: 8),
                      Text('VERIFIED AUTHORITY', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: gold)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Headline ──
                Text(
                  'The Law,\nSimplified.',
                  style: GoogleFonts.libreBaskerville(
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 16),

                // Gold divider
                Container(width: 40, height: 2, color: gold),
                const SizedBox(height: 16),

                // ── Description ──
                Text(
                  'Connect with verified Indian lawyers for chat, voice, and video consultations — on demand.',
                  style: textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.8), height: 1.5),
                ),
                const SizedBox(height: 20),

                // ── CTA buttons ──
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: gold,
                      foregroundColor: _black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    onPressed: onGetStarted,
                    child: const Text('Get started — free'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: gold.withValues(alpha: 0.5), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    onPressed: onLawyerCta,
                    child: const Text("I'm a lawyer"),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Trust row ──
                Row(
                  children: [
                    ...List.generate(3, (i) => Align(
                      widthFactor: 0.7,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFF333333),
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: Color.lerp(const Color(0xFF444444), const Color(0xFF555555), i / 2),
                          child: Icon(LucideIcons.user, size: 10, color: Colors.white54),
                        ),
                      ),
                    )),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('500+ Experts', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                        Text('AVAILABLE NOW', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1.0, color: gold)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoRow extends StatelessWidget {
  const _LogoRow({required this.textTheme, this.light = false});

  final TextTheme textTheme;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final fg = light ? Colors.white : const Color(0xFF0A0A0A);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: Color(0xFF0A0A0A),
            shape: BoxShape.circle,
          ),
          child: const Icon(LucideIcons.scale, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          'jerry',
          style: textTheme.titleLarge?.copyWith(
            color: fg,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.bg,
    required this.icon,
    required this.title,
    required this.body,
  });

  final Color bg;
  final IconData icon;
  final String title;
  final String body;

  static const _black = Color(0xFF0A0A0A);
  static const _muted = Color(0xFF525252);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFE8E8EA),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _black, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _black,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _muted,
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCell(
            textTheme: textTheme,
            value: '12+',
            label: 'Languages',
          ),
        ),
        Expanded(
          child: _StatCell(
            textTheme: textTheme,
            value: '10',
            label: 'Specialties',
          ),
        ),
        Expanded(
          child: _StatCell(
            textTheme: textTheme,
            value: '< 5 min',
            label: 'Avg. response',
          ),
        ),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.textTheme,
    required this.value,
    required this.label,
  });

  final TextTheme textTheme;
  final String value;
  final String label;

  static const _black = Color(0xFF0A0A0A);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: _black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(
            color: const Color(0xFF525252),
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _MarketingDrawer extends StatelessWidget {
  const _MarketingDrawer({
    required this.onHome,
    required this.onSignIn,
    required this.onGetStartedClient,
    required this.onJoinLawyer,
  });

  final VoidCallback onHome;
  final VoidCallback onSignIn;
  final VoidCallback onGetStartedClient;
  final VoidCallback onJoinLawyer;

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.interTextTheme(Theme.of(context).textTheme);

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
              child: Row(
                children: [
                  const _LogoRowLight(),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(LucideIcons.home),
              title: const Text('Home'),
              onTap: onHome,
            ),
            ListTile(
              leading: const Icon(LucideIcons.logIn),
              title: const Text('Log in'),
              onTap: onSignIn,
            ),
            ListTile(
              leading: const Icon(LucideIcons.sparkles),
              title: const Text('Get started — free'),
              subtitle: const Text('Create a client account'),
              onTap: onGetStartedClient,
            ),
            ListTile(
              leading: const Icon(LucideIcons.briefcase),
              title: const Text("I'm a lawyer"),
              subtitle: const Text('Join the advocate network'),
              onTap: onJoinLawyer,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(LucideIcons.info),
              title: const Text('About jerry'),
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('jerry — legal help on demand across India.')),
                );
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.helpCircle),
              title: const Text('Help & support'),
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Support: coming soon.')),
                );
              },
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                '© 2026 jerry',
                style: textTheme.bodySmall?.copyWith(color: const Color(0xFF9CA3AF)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoRowLight extends StatelessWidget {
  const _LogoRowLight();

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.interTextTheme(Theme.of(context).textTheme);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Color(0xFF0A0A0A),
            shape: BoxShape.circle,
          ),
          child: const Icon(LucideIcons.scale, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Text(
          'jerry',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}
