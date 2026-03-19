import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';

class LegalCenterScreen extends StatelessWidget {
  const LegalCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = [
      (
        title: context.tr('Privacy Policy'),
        body: context.tr('Privacy Policy Content'),
        icon: Icons.privacy_tip_outlined,
      ),
      (
        title: context.tr('Terms & Conditions'),
        body: context.tr('Terms & Conditions Content'),
        icon: Icons.gavel_outlined,
      ),
      (
        title: context.tr('Community Guidelines'),
        body: context.tr('Community Guidelines Content'),
        icon: Icons.shield_outlined,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Legal & Privacy')),
        backgroundColor: AppColors.deepSpace,
      ),
      body: Stack(
        children: [
          const _SpaceBackground(),
          ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sections.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final section = sections[index];
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    leading: Icon(section.icon, color: AppColors.hotPink),
                    title: Text(
                      section.title,
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    iconColor: AppColors.hotPink,
                    collapsedIconColor: AppColors.textLight,
                    children: [
                      Text(
                        section.body,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SpaceBackground extends StatelessWidget {
  const _SpaceBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.nebula, AppColors.deepSpace],
        ),
      ),
    );
  }
}
