import 'package:flutter/material.dart';
import 'package:jerry_app/core/theme/app_colors.dart';

/// Monolithic Editorial card — tonal layering, no borders, diffused shadow.
class BentoCard extends StatelessWidget {
  const BentoCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(16);
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surfaceContainerLowest,
        borderRadius: radius,
        // Ambient diffused shadow — no heavy drop-shadow.
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            offset: Offset(0, 12),
            blurRadius: 40,
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        splashColor: AppColors.surfaceContainerHigh.withValues(alpha: 0.4),
        highlightColor: AppColors.surfaceContainerHigh.withValues(alpha: 0.2),
        child: card,
      ),
    );
  }
}
