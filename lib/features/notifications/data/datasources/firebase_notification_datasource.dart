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

class FirebaseNotificationDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirebaseNotificationDataSource(this._firestore, this._auth);

  String? get _uid => _auth.currentUser?.uid;

  // ── Read / Stream ──────────────────────────────────────────────────────────

  /// Stream real-time notifications for the current user.
  Stream<QuerySnapshot> streamNotifications() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: uid)
        .snapshots();
  }

  /// Stream count of UNREAD notifications (for badge).
  Stream<int> streamUnreadCount() {
    final uid = _uid;
    if (uid == null) return Stream.value(0);
    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  // ── Write ──────────────────────────────────────────────────────────────────

  /// Mark a single notification as read.
  Future<void> markAsRead(String notifId) async {
    await _firestore.collection('notifications').doc(notifId).update({'read': true});
  }

  /// Mark ALL notifications as read for the current user.
  Future<void> markAllAsRead() async {
    final uid = _uid;
    if (uid == null) return;
    final batch = _firestore.batch();
    final snap = await _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .get();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  /// Delete (dismiss) a notification.
  Future<void> deleteNotification(String notifId) async {
    await _firestore.collection('notifications').doc(notifId).delete();
  }

  /// Send an in-app notification to any user.
  /// [type] is one of: 'friend', 'trip', 'system'
  Future<void> sendNotification({
    required String recipientId,
    required String title,
    required String body,
    String type = 'system',
    Map<String, dynamic> extra = const {},
  }) async {
    await _firestore.collection('notifications').add({
      'recipientId': recipientId,
      'title': title,
      'body': body,
      'type': type,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
      ...extra,
    });
  }
}
