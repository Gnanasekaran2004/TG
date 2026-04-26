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

class FirebaseTripDataSource {
  final FirebaseFirestore _firestore;

  FirebaseTripDataSource(this._firestore);

  // 1. Create a new trip
  Future<void> createTrip(Map<String, dynamic> tripData) async {
    try {
      await _firestore.collection('trips').add(tripData);
    } catch (e) {
      rethrow;
    }
  }

  // 2. Stream PUBLIC trips (main social feed)
  // Includes trips with visibility='public' OR no visibility field (legacy posts).
  // Client-side we filter out friends/private.
  // Limit 50 — shows the 50 most-recent posts; prevents loading the entire
  // collection as the database grows over time.
  Stream<QuerySnapshot> streamAllTrips() {
    try {
      return _firestore
          .collection('trips')
          .orderBy('createdAt', descending: true)
          .limit(50)              // ← PERF: paginate at 50 most-recent
          .snapshots();           // no includeMetadataChanges — feed doesn't
                                  // need to react to pending local writes
    } catch (e) {
      return const Stream.empty();
    }
  }


  // 2b. Stream FRIENDS trips from a given list of friend UIDs (max 30 per Firestore limit)
  Stream<QuerySnapshot> streamFriendsTrips(List<String> friendIds) {
    if (friendIds.isEmpty) return const Stream.empty();
    final ids = friendIds.take(30).toList();
    return _firestore
        .collection('trips')
        .where('ownerId', whereIn: ids)
        .where('visibility', isEqualTo: 'friends')
        .snapshots(); // sorted client-side in the feed
  }

  // 2c. Stream ALL of the current user's trips (any visibility) for My Trips page
  Stream<QuerySnapshot> streamMyAllTrips(String userId) {
    return _firestore
        .collection('trips')
        .where('ownerId', isEqualTo: userId)
        .snapshots(); // sorted client-side
  }

  // 2d. Stream only PRIVATE trips of the current user
  Stream<QuerySnapshot> streamPrivateTrips(String userId) {
    return _firestore
        .collection('trips')
        .where('ownerId', isEqualTo: userId)
        .where('visibility', isEqualTo: 'private')
        .snapshots(); // sorted client-side in PrivateFeedPage
  }

  // 3. Stream ONLY the logged-in user's trips
  Stream<QuerySnapshot> streamUserTrips(String userId) {
    try {
      return _firestore
          .collection('trips')
          .where('ownerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots(includeMetadataChanges: true);
    } catch (e) {
      return const Stream.empty();
    }
  }

  // 4. Add a diary entry to a specific trip
  Future<void> addDiaryEntry(String tripId, Map<String, dynamic> entryData) async {
    try {
      await _firestore
          .collection('trips')
          .doc(tripId)
          .collection('entries')
          .add(entryData);
    } catch (e) {
      rethrow;
    }
  }

  // 5. Stream the diary entries for a specific trip
  Stream<QuerySnapshot> streamTripEntries(String tripId) {
    try {
      return _firestore
          .collection('trips')
          .doc(tripId)
          .collection('entries')
          .orderBy('createdAt', descending: true)
          .snapshots(includeMetadataChanges: true);
    } catch (e) {
      return const Stream.empty();
    }
  }

  // 6. Delete a trip
  Future<void> deleteTrip(String tripDocId) async {
    await _firestore.collection('trips').doc(tripDocId).delete();
  }

  // 7. Update a trip's editable fields
  Future<void> updateTrip(String tripDocId, Map<String, dynamic> updates) async {
    await _firestore.collection('trips').doc(tripDocId).update({
      ...updates,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── LIKES (/trips/{tripId}/likes/{userId}) ───────────────────

  Future<void> likePost(String tripId, String userId) async {
    await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('likes')
        .doc(userId)
        .set({'likedAt': FieldValue.serverTimestamp()});
  }

  Future<void> unlikePost(String tripId, String userId) async {
    await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('likes')
        .doc(userId)
        .delete();
  }

  Stream<int> streamLikeCount(String tripId) {
    return _firestore
        .collection('trips')
        .doc(tripId)
        .collection('likes')
        .snapshots()
        .map((s) => s.docs.length);
  }

  Future<bool> isPostLikedByUser(String tripId, String userId) async {
    final doc = await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('likes')
        .doc(userId)
        .get();
    return doc.exists;
  }

  // ── COMMENTS (/trips/{tripId}/comments/{commentId}) ──────────

  Future<void> addComment(
    String tripId, {
    required String authorId,
    required String authorName,
    required String text,
    String? authorPhotoBase64,
  }) async {
    await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('comments')
        .add({
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoBase64': authorPhotoBase64 ?? '',
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> streamComments(String tripId) {
    return _firestore
        .collection('trips')
        .doc(tripId)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }
}