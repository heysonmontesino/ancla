import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'core/theme.dart';
import 'firebase_options.dart';
import 'features/onboarding/splash_screen.dart';
import 'features/sessions/controllers/session_playback_controller.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
    final FirebaseCrashlytics crashlytics = FirebaseCrashlytics.instance;
    final bool enableTelemetry = !kDebugMode;

    await analytics.setAnalyticsCollectionEnabled(enableTelemetry);
    await crashlytics.setCrashlyticsCollectionEnabled(enableTelemetry);

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      crashlytics.recordFlutterFatalError(details);
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };

    await AudioService.init(
      builder: () => SessionPlaybackController.instance,
      config: const AudioServiceConfig(
        androidNotificationChannelId:
            'com.heyson.paprespiracion.channel.audio_playback',
        androidNotificationChannelName: 'Reproduccion de audio',
        androidNotificationChannelDescription:
            'Controles de reproduccion para sesiones guiadas.',
        androidNotificationOngoing: true,
        androidResumeOnClick: true,
      ),
    );

    runApp(PapRespiracionApp(analytics: analytics));
    unawaited(analytics.logAppOpen());
  }, (Object error, StackTrace stackTrace) {
    FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: true);
  });
}

class PapRespiracionApp extends StatelessWidget {
  const PapRespiracionApp({super.key, required this.analytics});

  final FirebaseAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ancla',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      navigatorObservers: <NavigatorObserver>[
        FirebaseAnalyticsObserver(analytics: analytics),
      ],
      home: const SplashScreen(),
    );
  }
}
