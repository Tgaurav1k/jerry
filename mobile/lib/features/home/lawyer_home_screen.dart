import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:jerry_app/core/theme/app_colors.dart';
import 'package:jerry_app/shared/widgets/bento_card.dart';

/// Status panel for the lawyer dashboard tab (socket lives on [LawyerShellScreen]).
class LawyerDashboardTab extends StatelessWidget {
  const LawyerDashboardTab({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        BentoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.radio, size: 22, color: AppColors.sage500),
                  const SizedBox(width: 8),
                  Text(
                    'Live status',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                status,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.slate600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        BentoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.video, size: 22, color: AppColors.blue500),
                  const SizedBox(width: 8),
                  Text(
                    'Incoming calls',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Keep the app open while you are available. When a client starts a video consultation, you will see a full-screen prompt to accept or decline.',
                style: TextStyle(color: AppColors.slate500, height: 1.5, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
