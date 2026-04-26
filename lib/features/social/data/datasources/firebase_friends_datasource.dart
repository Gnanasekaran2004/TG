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
import '../../../notifications/data/datasources/firebase_notification_datasource.dart';
import '../../../../injection_container.dart' as di;

/// Status constants
enum FollowStatus { none, pending, following }

class FirebaseFriendsDataSource {
  final FirebaseFirestore _db;

  FirebaseFriendsDataSource(this._db);

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── /follows/{targetUid}/followers/{followerUid} ───────────────────────────

  /// Send a follow request (status = pending)
  Future<void> sendFollowRequest(String targetUid) async {
    await _db
        .collection('follows')
        .doc(targetUid)
        .collection('followers')
        .doc(_currentUid)
        .set({'status': 'pending', 'createdAt': FieldValue.serverTimestamp()});
  }

  /// Accept an incoming follow request from [requesterUid]
  /// Also creates a reverse "pending" to suggest following back (optional).
  Future<void> acceptFollowRequest(String requesterUid) async {
    final batch = _db.batch();

    // Mark the incoming request as accepted
    batch.set(
      _db.collection('follows').doc(_currentUid).collection('followers').doc(requesterUid),
      {'status': 'accepted', 'createdAt': FieldValue.serverTimestamp()},
    );

    // Update followerCount on current user, followingCount on requester
    batch.update(_db.collection('users').doc(_currentUid), {
      'followersCount': FieldValue.increment(1),
    });
    batch.update(_db.collection('users').doc(requesterUid), {
      'followingCount': FieldValue.increment(1),
    });

    await batch.commit();
  }

  /// Reject / cancel a follow request
  Future<void> rejectFollowRequest(String requesterUid) async {
    await _db
        .collection('follows')
        .doc(_currentUid)
        .collection('followers')
        .doc(requesterUid)
        .delete();
  }

  /// Unfollow (current user un-follows [targetUid])
  Future<void> unfollowUser(String targetUid) async {
    final batch = _db.batch();

    // Remove current user from target's followers
    batch.delete(
      _db.collection('follows').doc(targetUid).collection('followers').doc(_currentUid),
    );

    // Update counts
    batch.update(_db.collection('users').doc(targetUid), {
      'followersCount': FieldValue.increment(-1),
    });
    batch.update(_db.collection('users').doc(_currentUid), {
      'followingCount': FieldValue.increment(-1),
    });

    await batch.commit();
  }

  /// Check follow status of current user toward [targetUid]
  Future<FollowStatus> getFollowStatus(String targetUid) async {
    if (_currentUid.isEmpty) return FollowStatus.none;
    final doc = await _db
        .collection('follows')
        .doc(targetUid)
        .collection('followers')
        .doc(_currentUid)
        .get();
    if (!doc.exists) return FollowStatus.none;
    final status = doc.data()?['status'];
    if (status == 'accepted') return FollowStatus.following;
    if (status == 'pending') return FollowStatus.pending;
    return FollowStatus.none;
  }

  /// Stream of accepted followers of [uid]
  Stream<QuerySnapshot> streamFollowers(String uid) {
    return _db
        .collection('follows')
        .doc(uid)
        .collection('followers')
        .where('status', isEqualTo: 'accepted')
        .snapshots();
  }

