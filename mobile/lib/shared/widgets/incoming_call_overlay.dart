import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:jerry_app/core/theme/app_colors.dart';

/// Full-screen incoming call overlay (Design.md 6.16).
/// Shown over whatever screen the lawyer is on.
class IncomingCallOverlay extends StatefulWidget {
  const IncomingCallOverlay({
    super.key,
    required this.callerName,
    required this.callType,
    required this.onAccept,
    required this.onReject,
  });

  final String callerName;
  final String callType; // 'VIDEO' | 'VOICE'
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  State<IncomingCallOverlay> createState() => _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends State<IncomingCallOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;
  int _ringSeconds = 45;
  Timer? _ringTimer;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _ringTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _ringSeconds--);
      if (_ringSeconds <= 0) {
        t.cancel();
        widget.onReject();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ringTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.callType == 'VIDEO';

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Blurred dark backdrop ──
          Container(color: AppColors.darkBg.withValues(alpha: 0.94)),

          // ── Content ──
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),

                // ── Call type label ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isVideo ? LucideIcons.video : LucideIcons.phone, size: 14, color: AppColors.gold),
                      const SizedBox(width: 8),
                      Text(
                        isVideo ? 'Incoming video call…' : 'Incoming voice call…',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // ── Pulsing avatar ──
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, child) => Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer pulse ring
                      Container(
                        width: 160 * _pulseAnim.value,
                        height: 160 * _pulseAnim.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12 * (2 - _pulseAnim.value)), width: 2),
                        ),
                      ),
                      // Inner ring
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
                        ),
                      ),
                      // Avatar
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.darkCard,
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 2),
                        ),
                        child: const Icon(LucideIcons.user, size: 48, color: AppColors.darkTextMuted),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Caller name ──
                Text(
                  widget.callerName,
                  style: GoogleFonts.libreBaskerville(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Client',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.darkTextMuted),
                ),

                const SizedBox(height: 8),

                // ── Ring timeout countdown ──
                Text(
                  'Auto-declines in $_ringSeconds s',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.darkTextSecondary),
                ),

                const Spacer(),

                // ── Accept / Reject buttons ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Reject
                      _CallButton(
                        color: AppColors.error,
                        icon: LucideIcons.phoneOff,
                        label: 'Decline',
                        onTap: widget.onReject,
                      ),
                      // Accept
                      _CallButton(
                        color: const Color(0xFF22C55E),
                        icon: isVideo ? LucideIcons.video : LucideIcons.phone,
                        label: 'Accept',
                        onTap: widget.onAccept,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({required this.color, required this.icon, required this.label, required this.onTap});

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 10),
          Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }
}
