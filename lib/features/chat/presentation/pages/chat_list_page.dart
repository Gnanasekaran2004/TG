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
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../injection_container.dart' as di;
import '../../data/datasources/firebase_chat_datasource.dart';
import '../../../social/presentation/pages/friends_page.dart';
import 'chat_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Chat List Page — Friends Only
//
// Performance fixes vs original:
//  • streamChatableFriends() now uses 2 batch queries, not N sequential reads
//  • Last-message preview uses FutureBuilder (one-shot fetch), NOT a live
//    StreamBuilder — this eliminates N persistent Firestore listeners that
//    caused the "buffering on every user" problem
//  • streamUserProfile() (1 listener per tile) kept for live avatar/status
// ─────────────────────────────────────────────────────────────────────────────

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});
  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  String _searchQuery = '';
  late final Stream<List<Map<String, dynamic>>> _friendsStream;

  @override
  void initState() {
    super.initState();
    _friendsStream = di.sl<FirebaseChatDataSource>().streamChatableFriends();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Search bar ───────────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText: 'Search friends...',
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                    onPressed: () {
                      setState(() => _searchQuery = '');
                      FocusScope.of(context).unfocus();
                    },
                  )
                : null,
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ),

      const Divider(height: 1),

      // ── Friends live list ─────────────────────────────────────────────────
      Expanded(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _friendsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary));
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('Error loading chats',
                    style: TextStyle(color: Colors.grey[500])));
            }

            final friends = snapshot.data ?? [];
            final filtered = friends.where((d) {
              final name = d['name']?.toString().toLowerCase() ?? '';
              return name.contains(_searchQuery.toLowerCase());
            }).toList();

            if (friends.isEmpty) {
              return _EmptyFriendsState(
                onAddFriends: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const FriendsPage())),
              );
            }

            if (filtered.isEmpty) {
              return Center(
                child: Text('No friends match your search.',
                    style: TextStyle(color: Colors.grey[500])));
            }

            return ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 100),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final data = filtered[index];
                final uid  = data['uid']?.toString()  ?? '';
                final name = data['name']?.toString() ?? 'Friend';

                final colorPalette = [
                  AppColors.primary, AppColors.secondary,
                  AppColors.cyan, AppColors.gold, AppColors.primaryDark,
                ];
                final avatarColor =
                    colorPalette[name.length % colorPalette.length];

                return _ChatTile(
                  userId:         uid,
                  name:           name,
                  avatarColor:    avatarColor,
                  onTap:          _openChat,
                  animationDelay: (index * 50).ms,
                );
              },
            );
          },
        ),
      ),
    ]);
  }

  void _openChat(ChatContact contact) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => ChatScreen(contact: contact)));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyFriendsState extends StatelessWidget {
  final VoidCallback onAddFriends;
  const _EmptyFriendsState({required this.onAddFriends});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(18), shape: BoxShape.circle),
            child: Icon(Icons.chat_bubble_outline_rounded,
                size: 44, color: AppColors.primary.withAlpha(160)),
          ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 20),
          const Text('No friends to chat with yet',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            textAlign: TextAlign.center,
          ).animate().fade(delay: 150.ms),
          const SizedBox(height: 8),
          Text(
            'You can only chat with mutual friends.\nFollow someone and wait for them to follow back.',
            style: TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ).animate().fade(delay: 250.ms),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAddFriends,
            icon: const Icon(Icons.people_outline_rounded, size: 18),
            label: const Text('Find Friends',
                style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
          ).animate().fade(delay: 350.ms).slideY(begin: 0.1),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chat Tile
//
// • streamUserProfile  → 1 live listener (avatar + online status)
// • getLastMessage     → FutureBuilder one-shot fetch (NOT a live listener)
//   This is the critical fix: previously streamMessages() opened a persistent
//   listener per tile, causing N Firestore listeners simultaneously → buffering.
// ─────────────────────────────────────────────────────────────────────────────

class _ChatTile extends StatelessWidget {
  final String userId;
  final String name;
  final Color avatarColor;
  final Function(ChatContact) onTap;
  final Duration animationDelay;

  const _ChatTile({
    required this.userId,
    required this.name,
    required this.avatarColor,
    required this.onTap,
    required this.animationDelay,
  });

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final h  = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m  = dt.minute.toString().padLeft(2, '0');
    final p  = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $p';
  }

  @override
  Widget build(BuildContext context) {
    final ds = di.sl<FirebaseChatDataSource>();

    return StreamBuilder<Map<String, dynamic>?>(
      stream: ds.streamUserProfile(userId),
      builder: (context, profileSnap) {
        final profile     = profileSnap.data ?? {};
        final photoBase64 = profile['photoBase64']?.toString();
        final isOnline    = profile['isOnline'] == true;
        final displayName = profile['name']?.toString() ?? name;

        // ── Last message: one-shot FutureBuilder, NOT a live stream ──────────
        return FutureBuilder<Map<String, dynamic>?>(
          future: ds.getLastMessage(userId),
          builder: (context, msgSnap) {
            final lastMsg  = msgSnap.data;
            final msgText  = lastMsg?['message']?.toString() ??
                'Tap to start a conversation!';
            final timeStr  = _formatTime(lastMsg?['timestamp'] as Timestamp?);
            final isMine   = lastMsg?['senderId'] !=
                userId; // if senderId is NOT the other person, it's mine

            final contact = ChatContact(
              id:          userId,
              name:        displayName,
              avatarColor: avatarColor,
              isOnline:    isOnline,
              lastSeen:    isOnline ? 'Online' : 'Offline',
              mutualTrip:  'Friends',
              photoBase64: photoBase64,
            );

            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              onTap: () => onTap(contact),
              leading: Stack(children: [
                ProfileAvatar(
                  photoBase64:     photoBase64,
                  initial:         displayName.isNotEmpty
                      ? displayName[0].toUpperCase() : 'F',
                  radius:          26,
                  backgroundColor: avatarColor,
                ),
                Positioned(
                  right: 0, bottom: 0,
                  child: Container(
                    width: 13, height: 13,
                    decoration: BoxDecoration(
                      color:  isOnline ? const Color(0xFF1DBF73) : Colors.grey,
                      shape:  BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface, width: 2),
                    ),
                  ),
                ),
              ]),
              title: Row(children: [
                Expanded(
                  child: Text(displayName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                if (timeStr.isNotEmpty)
                  Text(timeStr,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
              subtitle: Row(children: [
                if (isMine && lastMsg != null) ...[
                  Icon(Icons.done_all, size: 14,
                      color: isOnline ? AppColors.cyan : Colors.grey),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    msgText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isOnline
                          ? AppColors.primary.withAlpha(180) : Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                ),
              ]),
            ).animate().fade(delay: animationDelay, duration: 300.ms);
          },
        );
      },
    );
  }
}