  /// Stream of pending incoming follow requests for [uid]
  Stream<QuerySnapshot> streamFollowRequests(String uid) {
    return _db
        .collection('follows')
        .doc(uid)
        .collection('followers')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  /// Stream of users that [uid] is following
  Stream<QuerySnapshot> streamFollowing(String uid) {
    return _db
        .collectionGroup('followers')
        .where(FieldPath.documentId, isEqualTo: uid)
        .where('status', isEqualTo: 'accepted')
        .snapshots();
  }

  /// Gets the list of accepted follower UIDs for [uid]
  Future<List<String>> getFollowerIds(String uid) async {
    final snap = await _db
        .collection('follows')
        .doc(uid)
        .collection('followers')
        .where('status', isEqualTo: 'accepted')
        .get();
    return snap.docs.map((d) => d.id).toList();
  }

  /// Gets the list of UIDs that [uid] follows — by scanning all /follows docs
  Future<List<String>> getFollowingIds(String uid) async {
    // We track this by storing a /follows/{uid}/following/{targetUid} mirror
    final snap = await _db
        .collection('follows')
        .doc(uid)
        .collection('following')
        .where('status', isEqualTo: 'accepted')
        .get();
    return snap.docs.map((d) => d.id).toList();
  }

  // ── /follows/{uid}/following/{targetUid} mirror ────────────────────────────
  // When current user follows someone, we ALSO write to our own /following subcollection
  // so we can query "who do I follow?" cheaply.

  /// Follow someone — writes to target's /followers AND our own /following.
  /// Also sends an in-app notification to the target user.
  Future<void> followUser(String targetUid) async {
    if (_currentUid.isEmpty) return;

    final batch = _db.batch();

    // Write pending doc to target's /followers subcollection
    batch.set(
      _db.collection('follows').doc(targetUid).collection('followers').doc(_currentUid),
      {'status': 'pending', 'createdAt': FieldValue.serverTimestamp()},
    );

    // Write pending doc to my /following mirror
    batch.set(
      _db.collection('follows').doc(_currentUid).collection('following').doc(targetUid),
      {'status': 'pending', 'createdAt': FieldValue.serverTimestamp()},
    );

    await batch.commit();

    // ── Fetch sender name for notification ──
    try {
      final senderDoc = await _db.collection('users').doc(_currentUid).get();
      final senderName = senderDoc.data()?['name']?.toString() ?? 'Someone';

      // Send in-app notification to target user
      await di.sl<FirebaseNotificationDataSource>().sendNotification(
        recipientId: targetUid,
        title: '👤 New Follow Request',
        body: '$senderName wants to follow you.',
        type: 'friend',
        extra: {'senderId': _currentUid},
      );
    } catch (_) {
      // Notification failure should never break the follow action
    }
  }

  /// Full unfollow — cleans both sides and decrements counts
  Future<void> unfollowUserFull(String targetUid) async {
    if (_currentUid.isEmpty) return;

    // ── Read status BEFORE deleting (doc won't exist after batch.commit) ──
    final doc = await _db
        .collection('follows')
        .doc(targetUid)
        .collection('followers')
        .doc(_currentUid)
        .get();
    final wasAccepted = doc.data()?['status'] == 'accepted';

    // ── Phase 1: Delete both follow docs atomically ────────────────────────
    final batch = _db.batch();
    batch.delete(
      _db.collection('follows').doc(targetUid).collection('followers').doc(_currentUid),
    );
    batch.delete(
      _db.collection('follows').doc(_currentUid).collection('following').doc(targetUid),
    );
    await batch.commit();

    // ── Phase 2: Decrement counts only if the follow was accepted ──────────
    if (wasAccepted) {
      await Future.wait([
        _db.collection('users').doc(targetUid).set(
          {'followersCount': FieldValue.increment(-1)},
          SetOptions(merge: true),
        ),
        _db.collection('users').doc(_currentUid).set(
          {'followingCount': FieldValue.increment(-1)},
          SetOptions(merge: true),
        ),
      ]);
    }
  }


  /// Accept request — marks both follower + following as accepted,
  /// updates follower/following counts, and notifies the requester.
  Future<void> acceptRequest(String requesterUid) async {
    if (_currentUid.isEmpty) return;

    // ── Phase 1: Atomically update the follow status docs ──────────────────
    final batch = _db.batch();

    // 1a. Mark the incoming follower doc as accepted (doc already exists as 'pending')
    batch.update(
      _db.collection('follows').doc(_currentUid).collection('followers').doc(requesterUid),
      {'status': 'accepted'},
    );

    // 1b. Create/update the requester's /following mirror to accepted
    batch.set(
      _db.collection('follows').doc(requesterUid).collection('following').doc(_currentUid),
      {'status': 'accepted', 'acceptedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );

    await batch.commit();

    // ── Phase 2: Update counters separately with set+merge ─────────────────
    // Using set+merge so fields are created if they don't exist yet.
    // The Firestore rules allow cross-user updates of followersCount/followingCount.
    await Future.wait([
      _db.collection('users').doc(_currentUid).set(
        {'followersCount': FieldValue.increment(1)},
        SetOptions(merge: true),
      ),
      _db.collection('users').doc(requesterUid).set(
        {'followingCount': FieldValue.increment(1)},
        SetOptions(merge: true),
      ),
    ]);

    // ── Phase 3: Notify the requester ──────────────────────────────────────
    try {
      final myDoc = await _db.collection('users').doc(_currentUid).get();
      final myName = myDoc.data()?['name']?.toString() ?? 'Someone';

      await di.sl<FirebaseNotificationDataSource>().sendNotification(
        recipientId: requesterUid,
        title: '✅ Follow Request Accepted',
        body: '$myName accepted your follow request.',
        type: 'friend',
        extra: {'senderId': _currentUid},
      );
    } catch (_) {}
  }


  /// Get follow status: none / pending / following
  Future<FollowStatus> followStatus(String targetUid) async {
    if (_currentUid.isEmpty) return FollowStatus.none;
    final doc = await _db
        .collection('follows')
        .doc(targetUid)
        .collection('followers')
        .doc(_currentUid)
        .get();
    if (!doc.exists) return FollowStatus.none;
    return doc.data()?['status'] == 'accepted'
        ? FollowStatus.following
        : FollowStatus.pending;
  }

  /// Get friend IDs (users who both follow each other = accepted in both directions)
  Future<List<String>> getFriendIds() async {
    if (_currentUid.isEmpty) return [];

    // Who follows me (accepted)
    final followers = await getFollowerIds(_currentUid);

    // Who I follow (accepted) — from my /following subcollection
    final following = await getFollowingIds(_currentUid);

    // Intersection = mutual friends
    final followingSet = following.toSet();
    return followers.where((id) => followingSet.contains(id)).toList();
  }

  /// Stream incoming pending requests for current user
  Stream<QuerySnapshot> streamMyPendingRequests() {
    if (_currentUid.isEmpty) return const Stream.empty();
    return _db
        .collection('follows')
        .doc(_currentUid)
        .collection('followers')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  /// Stream all users that current user follows (accepted)
  Stream<QuerySnapshot> streamMyFollowing() {
    if (_currentUid.isEmpty) return const Stream.empty();
    return _db
        .collection('follows')
        .doc(_currentUid)
        .collection('following')
        .where('status', isEqualTo: 'accepted')
        .snapshots();
  }

  /// Stream all accepted followers of current user
  Stream<QuerySnapshot> streamMyFollowers() {
    if (_currentUid.isEmpty) return const Stream.empty();
    return _db
        .collection('follows')
        .doc(_currentUid)
        .collection('followers')
        .where('status', isEqualTo: 'accepted')
        .snapshots();
  }
}
