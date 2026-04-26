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
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

class FirebaseAuthDataSource {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  FirebaseAuthDataSource(this._auth, this._firestore);

  // ── Existing Auth ──────────────────────────────────────────────────────────

  Stream<User?> get authStateChanges {
    try { return _auth.authStateChanges(); } catch (_) { return const Stream.empty(); }
  }

  Future<UserCredential> signIn({required String email, required String password}) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signUp({required String email, required String password}) async {
    return await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    try { await _auth.signOut(); } catch (_) {}
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  User? get currentUser {
    try { return _auth.currentUser; } catch (_) { return null; }
  }

  // ── Email OTP System ───────────────────────────────────────────────────────

  /// Generates a 6-digit OTP, stores it in Firestore with 5-min expiry,
  /// and sends it to [email] via the EmailJS REST API.
  Future<void> sendEmailOtp({
    required String email,
    required String name,
    required String serviceId,
    required String templateId,
    required String publicKey,
  }) async {
    // 1. Generate 6-digit OTP
    final otp = (100000 + Random.secure().nextInt(900000)).toString();
    final expiresAt = DateTime.now().add(const Duration(minutes: 5));

    // 2. Store in Firestore (keyed by email — one OTP per email at a time)
    await _firestore.collection('otp_verifications').doc(email).set({
      'otp': otp,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'attempts': 0,
      'used': false,
    });

    // 3. Send via EmailJS REST API
    final response = await http.post(
      Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
      headers: {'Content-Type': 'application/json', 'origin': 'http://localhost'},
      body: jsonEncode({
        'service_id': serviceId,
        'template_id': templateId,
        'user_id': publicKey,
        'template_params': {
          'user_name': name,
          'user_email': email,
          'otp_code': otp,
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send OTP. Please try again. (${response.body})');
    }
  }

  /// Verifies [enteredOtp] against the stored OTP for [email].
  /// Returns `true` if valid. Throws descriptive exceptions on failure.
  Future<bool> verifyEmailOtp({
    required String email,
    required String enteredOtp,
  }) async {
    final doc = await _firestore.collection('otp_verifications').doc(email).get();
    if (!doc.exists) throw Exception('OTP not found. Please request a new one.');

    final data = doc.data()!;
    final expiresAt   = (data['expiresAt'] as Timestamp).toDate();
    final storedOtp   = data['otp']      as String;
    final attempts    = data['attempts'] as int;
    final used        = data['used']     as bool;

    if (used)          throw Exception('This OTP has already been used.');
    if (attempts >= 3) throw Exception('Too many wrong attempts. Please request a new OTP.');
    if (DateTime.now().isAfter(expiresAt)) {
      await doc.reference.delete();
      throw Exception('OTP has expired. Please request a new one.');
    }

    if (storedOtp != enteredOtp.trim()) {
      await doc.reference.update({'attempts': attempts + 1});
      return false;
    }

    // Mark as used so it cannot be replayed
    await doc.reference.update({'used': true});
    return true;
  }

  /// Cleans up the OTP document after successful use.
  Future<void> deleteOtp(String email) async {
    try {
      await _firestore.collection('otp_verifications').doc(email).delete();
    } catch (_) {}
  }

  // ── Registration After OTP ─────────────────────────────────────────────────

  /// Creates the Firebase account and Firestore user profile in one step.
  /// Also writes to `registered_emails` so future duplicate-checks work.
  Future<UserCredential> createAccountAfterOtp({
    required String email,
    required String password,
    required String name,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.updateDisplayName(name);

    // Fetch FCM token now that the user is authenticated
    String fcmToken = '';
    try {
      fcmToken = await FirebaseMessaging.instance.getToken() ?? '';
    } catch (_) {}

    final uid = credential.user!.uid;

    // Write user profile document
    await _firestore.collection('users').doc(uid).set({
      'uid':            uid,
      'name':           name,
      'email':          email,
      'bio':            '',
      'photoBase64':    '',
      'isOnline':       true,
      'lastSeen':       FieldValue.serverTimestamp(),
      'fcmToken':       fcmToken,
      'followersCount': 0,
      'followingCount': 0,
    });

    // Write to the registered_emails index (public point-read collection).
    // This lets the register screen block duplicate emails BEFORE sending an OTP,
    // with no deprecated API and no auth requirement on the reader.
    try {
      await _firestore
          .collection('registered_emails')
          .doc(email.toLowerCase().trim())
          .set({
        'uid':       uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Non-fatal — the account already exists in Firebase Auth;
      // the OTP page will catch email-already-in-use as a safety net.
    }

    return credential;
  }

  // ── Email Duplicate Guard ────────────────────────────────────────────────────────

  /// Checks if [email] is already registered by doing a point-read on the
  /// `registered_emails` index.  The Firestore rule `allow get: if true`
  /// means unauthenticated callers can read — safe for the register screen.
  ///
  /// Fallback: returns `false` on any error (network, rules, etc.) so
  /// registration is never accidentally blocked.  The OTP page still catches
  /// [firebase_auth/email-already-in-use] as a secondary safety net.
  Future<bool> checkEmailExists(String email) async {
    try {
      final doc = await _firestore
          .collection('registered_emails')
          .doc(email.toLowerCase().trim())
          .get();
      return doc.exists;
    } catch (_) {
      return false; // network error or rules change — don't block registration
    }
  }

  // ── Password Reset After OTP ──────────────────────────────────────────────────

  /// After OTP verified, sends Firebase's own reset email  
  /// so the user can securely set a new password via the link.
  Future<void> sendResetAfterOtp(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
