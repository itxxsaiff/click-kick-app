import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'firebase_options.dart';
import 'config/stripe_config.dart';
import 'l10n/app_locale_controller.dart';
import 'l10n/app_strings.dart';
import 'l10n/l10n.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_router.dart';
import 'screens/public/public_feed_screen.dart';
import 'screens/user/contest_detail_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final localeController = AppLocaleController();
  await localeController.load();
  await AppStrings.load();

  if (!kIsWeb) {
    Stripe.publishableKey = StripeConfig.publishableKey;
    await Stripe.instance.applySettings();
  }

  if (!kIsWeb) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  runApp(VideoContestApp(localeController: localeController));
}

class VideoContestApp extends StatelessWidget {
  const VideoContestApp({super.key, required this.localeController});

  final AppLocaleController localeController;

  @override
  Widget build(BuildContext context) {
    return LanguageScope(
      controller: localeController,
      child: FutureBuilder(
        future: Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.darkTheme,
              home: Scaffold(
                body: Center(child: Text(context.tr('Firebase init failed.'))),
              ),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.darkTheme,
              home: const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: context.tr('Video Contest'),
            theme: AppTheme.darkTheme,
            locale: localeController.locale,
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              return child ?? const SizedBox.shrink();
            },
            home: const PublicFeedScreen(),
            onGenerateRoute: (settings) {
              final routeName = settings.name ?? '/';
              final uri = Uri.parse(routeName);
              if (uri.path == '/register') {
                return MaterialPageRoute(
                  builder: (_) => const RegisterScreen(),
                );
              }
              if (uri.path == '/login') {
                return MaterialPageRoute(builder: (_) => const LoginScreen());
              }
              if (uri.path == '/home') {
                return MaterialPageRoute(builder: (_) => const HomeRouter());
              }
              if (uri.path == '/contest-share') {
                final contestId = uri.queryParameters['contestId'] ?? '';
                final submissionId = uri.queryParameters['submissionId'];
                if (contestId.isNotEmpty) {
                  return MaterialPageRoute(
                    builder: (_) => ContestShareRouteScreen(
                      contestId: contestId,
                      focusSubmissionId: submissionId,
                    ),
                  );
                }
              }
              return MaterialPageRoute(
                builder: (_) => const PublicFeedScreen(),
              );
            },
          );
        },
      ),
    );
  }
}
