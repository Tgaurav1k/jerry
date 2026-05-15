import 'package:flutter/material.dart';
import 'package:jerry_app/core/theme/app_colors.dart';

/// Bottom nav matching Stitch design — rounded container, monochrome with
/// filled active indicator.
class FloatingGlassBottomNav extends StatelessWidget {
  const FloatingGlassBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    /// Per-tab unread/badge count (same order as [items]). Null = hide badges.
    this.tabBadgeCounts,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<FloatingNavItem> items;
  final List<int>? tabBadgeCounts;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18000000),
                offset: Offset(0, 4),
                blurRadius: 20,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final spec = items[i];
              final selected = i == currentIndex;
              final badge = tabBadgeCounts != null &&
                      i < tabBadgeCounts!.length
                  ? tabBadgeCounts![i]
                  : 0;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              spec.icon,
                              size: 20,
                              color: selected ? Colors.white : AppColors.outline,
                            ),
                            if (badge > 0)
                              Positioned(
                                right: -6,
                                top: -6,
                                child: Container(
                                  padding: badge > 1
                                      ? const EdgeInsets.symmetric(horizontal: 5, vertical: 2)
                                      : EdgeInsets.zero,
                                  constraints: BoxConstraints(
                                    minWidth: badge > 1 ? 16 : 8,
                                    minHeight: badge > 1 ? 14 : 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE53935),
                                    shape: badge > 1 ? BoxShape.rectangle : BoxShape.circle,
                                    borderRadius: badge > 1 ? BorderRadius.circular(8) : null,
                                    border: Border.all(color: Colors.white, width: 1.2),
                                  ),
                                  alignment: Alignment.center,
                                  child: badge > 1
                                      ? Text(
                                          badge > 9 ? '9+' : '$badge',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            height: 1,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        spec.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                          color: selected ? AppColors.primary : AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class FloatingNavItem {
  const FloatingNavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}
