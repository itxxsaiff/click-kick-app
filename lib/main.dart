import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'l10n/app_locale_controller.dart';
import 'l10n/app_strings.dart';
import 'l10n/l10n.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/auth_action_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_router.dart';
import 'screens/public/public_feed_screen.dart';
import 'screens/user/contest_detail_screen.dart';

final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final localeController = AppLocaleController();
  await localeController.load();
  await AppStrings.load();

  if (!kIsWeb) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  runApp(VideoContestApp(localeController: localeController));
}

class VideoContestApp extends StatelessWidget {
  const VideoContestApp({super.key, required this.localeController});

  final AppLocaleController localeController;

  double _mobileTextScale(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (kIsWeb) return 1;
    if (width <= 430) return 0.92;
    if (width <= 600) return 0.96;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return LanguageScope(
      controller: localeController,
      child: FutureBuilder(
        future: Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ),
        builder: (context, snapshot) {
          final isArabic = localeController.language == AppLanguage.arabic;
          if (snapshot.hasError) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.darkTheme(useArabicFont: isArabic),
              home: Scaffold(
                body: Center(child: Text(context.tr('Firebase init failed.'))),
              ),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.darkTheme(useArabicFont: isArabic),
              home: const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: context.tr('Video Contest'),
            navigatorObservers: [appRouteObserver],
            theme: AppTheme.darkTheme(useArabicFont: isArabic),
            locale: localeController.locale,
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              final media = MediaQuery.of(context);
              return MediaQuery(
                data: media.copyWith(
                  textScaler: TextScaler.linear(_mobileTextScale(context)),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const LanguageSelectionScreen(showContinue: true),
            onGenerateRoute: (settings) {
              final routeName = settings.name ?? '/';
              final uri = Uri.parse(routeName);
              if (uri.path == '/app') {
                return MaterialPageRoute(builder: (_) => const HomeRouter());
              }
              if (uri.path == '/register') {
                final type = (uri.queryParameters['type'] ?? '').toLowerCase();
                if (type == 'user' || type == 'personal') {
                  return MaterialPageRoute(
                    builder: (_) => const RegisterScreen(),
                  );
                }
                if (type == 'business' || type == 'sponsor') {
                  return MaterialPageRoute(
                    builder: (_) => const RegisterScreen(isSponsor: true),
                  );
                }
                return MaterialPageRoute(
                  builder: (_) => const AccountTypeSelectionScreen(),
                );
              }
              if (uri.path == '/login') {
                return MaterialPageRoute(builder: (_) => const LoginScreen());
              }
              if (uri.path == '/forgot-password') {
                final email = uri.queryParameters['email'] ?? '';
                return MaterialPageRoute(
                  builder: (_) => ForgotPasswordScreen(initialEmail: email),
                );
              }
              if (uri.path == '/auth-action') {
                final mode = uri.queryParameters['mode'] ?? '';
                final oobCode = uri.queryParameters['oobCode'] ?? '';
                return MaterialPageRoute(
                  builder: (_) =>
                      AuthActionScreen(mode: mode, oobCode: oobCode),
                );
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
              return MaterialPageRoute(builder: (_) => const HomeRouter());
            },
          );
        },
      ),
    );
  }
}
