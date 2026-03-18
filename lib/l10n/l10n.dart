import 'package:flutter/material.dart';
import 'app_locale_controller.dart';
import 'app_strings.dart';

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
