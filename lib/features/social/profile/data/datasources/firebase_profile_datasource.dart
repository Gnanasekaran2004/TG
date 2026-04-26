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
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseProfileDataSource {
  final FirebaseFirestore _firestore;

  FirebaseProfileDataSource(this._firestore);

  // 1. Create a new profile when a user registers.
  // Called by AuthBloc.SignUpRequested for legacy direct-signup flows.
  // New OTP-based registration uses FirebaseAuthDataSource.createAccountAfterOtp()
  // instead, which writes the user document directly.
  Future<void> createUserProfile({
    required String uid,
    required String email,
  }) async {
    final defaultName = email.split('@').first;
    // Use merge:true so we never overwrite fields set by createAccountAfterOtp()
    await _firestore.collection('users').doc(uid).set({
      'uid':             uid,
      'name':            defaultName,
      'email':           email,
      'bio':             '',
      'username':        '',
      'profileComplete': false, // Setup Profile page sets this true on completion
      'interests':       [],
      'followersCount':  0,
      'followingCount':  0,
      'createdAt':       FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // 2. Fetch a specific user's profile
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // 3. Update editable profile fields
  Future<void> updateUserProfile({
    required String uid,
    required Map<String, dynamic> updates,
  }) async {
    await _firestore.collection('users').doc(uid).update(updates);
  }

  // 4. Upload profile picture as base64 directly into Firestore (100% FREE - no Firebase Storage needed!)
  // The image is compressed to 300px wide at 70% quality before this is called,
  // keeping the base64 well under Firestore's 1MB limit per document.
  Future<void> uploadProfilePicture({
    required String uid,
    required Uint8List imageBytes,
  }) async {
    // Convert bytes to a base64 string
    final base64String = base64Encode(imageBytes);

    // Save it to Firestore — no Storage bucket required!
    await _firestore.collection('users').doc(uid).update({
      'photoBase64': base64String,
    });
  }

  // 5. Stream a user's profile for real-time updates
  Stream<Map<String, dynamic>?> streamUserProfile(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) => snap.data());
  }
}