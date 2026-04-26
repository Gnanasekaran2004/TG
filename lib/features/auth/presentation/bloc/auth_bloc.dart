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
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../injection_container.dart';
import '../../../social/profile/data/datasources/firebase_profile_datasource.dart';
import '../../domain/usecases/get_auth_state_usecase.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../../domain/usecases/sign_up_usecase.dart';
import '../../domain/usecases/sign_out_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import 'package:flutter/foundation.dart'; // Added for debugPrint

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SignInUseCase signInUseCase;
  final SignUpUseCase signUpUseCase;
  final SignOutUseCase signOutUseCase;
  final GetAuthStateUseCase getAuthStateUseCase;

  AuthBloc({
    required this.signInUseCase,
    required this.signUpUseCase,
    required this.signOutUseCase,
    required this.getAuthStateUseCase,
  }) : super(AuthInitial()) {
    on<AuthCheckRequested>((event, emit) async {
      emit(AuthLoading());
      await emit.forEach(
        getAuthStateUseCase(),
        onData: (user) {
          if (user != null) {
            return Authenticated(user: user);
          } else {
            return Unauthenticated();
          }
        },
      );
    });

    on<SignInRequested>((event, emit) async {
      emit(AuthLoading());
      final result = await signInUseCase(
        email: event.email,
        password: event.password,
      );
      result.fold(
        (failure) => emit(AuthError(message: failure.toString())),
        (_) => null, // State will be updated by the authStateChanges stream
      );
    });

    on<SignUpRequested>((event, emit) async {
      emit(AuthLoading());
      final result = await signUpUseCase(
        email: event.email,
        password: event.password,
      );

      await result.fold(
        (failure) async => emit(AuthError(message: failure.toString())),
        (userCredential) async {
          // ENTERPRISE ADDITION: Automatically generate their public Firestore Profile!
          try {
            if (userCredential.user != null) {
              final profileDataSource = sl<FirebaseProfileDataSource>();
              await profileDataSource.createUserProfile(
                uid: userCredential.user!.uid,
                email: event.email,
              );
            }
          } catch (e) {
            // Failsafes to ensure errors don't crash the signup flow
            debugPrint('Profile creation error: $e');
          }
          // State navigation will be handled automatically by authStateChanges stream
        },
      );
    });

    on<SignOutRequested>((event, emit) async {
      emit(AuthLoading());
      final result = await signOutUseCase();
      result.fold(
        (failure) => emit(AuthError(message: failure.toString())),
        (_) => null, // State will be updated by the authStateChanges stream
      );
    });
  }
}
