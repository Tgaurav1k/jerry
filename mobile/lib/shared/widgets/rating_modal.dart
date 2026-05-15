import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:jerry_app/core/theme/app_colors.dart';

/// Post-call rating bottom sheet.
///
/// The modal owns the submit lifecycle: it calls [onSubmit] with the result and
/// only closes once that future resolves successfully. If [onSubmit] throws, the
/// sheet stays open and shows the error so the user can retry.
///
/// Usage:
///   final submitted = await RatingModal.show(
///     context,
///     lawyerName: 'Meera Kapoor',
///     consultationId: 'xxx',
///     onSubmit: (r) => api.post('/ratings/consultations/$id', data: {...}),
///   );
class RatingResult {
  const RatingResult({required this.stars, this.reviewText});
  final int     stars;
  final String? reviewText;
}

typedef RatingSubmitCallback = Future<void> Function(RatingResult result);

class RatingModal extends StatefulWidget {
  const RatingModal({
    super.key,
    required this.lawyerName,
    required this.consultationId,
    required this.onSubmit,
  });

  final String lawyerName;
  final String consultationId;
  final RatingSubmitCallback onSubmit;

  /// Returns `true` if the user successfully submitted a rating, `false` if
  /// they dismissed (Skip / back / outside tap).
  static Future<bool> show(
    BuildContext context, {
    required String lawyerName,
    required String consultationId,
    required RatingSubmitCallback onSubmit,
  }) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RatingModal(
        lawyerName: lawyerName,
        consultationId: consultationId,
        onSubmit: onSubmit,
      ),
    );
    return ok ?? false;
  }

  @override
  State<RatingModal> createState() => _RatingModalState();
}

class _RatingModalState extends State<RatingModal> {
  static const int _reviewMaxLength = 1000;

  int _stars = 0;
  final _review = TextEditingController();
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _review.dispose();
    super.dispose();
  }

  // Backend rule: reviewText required for ratings < 4 stars.
  bool get _requiresText => _stars > 0 && _stars < 4;

  String _labelForStars(int s) {
    // Aligned with the "review required below 4" rule: 1-3 are negative-leaning.
    const labels = ['', 'Poor', 'Needs work', 'Okay', 'Very good', 'Excellent'];
    return labels[s];
  }

  Future<void> _handleSubmit() async {
    final canSubmit =
        _stars > 0 && (!_requiresText || _review.text.trim().isNotEmpty);
    if (!canSubmit || _submitting) return;

    final result = RatingResult(
      stars: _stars,
      reviewText: _review.text.trim().isEmpty ? null : _review.text.trim(),
    );

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      await widget.onSubmit(result);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorText = _humanizeError(e);
      });
    }
  }

  String _humanizeError(Object e) {
    final msg = e.toString();
    if (msg.contains('Already rated')) return 'You have already rated this consultation.';
    if (msg.contains('ended')) return 'Rating is only available after the call has ended.';
    if (msg.contains('SocketException') || msg.contains('Failed host lookup')) {
      return 'No internet connection. Please try again.';
    }
    return 'Could not submit rating. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final canSubmit = _stars > 0 &&
        (!_requiresText || _review.text.trim().isNotEmpty) &&
        !_submitting;

    return PopScope(
      canPop: !_submitting,
      child: Padding(
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
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
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

                    // Star row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) {
                        final filled = i < _stars;
                        return GestureDetector(
                          onTap: _submitting
                              ? null
                              : () => setState(() => _stars = i + 1),
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

                    // Star label
                    Center(
                      child: Text(
                        _stars == 0 ? 'Tap to rate' : _labelForStars(_stars),
                        style: tt.bodySmall?.copyWith(
                          color: _stars > 0 ? AppColors.onSurface : AppColors.outline,
                          fontWeight: _stars > 0 ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Review text
                    if (_stars > 0) ...[
                      TextField(
                        controller: _review,
                        enabled: !_submitting,
                        maxLines: 3,
                        maxLength: _reviewMaxLength,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(_reviewMaxLength),
                        ],
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
                          counterStyle: const TextStyle(color: AppColors.outline, fontSize: 11),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.outlineVariant),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.outlineVariant),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.onSurface, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    if (_errorText != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.errorContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _errorText!,
                          style: tt.bodySmall?.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else
                      const SizedBox(height: 12),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _submitting
                                ? null
                                : () => Navigator.of(context).pop(false),
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
                            onPressed: canSubmit ? _handleSubmit : null,
                            icon: _submitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.onPrimary),
                                    ),
                                  )
                                : const Icon(LucideIcons.check, size: 16),
                            label: Text(_submitting ? 'Submitting…' : 'Submit'),
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
      ),
    );
  }
}
