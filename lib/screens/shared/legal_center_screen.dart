import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';

class LegalCenterScreen extends StatelessWidget {
  const LegalCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = [
      (
        title: context.tr('Terms of Service'),
        body: context.tr('Terms & Conditions Content'),
      ),
      (
        title: context.tr('Privacy Policy'),
        body: context.tr('Privacy Policy Content'),
      ),
      (
        title: context.tr('Community Guidelines'),
        body: _communityGuidelinesBlocks(context),
      ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          const _SpaceBackground(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        context.tr('Legal & Privacy'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ...sections.map(
                  (section) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _LegalSectionTile(
                      title: section.title,
                      body: section.body,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _communityGuidelinesBlocks(BuildContext context) {
    return [
      context.tr('Be respectful, kind, and positive.'),
      context.tr('No harassment, hate speech, or bullying.'),
      context.tr('Do not post nudity, violence, or illegal content.'),
      context.tr(
        'Respect copyright and intellectual property.',
      ),
      context.tr(
        'Report inappropriate content to help keep our community safe.',
      ),
    ].join('\n\n');
  }
}

class _LegalSectionTile extends StatelessWidget {
  const _LegalSectionTile({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  Future<void> _openSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0B1520),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      body,
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 16,
                        height: 1.65,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openSheet(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1A25),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF263646)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFA9B2BF),
                size: 28,
              ),
            ],
          ),
        ),
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
