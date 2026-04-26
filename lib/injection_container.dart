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
import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'features/auth/data/datasources/firebase_auth_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/get_auth_state_usecase.dart';
import 'features/auth/domain/usecases/sign_in_usecase.dart';
import 'features/auth/domain/usecases/sign_out_usecase.dart';
import 'features/auth/domain/usecases/sign_up_usecase.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/notifications/data/datasources/firebase_notification_datasource.dart';
import 'features/social/profile/data/datasources/firebase_profile_datasource.dart';
import 'features/social/data/datasources/firebase_trip_datasource.dart';
import 'features/social/data/datasources/firebase_friends_datasource.dart';
import 'features/chat/data/datasources/firebase_chat_datasource.dart';
import 'core/services/firebase_messaging_service.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // ── Firestore — configure offline persistence ─────────────────────────────
  // Explicit 100 MB cache: ensures navigation between pages and brief network
  // outages don't cause repeated round-trips to Firestore.
  // Default mobile cache is only 40 MB; this triples it for a data-heavy app.
  final fs = FirebaseFirestore.instance;
  try {
    fs.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 104857600, // 100 MB
    );
  } catch (_) {
    // Settings already initialised (hot-restart scenario) — ignore.
  }

  // ── External ─────────────────────────────────────────────────────────────
  sl.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);
  sl.registerLazySingleton<FirebaseFirestore>(() => fs);

  // ── Data Sources ─────────────────────────────────────────────────────────
  sl.registerLazySingleton(() => FirebaseAuthDataSource(sl(), sl()));
  sl.registerLazySingleton(() => FirebaseProfileDataSource(sl()));
  sl.registerLazySingleton(() => FirebaseTripDataSource(sl()));
  sl.registerLazySingleton(() => FirebaseNotificationDataSource(sl(), sl()));
  sl.registerLazySingleton(() => FirebaseChatDataSource(sl()));
  sl.registerLazySingleton(() => FirebaseFriendsDataSource(sl()));

  // ── Services ─────────────────────────────────────────────────────────────
  sl.registerLazySingleton(() => FirebaseMessagingService());

  // ── Repositories ─────────────────────────────────────────────────────────
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(sl()),
  );

  // ── Use Cases ────────────────────────────────────────────────────────────
  sl.registerLazySingleton(() => SignInUseCase(sl()));
  sl.registerLazySingleton(() => SignUpUseCase(sl()));
  sl.registerLazySingleton(() => SignOutUseCase(sl()));
  sl.registerLazySingleton(() => GetAuthStateUseCase(sl()));

  // ── BLoC ─────────────────────────────────────────────────────────────────
  // registerFactory is correct for BLoC — each BlocProvider gets a fresh
  // instance and proper dispose lifecycle management.
  sl.registerFactory(
    () => AuthBloc(
      signInUseCase:     sl(),
      signUpUseCase:     sl(),
      signOutUseCase:    sl(),
      getAuthStateUseCase: sl(),
    ),
  );
}
