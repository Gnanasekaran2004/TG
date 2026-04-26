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
import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../injection_container.dart' as di;
import '../../features/social/profile/data/datasources/firebase_profile_datasource.dart';

// ── Background FCM handler (required at top-level) ───────────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  log('Background FCM message: ${message.messageId}');
}

// ─────────────────────────────────────────────────────────────────────────────
// FirebaseMessagingService
//
// Handles:
//  1. FCM permission + token management
//  2. Foreground FCM messages → local notification
//  3. Firestore notification watcher → local notification (no backend needed)
//     Starts when a user logs in, stops when they log out.
// ─────────────────────────────────────────────────────────────────────────────

class FirebaseMessagingService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // Use nullable + dynamic cast to be compatible with all plugin versions
  FlutterLocalNotificationsPlugin? _localNotif;
  AndroidNotificationChannel?      _channel;

  // Firestore watcher state
  StreamSubscription<QuerySnapshot>? _notifSubscription;
  final Set<String> _shownIds = {};
  int _notifCounter = 0;

  // ── Initialize (call once at app start) ─────────────────────────────────────

  Future<void> initialize() async {
    // 1. Request permissions
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    if (!kIsWeb) {
      // 2. Local notifications setup (Android)
      _localNotif = FlutterLocalNotificationsPlugin();

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);

      // Cast to dynamic to support both old (positional) and new (named) API
      await (_localNotif as dynamic).initialize(initSettings);

      _channel = const AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'Trip-GUY social and system notifications.',
        importance: Importance.max,
      );

      await _localNotif!
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel!);

      // 3. Background FCM handler (mobile only)
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    }

    // 4. Foreground FCM messages
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      final n = msg.notification;
      if (!kIsWeb && _localNotif != null && n != null && _channel != null) {
        _showLocalNotification(
          id:    n.hashCode,
          title: n.title ?? '',
          body:  n.body  ?? '',
        );
      }
    });

    // 5. Save FCM token
    await _saveDeviceToken();
    _fcm.onTokenRefresh.listen(_saveTokenToFirestore);

    // 6. Start Firestore watcher if a user is already signed in
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      startNotificationWatcher(currentUser.uid);
    }

    // 7. Re-start/stop watcher on auth changes
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        startNotificationWatcher(user.uid);
      } else {
        stopNotificationWatcher();
      }
    });
  }

  // ── Firestore notification watcher ───────────────────────────────────────────
  // Listens for new unread notifications in Firestore and shows local push.

  void startNotificationWatcher(String uid) {
    stopNotificationWatcher();
    _shownIds.clear();

    // Seed existing unread docs so we don't re-notify on app start
    FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .get()
        .then((snap) {
      for (final doc in snap.docs) {
        _shownIds.add(doc.id);
      }

      // Now subscribe — only NEW arrivals (not in _shownIds) fire a push
      _notifSubscription = FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', isEqualTo: uid)
          .where('read', isEqualTo: false)
          .snapshots()
          .listen((snap) {
        for (final change in snap.docChanges) {
          if (change.type != DocumentChangeType.added) continue;
          final docId = change.doc.id;
          if (_shownIds.contains(docId)) continue;
          _shownIds.add(docId);

          final data  = change.doc.data() as Map<String, dynamic>;
          final title = (data['title'] as String?) ?? 'Trip-GUY';
          final body  = (data['body']  as String?) ?? '';

          _showLocalNotification(
            id:    ++_notifCounter,
            title: title,
            body:  body,
          );
        }
      }, onError: (Object e) { log('Notification watcher error: $e'); });
    }).catchError((Object e) { log('Notification seed error: $e'); return null; });
  }

  void stopNotificationWatcher() {
    _notifSubscription?.cancel();
    _notifSubscription = null;
  }

  // ── Show a local phone notification ─────────────────────────────────────────

  void _showLocalNotification({
    required int    id,
    required String title,
    required String body,
  }) {
    if (kIsWeb || _localNotif == null || _channel == null) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel!.id,
        _channel!.name,
        channelDescription: _channel!.description,
        importance:     Importance.max,
        priority:       Priority.high,
        icon:           '@mipmap/ic_launcher',
        color:          const Color(0xFF4272FF),
        playSound:      true,
        enableVibration: true,
      ),
    );

    // Dynamic cast handles both positional and named param API versions
    (_localNotif as dynamic).show(id, title, body, details);
  }

  // ── FCM token helpers ────────────────────────────────────────────────────────

  Future<void> _saveDeviceToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) await _saveTokenToFirestore(token);
    } catch (e) {
      log('Failed to get FCM token: $e');
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await di.sl<FirebaseProfileDataSource>().updateUserProfile(
          uid: user.uid,
          updates: {'fcmToken': token},
        );
        log('FCM token saved.');
      } catch (e) {
        log('Failed to save FCM token: $e');
      }
    }
  }
}
