import 'package:flutter/material.dart';
import 'app_locale_controller.dart';
import 'app_strings.dart';
import '../theme/app_colors.dart';

class LanguageScope extends InheritedNotifier<AppLocaleController> {
  const LanguageScope({
    super.key,
    required AppLocaleController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  static AppLocaleController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LanguageScope>();
    assert(scope != null, 'LanguageScope not found in widget tree.');
    return scope!.notifier!;
  }
}

extension L10nBuildContext on BuildContext {
  String tr(String key) {
    final c = LanguageScope.of(this);
    return AppStrings.translate(key, c.language);
  }

  bool get isArabic => LanguageScope.of(this).language == AppLanguage.arabic;
}

class LanguageMenuButton extends StatelessWidget {
  const LanguageMenuButton({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final controller = LanguageScope.of(context);
    final lang = controller.language;
    return PopupMenuButton<AppLanguage>(
      tooltip: context.tr('Language'),
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.language),
          if (!compact) ...[
            const SizedBox(width: 6),
            Text(
              lang == AppLanguage.arabic
                  ? context.tr('Arabic')
                  : context.tr('English'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
      onSelected: (value) => controller.setLanguage(value),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: AppLanguage.english,
          child: Text(context.tr('English')),
        ),
        PopupMenuItem(
          value: AppLanguage.arabic,
          child: Text(context.tr('Arabic')),
        ),
      ],
    );
  }
}

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({
    super.key,
    this.showContinue = false,
  });

  final bool showContinue;

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  bool _showUpdated = false;
  bool _hasExplicitSelection = false;

  Future<void> _selectLanguage(AppLanguage language) async {
    final controller = LanguageScope.of(context);
    if (_hasExplicitSelection && controller.language == language) return;
    await controller.setLanguage(language);
    if (!mounted) return;
    setState(() {
      _showUpdated = true;
      _hasExplicitSelection = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isStandalonePicker = !widget.showContinue;
    if (isStandalonePicker) {
      return const _CompactLanguageSelectionScreen();
    }

    final controller = LanguageScope.of(context);
    final language = controller.language;
    final showSelectedState = !widget.showContinue || _hasExplicitSelection;

    return Scaffold(
      appBar: widget.showContinue
          ? null
          : AppBar(
              title: Text(context.tr('Language')),
            ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.2,
            colors: [Color(0xFF4A1D74), Color(0xFF120A22)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              SizedBox(height: widget.showContinue ? 52 : 24),
              Center(
                child: SizedBox(
                  width: widget.showContinue ? 220 : 108,
                  height: widget.showContinue ? 170 : 108,
                  child: widget.showContinue
                      ? Image.asset('assets/images/logo.png', fit: BoxFit.contain)
                      : Container(
                          decoration: BoxDecoration(
                            color: const Color(0x2217D4FF),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: const Color(0x55E14BC7)),
                          ),
                          child: const Icon(
                            Icons.language_rounded,
                            size: 54,
                            color: Color(0xFF7FD9FF),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              if (widget.showContinue) ...[
                Text(
                  context.tr('Language'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('Choose language'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 26),
              ] else
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xCC24123E),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0x66E14BC7)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x332B9BFF),
                        blurRadius: 22,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.public,
                        color: Color(0xFF6DD6FF),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.tr('Choose language'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFFE14BC7),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              _LanguageOptionTile(
                label: context.tr('Arabic'),
                emoji: '🇸🇦',
                selected: showSelectedState && language == AppLanguage.arabic,
                onTap: () => _selectLanguage(AppLanguage.arabic),
              ),
              const SizedBox(height: 12),
              _LanguageOptionTile(
                label: context.tr('English'),
                emoji: '🇬🇧',
                selected: showSelectedState && language == AppLanguage.english,
                onTap: () => _selectLanguage(AppLanguage.english),
              ),
              if (_showUpdated) ...[
                const SizedBox(height: 26),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E1A25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF5BCB58),
                      width: 1.4,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Color(0xFF5BCB58),
                        size: 32,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          context.tr('Language updated successfully'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (widget.showContinue) ...[
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _hasExplicitSelection
                      ? () {
                          Navigator.pushReplacementNamed(context, '/app');
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.hotPink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: Text(context.tr('Continue')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactLanguageSelectionScreen extends StatefulWidget {
  const _CompactLanguageSelectionScreen();

  @override
  State<_CompactLanguageSelectionScreen> createState() =>
      _CompactLanguageSelectionScreenState();
}

class _CompactLanguageSelectionScreenState
    extends State<_CompactLanguageSelectionScreen> {
  bool _showUpdated = false;

  Future<void> _selectLanguage(AppLanguage language) async {
    final controller = LanguageScope.of(context);
    if (controller.language == language) return;
    await controller.setLanguage(language);
    if (!mounted) return;
    setState(() => _showUpdated = true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = LanguageScope.of(context);
    final language = controller.language;

    return Scaffold(
      backgroundColor: const Color(0xFF07121B),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
                Expanded(
                  child: Text(
                    context.tr('Language'),
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
            _CompactLanguageTile(
              label: context.tr('English'),
              emoji: '🇺🇸',
              selected: language == AppLanguage.english,
              onTap: () => _selectLanguage(AppLanguage.english),
            ),
            const SizedBox(height: 14),
            _CompactLanguageTile(
              label: context.tr('Arabic'),
              emoji: '🇸🇦',
              selected: language == AppLanguage.arabic,
              onTap: () => _selectLanguage(AppLanguage.arabic),
            ),
            if (_showUpdated) ...[
              const SizedBox(height: 26),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1A25),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF5BCB58),
                    width: 1.4,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: Color(0xFF5BCB58),
                      size: 32,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        context.tr('Language updated successfully'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LanguageOptionTile extends StatelessWidget {
  const _LanguageOptionTile({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: const Color(0xCC24123E),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? const Color(0xFFE14BC7)
                  : const Color(0x553E2A64),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFFE14BC7),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactLanguageTile extends StatelessWidget {
  const _CompactLanguageTile({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1A25),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFFEE4B82)
                  : const Color(0xFF263646),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected
                    ? const Color(0xFFEE4B82)
                    : const Color(0xFF506072),
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
