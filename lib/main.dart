// ============================================================================
// Trip-GUY — Travel Super-App
// Copyright (c) 2026 Gnanasekaran D. All Rights Reserved.
//
// PROPRIETARY AND CONFIDENTIAL
//
// This source code and all associated files are the exclusive intellectual
// property of Gnanasekaran D. Unauthorized copying, modification, distribution,
// or use of this file, via any medium, is strictly prohibited.
//
// Contact : sgnana238@gmail.com | +91 8248094569
// Country : India
// License : See LICENSE file at the project root for full terms.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/utils/router.dart';
import 'core/utils/base64_cache.dart';
import 'injection_container.dart' as di;
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/chat/data/datasources/firebase_chat_datasource.dart';
import 'features/social/presentation/pages/social_feed_page.dart' show clearFeedProfileCache;
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/services/firebase_messaging_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await di.init();
  di.sl<FirebaseMessagingService>().initialize().catchError((e) {
    debugPrint('FCM Init Error: $e');
  });
  
  runApp(const TripGuyApp());
}

class TripGuyApp extends StatefulWidget {
  const TripGuyApp({super.key});
  @override
  State<TripGuyApp> createState() => _TripGuyAppState();
}

class _TripGuyAppState extends State<TripGuyApp> with WidgetsBindingObserver {
  final _themeProvider = ThemeProvider();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setPresence(online: true);

    // Clear image cache and profile cache when user signs out.
    // This prevents stale data from leaking into the next user session.
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        Base64Cache.clear();
        clearFeedProfileCache();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setPresence(online: false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _setPresence(online: true);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _setPresence(online: false);
        break;
      case AppLifecycleState.hidden:
        _setPresence(online: false);
        break;
    }
  }

  void _setPresence({required bool online}) {
    try {
      final chatDs = di.sl<FirebaseChatDataSource>();
      if (online) {
        chatDs.setOnline();
      } else {
        chatDs.setOffline();
      }
    } catch (_) {

    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => di.sl<AuthBloc>()..add(AuthCheckRequested()),
        ),
      ],
      child: ThemeProviderWidget(
        notifier: _themeProvider,
        child: ListenableBuilder(
          listenable: _themeProvider,
          builder: (context, _) {
            return MaterialApp.router(
              title: 'Trip-GUY',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: _themeProvider.mode,
              routerConfig: AppRouter.router,
            );
          },
        ),
      ),
    );
  }
}