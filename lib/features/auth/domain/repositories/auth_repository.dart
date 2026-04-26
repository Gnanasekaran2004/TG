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
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/errors/failures.dart';

abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  
  Future<Either<Failure, UserCredential>> signIn({
    required String email,
    required String password,
  });

  Future<Either<Failure, UserCredential>> signUp({
    required String email,
    required String password,
  });

  Future<Either<Failure, void>> signOut();

  User? get currentUser;
}
