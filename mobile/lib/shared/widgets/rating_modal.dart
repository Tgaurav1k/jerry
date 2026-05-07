import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:jerry_app/core/theme/app_colors.dart';

/// Post-call rating bottom sheet.
/// Usage:
///   final stars = await RatingModal.show(context, lawyerName: 'Meera Kapoor', consultationId: 'xxx');
class RatingResult {
  const RatingResult({required this.stars, this.reviewText});
  final int     stars;
  final String? reviewText;
}

class RatingModal extends StatefulWidget {
  const RatingModal({super.key, required this.lawyerName, required this.consultationId});

  final String lawyerName;
  final String consultationId;

  static Future<RatingResult?> show(BuildContext context, {required String lawyerName, required String consultationId}) {
    return showModalBottomSheet<RatingResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RatingModal(lawyerName: lawyerName, consultationId: consultationId),
    );
  }

  @override
  State<RatingModal> createState() => _RatingModalState();
}

class _RatingModalState extends State<RatingModal> {
  int _stars = 0;
  final _review = TextEditingController();

  @override
  void dispose() {
    _review.dispose();
    super.dispose();
  }

  bool get _requiresText => _stars > 0 && _stars < 4;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final canSubmit = _stars > 0 && (!_requiresText || _review.text.trim().isNotEmpty);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grabber
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.outlineVariant, borderRadius: BorderRadius.circular(99))),
            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How was your\nconsultation?',
                    style: GoogleFonts.libreBaskerville(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      color: AppColors.onSurface,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'with ${widget.lawyerName}',
                    style: tt.bodyMedium?.copyWith(color: AppColors.secondary),
                  ),

                  const SizedBox(height: 28),

                  // ── Star row ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final filled = i < _stars;
                      return GestureDetector(
                        onTap: () => setState(() => _stars = i + 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(6),
                          child: AnimatedScale(
                            scale: filled ? 1.15 : 1.0,
                            duration: const Duration(milliseconds: 150),
                            child: Icon(
                              filled ? Icons.star_rounded : Icons.star_outline_rounded,
                              size: 44,
                              color: filled ? AppColors.gold : AppColors.outlineVariant,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 8),

                  // ── Star label ──
                  Center(
                    child: Text(
                      _stars == 0 ? 'Tap to rate' : ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'][_stars],
                      style: tt.bodySmall?.copyWith(
                        color: _stars > 0 ? AppColors.onSurface : AppColors.outline,
                        fontWeight: _stars > 0 ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Review text ──
                  if (_stars > 0) ...[
                    TextField(
                      controller: _review,
                      maxLines: 3,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 14, color: AppColors.onSurface),
                      decoration: InputDecoration(
                        hintText: _requiresText
                            ? 'Help us understand what went wrong…'
                            : 'Share feedback (optional)',
                        hintStyle: const TextStyle(color: AppColors.outline, fontSize: 13),
                        filled: true,
                        fillColor: AppColors.surfaceContainerLow,
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outlineVariant)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outlineVariant)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.onSurface, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Buttons ──
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(null),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.secondary,
                            side: const BorderSide(color: AppColors.outlineVariant),
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Skip'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: canSubmit ? () => Navigator.of(context).pop(
                            RatingResult(
                              stars: _stars,
                              reviewText: _review.text.trim().isEmpty ? null : _review.text.trim(),
                            ),
                          ) : null,
                          icon: const Icon(LucideIcons.check, size: 16),
                          label: const Text('Submit'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
