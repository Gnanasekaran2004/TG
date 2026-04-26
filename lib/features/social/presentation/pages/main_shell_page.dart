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
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../features/notifications/presentation/pages/notifications_page.dart';
import 'social_feed_page.dart';
import '../../../../features/navigation/presentation/pages/live_map_page.dart';
import '../../../../features/chat/presentation/pages/chat_list_page.dart';
import '../../../../features/diary/presentation/pages/diary_page.dart';
import '../../../../features/ai_assistant/presentation/pages/ai_assistant_page.dart';
import '../../../../features/auth/presentation/pages/profile_page.dart';
import '../widgets/add_trip_modal.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _currentIndex = 0;

  // ── Live unread notification count from Firestore ──
  Stream<int> get _unreadNotifStream {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(0);
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // ── Live unread CHAT messages count across all conversations ──
  Stream<int> get _unreadChatStream {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(0);
    // Count messages where I am receiver and 'read' is false
    return FirebaseFirestore.instance
        .collectionGroup('messages')
        .where('receiverId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  final List<Widget> _pages = [
    const SocialFeedPage(),
    const LiveMapPage(),
    const ChatListPage(),
    const DiaryPage(),
  ];

  final List<String> _titles = [
    'Trip-GUY',
    'Live Navigator',
    'Messages',
    'Travel Diary',
  ];

  void _openAddTrip() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddTripModal(),
    );
  }

  void _openChatbot() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AiAssistantFullPage()),
    );
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = ThemeProviderWidget.of(context);
    final isDark = themeProvider.isDark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_currentIndex],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        automaticallyImplyLeading: false,
        actions: [
          // ── Theme Toggle ─────────────────────────────
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                isDark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
                key: ValueKey(isDark),
              ),
            ),
            tooltip: isDark ? 'Switch to Light' : 'Switch to Dark',
            onPressed: () {
              themeProvider.setMode(
                isDark ? ThemeMode.light : ThemeMode.dark,
              );
            },
          ),
          // ── Notification Icon with Live Badge ───────
          StreamBuilder<int>(
            stream: _unreadNotifStream,
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return Stack(
                alignment: Alignment.topRight,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    tooltip: 'Notifications',
                    onPressed: _openNotifications,
                  ),
                  if (count > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            count > 9 ? '9+' : '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          // ── Avatar (Live Photo from Firestore) ──────
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              ).then((_) => setState(() {})); // Refresh on return
            },
            child: Container(
              margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
              width: 36,
              height: 36,
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseAuth.instance.currentUser == null
                    ? null
                    : FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser!.uid)
                        .snapshots(),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data() as Map<String, dynamic>?;
                  final photoBase64 = data?['photoBase64']?.toString();
                  final initial = FirebaseAuth.instance.currentUser?.email?.isNotEmpty == true
                      ? FirebaseAuth.instance.currentUser!.email![0].toUpperCase()
                      : 'U';
                  return ProfileAvatar(
                    photoBase64: photoBase64,
                    initial: initial,
                    radius: 18,
                    backgroundColor: AppColors.primary,
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _pages),
      floatingActionButton: _currentIndex == 0
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'chatbot_fab',
                  onPressed: _openChatbot,
                  backgroundColor: const Color(0xFF8E2DE2),
                  tooltip: 'Ask TripBot',
                  child: const Icon(Icons.smart_toy_outlined,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'add_trip_fab',
                  onPressed: _openAddTrip,
                  backgroundColor: AppColors.secondary,
                  tooltip: 'Plan New Trip',
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ],
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) =>
            setState(() => _currentIndex = index),
        indicatorColor: AppColors.primary.withAlpha(30),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppColors.primary),
            label: 'Feed',
          ),
          const NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map, color: AppColors.primary),
            label: 'Map',
          ),
          // ── Chat with unread badge ──
          NavigationDestination(
            icon: StreamBuilder<int>(
              stream: _unreadChatStream,
              builder: (context, snap) {
                final count = snap.data ?? 0;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.chat_bubble_outline),
                    if (count > 0)
                      Positioned(
                        top: -4,
                        right: -6,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            count > 9 ? '9+' : '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            selectedIcon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.chat_bubble, color: AppColors.primary),
                StreamBuilder<int>(
                  stream: _unreadChatStream,
                  builder: (context, snap) {
                    final count = snap.data ?? 0;
                    if (count == 0) return const SizedBox.shrink();
                    return Positioned(
                      top: -4,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          count > 9 ? '9+' : '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            label: 'Chat',
          ),
          const NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book, color: AppColors.primary),
            label: 'Diary',
          ),
        ],
      ),
    );
  }
}

