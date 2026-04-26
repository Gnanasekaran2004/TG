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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/otp_verification_page.dart';
import '../../features/auth/presentation/pages/setup_profile_page.dart';
import '../../features/social/presentation/pages/main_shell_page.dart';
import '../../features/splash/presentation/pages/splash_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/splash',

    // ── Auth Redirect Guard ──────────────────────────────────────────────────
    redirect: (context, state) {
      final isLoggedIn  = FirebaseAuth.instance.currentUser != null;
      final currentPath = state.matchedLocation;

      // Always allow splash and OTP (unauthenticated during registration / forgot-pw)
      if (currentPath == '/splash') return null;
      if (currentPath == '/otp')    return null;

      // /setup-profile: only accessible when logged in
      if (currentPath == '/setup-profile') {
        return isLoggedIn ? null : '/login';
      }

      final authPaths = ['/login', '/register', '/forgot-password'];

      // Logged-in users should not see auth screens
      if (isLoggedIn && authPaths.contains(currentPath)) return '/home';

      // Unauthenticated users cannot access the app shell
      if (!isLoggedIn && currentPath.startsWith('/home')) return '/login';

      return null;
    },

    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/splash'),

      // ── Splash — checks profileComplete to decide where to go ──────────────
      GoRoute(
        path: '/splash',
        builder: (context, state) => SplashScreen(
          onDone: () async {
            final user = FirebaseAuth.instance.currentUser;
            if (user == null) { context.go('/login'); return; }

            // Check if user has completed profile setup
            try {
              final doc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get();
              final profileComplete = doc.data()?['profileComplete'] as bool? ?? false;
              if (context.mounted) {
                context.go(profileComplete ? '/home' : '/setup-profile');
              }
            } catch (_) {
              // If check fails, fall back to home (returning user graceful fallback)
              if (context.mounted) context.go('/home');
            }
          },
        ),
      ),

      GoRoute(path: '/login',           builder: (_, _) => const LoginPage()),
      GoRoute(path: '/forgot-password', builder: (_, _) => const ForgotPasswordPage()),
      GoRoute(path: '/register',        builder: (_, _) => const RegisterPage()),
      GoRoute(path: '/home',            builder: (_, _) => const MainShellPage()),

      // ── Setup Profile (new users only) ─────────────────────────────────────
      GoRoute(
        path: '/setup-profile',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return SetupProfilePage(
            prefilledName: extra['name'] as String? ?? '',
          );
        },
      ),

      // ── OTP Verification (registration & forgot-password) ──────────────────
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return OtpVerificationPage(
            email:    extra['email']    as String? ?? '',
            name:     extra['name']     as String? ?? '',
            password: extra['password'] as String? ?? '',
            mode:     extra['mode']     as String? ?? 'registration',
          );
        },
      ),
    ],
  );
}