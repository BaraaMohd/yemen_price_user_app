import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// --- Services & Settings ---
import 'core/services/offline_manager.dart';
import 'core/services/notification_service.dart';
import 'core/services/offline_map_service.dart';
import 'core/services/service_locator.dart';
import 'core/app_settings.dart';
import 'core/l10n/app_localizations.dart';
import 'core/app_scaffold.dart';
import 'core/config.dart';

// --- Screens ---
import 'features/products/screens/home_screen.dart';
import 'features/auth/onboarding_screen.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize core services
  await OfflineManager.init();
  await AppSettings.init();
  await NotificationService.init();
  await setupLocator();  // #7 – wire get_it service locator

  // 2. Sync pending offline reports in the background
  OfflineManager.syncAllPending().then((count) {
    if (count > 0) debugPrint("🔄 Background Sync: $count actions sent.");
  });
  OfflineManager.startConnectivitySync(onSynced: (count) {
    final messenger = appScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    final text = AppLocalizations.of(messenger.context)
        .tr("تمت مزامنة التحديثات المحفوظة");
    messenger.showSnackBar(
      SnackBar(content: Text(text)),
    );
  });
  OfflineMapService.startAutoDownload(
    AppConfig.offlineMapUrl,
    onDownloaded: (_) {
      final messenger = appScaffoldMessengerKey.currentState;
      if (messenger == null) return;
      final text = AppLocalizations.of(messenger.context)
          .tr("تم تنزيل خريطة أوفلاين");
      messenger.showSnackBar(SnackBar(content: Text(text)));
    },
  );

  runApp(const PriceMonitorApp());
}

class PriceMonitorApp extends StatelessWidget {
  const PriceMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppSettings.themeMode,
      builder: (context, themeMode, _) {
        return ValueListenableBuilder<Locale>(
          valueListenable: AppSettings.locale,
          builder: (context, locale, child) {
            return MaterialApp(
              // --- Localization ---
              onGenerateTitle: (context) =>
                  AppLocalizations.of(context).tr("نظام الأسعار اليمني"),
              debugShowCheckedModeBanner: false,
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              scaffoldMessengerKey: appScaffoldMessengerKey,

              // --- Theme Setup ---
              themeMode: themeMode,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,

              // --- #6 Onboarding: show onboarding on first run ---
              home: FutureBuilder<bool>(
                future: _checkOnboardingDone(),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox.shrink();
                  return snap.data! ? const HomeScreen() : const OnboardingScreen();
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _checkOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_done') ?? false;
  }
}
