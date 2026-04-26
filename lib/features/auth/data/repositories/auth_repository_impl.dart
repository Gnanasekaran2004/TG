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
import '../datasources/firebase_auth_datasource.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuthDataSource _dataSource;

  AuthRepositoryImpl(this._dataSource);

  @override
  Stream<User?> get authStateChanges => _dataSource.authStateChanges;

  @override
  Future<Either<Failure, UserCredential>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _dataSource.signIn(email: email, password: password);
      return Right(result);
    } on FirebaseAuthException catch (e) {
      return Left(ServerFailure(e.message ?? 'Authentication failed'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserCredential>> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _dataSource.signUp(email: email, password: password);
      return Right(result);
    } on FirebaseAuthException catch (e) {
      return Left(ServerFailure(e.message ?? 'Registration failed'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await _dataSource.signOut();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  User? get currentUser => _dataSource.currentUser;
}
