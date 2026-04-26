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
import 'dart:math' show min;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseChatDataSource {
  final FirebaseFirestore _firestore;

  FirebaseChatDataSource(this._firestore);

  // ── Deterministic chat-room ID (same for both participants) ───────────────
  String _getChatRoomId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return ids.join('_');
  }

  // ── 1. Friends-only stream (mutual follows) ───────────────────────────────
  // Fixed: uses 2 batch queries instead of N sequential reads.
  // Following list changes stream → 1 followers query → in-memory intersection
  // → 1 users whereIn query. Maximum 3 Firestore round-trips regardless of
  // how many friends the user has.
  Stream<List<Map<String, dynamic>>> streamChatableFriends() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return Stream.value([]);

    return _firestore
        .collection('follows')
        .doc(uid)
        .collection('following')
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .asyncMap((followingSnap) async {
      // UIDs that I follow (accepted)
      final followingIds = followingSnap.docs.map((d) => d.id).toSet();
      if (followingIds.isEmpty) return <Map<String, dynamic>>[];

      // Batch-fetch MY followers in ONE query (not N individual reads)
      final followersSnap = await _firestore
          .collection('follows')
          .doc(uid)
          .collection('followers')
          .where('status', isEqualTo: 'accepted')
          .get();
      final followerIds = followersSnap.docs.map((d) => d.id).toSet();

      // Mutual = intersection (I follow them AND they follow me)
      final friendIds = followingIds.intersection(followerIds).toList();
      if (friendIds.isEmpty) return <Map<String, dynamic>>[];

      // Batch-fetch user profiles (Firestore whereIn, max 30 per chunk)
      final results = <Map<String, dynamic>>[];
      for (var i = 0; i < friendIds.length; i += 30) {
        final chunk = friendIds.sublist(i, min(i + 30, friendIds.length));
        final snap = await _firestore
            .collection('users')
            .where('uid', whereIn: chunk)
            .get();
        results.addAll(snap.docs.map((d) => d.data()));
      }
      return results;
    });
  }

  // ── 2. Get last message for a chat room (one-shot, not a live stream) ──────
  // Used in the chat list tiles to avoid having N live message listeners open.
  Future<Map<String, dynamic>?> getLastMessage(String otherUserId) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (myUid.isEmpty) return null;
    try {
      final chatRoomId = _getChatRoomId(myUid, otherUserId);
      final snap = await _firestore
          .collection('chats')
          .doc(chatRoomId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return snap.docs.first.data();
    } catch (_) {
      return null;
    }
  }

  // ── 3. Check mutual friendship ────────────────────────────────────────────
  Future<bool> isMutualFriend(String otherUid) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return false;
    try {
      final results = await Future.wait([
        _firestore.collection('follows').doc(otherUid)
            .collection('followers').doc(uid).get(),
        _firestore.collection('follows').doc(uid)
            .collection('followers').doc(otherUid).get(),
      ]);
      return results[0].data()?['status'] == 'accepted' &&
          results[1].data()?['status'] == 'accepted';
    } catch (_) {
      return false;
    }
  }

  // ── 4. Legacy all-users stream (kept for reference) ──────────────────────
  Stream<QuerySnapshot> streamAllUsers() {
    final currentUser = FirebaseAuth.instance.currentUser;
    return _firestore
        .collection('users')
        .where('uid', isNotEqualTo: currentUser?.uid)
        .snapshots();
  }

  // ── 5. Send a message ────────────────────────────────────────────────────
  Future<void> sendMessage(String receiverId, String message) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final chatRoomId = _getChatRoomId(currentUser.uid, receiverId);

    await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .add({
      'senderId':   currentUser.uid,
      'receiverId': receiverId,
      'message':    message,
      'timestamp':  FieldValue.serverTimestamp(),
      'read':       false,
    });
  }

  // ── 6. Mark messages from [senderId] as read ──────────────────────────────
  Future<void> markMessagesAsRead(String senderId) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    final chatRoomId = _getChatRoomId(myUid, senderId);
    final snap = await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .where('receiverId', isEqualTo: myUid)
        .where('read', isEqualTo: false)
        .get();

    if (snap.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  // ── 7. Stream live messages for the open chat screen ─────────────────────
  Stream<QuerySnapshot> streamMessages(String receiverId) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final chatRoomId = _getChatRoomId(currentUserId, receiverId);

    return _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // ── Presence ─────────────────────────────────────────────────────────────

  Future<void> setOnline() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).set(
      {'isOnline': true, 'lastOnline': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  Future<void> setOffline() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).set(
      {'isOnline': false, 'lastOnline': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  Stream<bool> streamIsOnline(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.data()?['isOnline'] == true);
  }

  Stream<Map<String, dynamic>?> streamUserProfile(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.data());
  }
}