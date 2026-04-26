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
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../injection_container.dart' as di;
import '../../data/datasources/firebase_friends_datasource.dart';
import '../../profile/data/datasources/firebase_profile_datasource.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Friends Page — Discover / Followers / Following
// ─────────────────────────────────────────────────────────────────────────────

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});
  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final String _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2453E0),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Friends',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: di.sl<FirebaseFriendsDataSource>().streamMyPendingRequests(),
            builder: (context, snap) {
              final count = snap.data?.docs.length ?? 0;
              if (count == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Chip(
                  label: Text('$count new',
                      style: const TextStyle(color: Colors.white, fontSize: 11)),
                  backgroundColor: AppColors.secondary,
                  padding: EdgeInsets.zero,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Discover'),
            Tab(text: 'Followers'),
            Tab(text: 'Following'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DiscoverTab(currentUid: _currentUid),
          _FollowersTab(currentUid: _currentUid),
          _FollowingTab(currentUid: _currentUid),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DISCOVER TAB — all users with follow button
// ─────────────────────────────────────────────────────────────────────────────

class _DiscoverTab extends StatefulWidget {
  final String currentUid;
  const _DiscoverTab({required this.currentUid});
  @override
  State<_DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<_DiscoverTab> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: TextField(
          onChanged: (v) => setState(() => _search = v.toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Search travelers...',
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('uid', isNotEqualTo: widget.currentUid)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }
            final users = snap.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name']?.toString().toLowerCase() ?? '';
              return _search.isEmpty || name.contains(_search);
            }).toList();

            if (users.isEmpty) {
              return const Center(child: Text('No travelers found.', style: TextStyle(color: Colors.grey)));
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: users.length,
              itemBuilder: (context, i) {
                final data = users[i].data() as Map<String, dynamic>;
                return _UserTile(
                  uid: data['uid']?.toString() ?? '',
                  name: data['name']?.toString() ?? 'Traveler',
                  bio: data['bio']?.toString() ?? '',
                  photoBase64: data['photoBase64']?.toString(),
                  followersCount: data['followersCount'] ?? 0,
                  currentUid: widget.currentUid,
                  animDelay: (i * 40).ms,
                ).animate().fade(delay: (i * 40).ms);
              },
            );
          },
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOLLOWERS TAB — people who follow you (pending + accepted)
// ─────────────────────────────────────────────────────────────────────────────

class _FollowersTab extends StatelessWidget {
  final String currentUid;
  const _FollowersTab({required this.currentUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: di.sl<FirebaseFriendsDataSource>().streamMyPendingRequests(),
      builder: (context, pendingSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: di.sl<FirebaseFriendsDataSource>().streamMyFollowers(),
          builder: (context, followersSnap) {
            final pendingDocs = pendingSnap.data?.docs ?? [];
            final acceptedDocs = followersSnap.data?.docs ?? [];

            if (pendingDocs.isEmpty && acceptedDocs.isEmpty) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.people_outline, size: 56, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  const Text('No followers yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text('Share your trips to get followers!',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ]),
              );
            }

            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (pendingDocs.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                    child: Text('Follow Requests (${pendingDocs.length})',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  ...pendingDocs.map((doc) => _PendingRequestTile(
                    requesterUid: doc.id,
                    currentUid: currentUid,
                  )),
                  const Divider(height: 20, indent: 16, endIndent: 16),
                ],
                if (acceptedDocs.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                    child: Text('Followers (${acceptedDocs.length})',
                        style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  ...acceptedDocs.map((doc) => _SimpleUserTile(uid: doc.id)),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOLLOWING TAB
// ─────────────────────────────────────────────────────────────────────────────

class _FollowingTab extends StatelessWidget {
  final String currentUid;
  const _FollowingTab({required this.currentUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: di.sl<FirebaseFriendsDataSource>().streamMyFollowing(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.person_add_alt_1_outlined, size: 56, color: Colors.grey[300]),
              const SizedBox(height: 12),
              const Text('Not following anyone yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 6),
              const Text('Discover travelers on the Discover tab!',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
            ]),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            return _FollowingTile(
              targetUid: docs[i].id,
              currentUid: currentUid,
            ).animate().fade(delay: (i * 40).ms);
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// USER TILE — Discover card with Follow / Pending / Following state button
// ─────────────────────────────────────────────────────────────────────────────

class _UserTile extends StatefulWidget {
  final String uid, name, bio;
  final String? photoBase64;
  final int followersCount;
  final String currentUid;
  final Duration animDelay;

  const _UserTile({
    required this.uid,
    required this.name,
    required this.bio,
    this.photoBase64,
    required this.followersCount,
    required this.currentUid,
    required this.animDelay,
  });

  @override
  State<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<_UserTile> {
  FollowStatus _status = FollowStatus.none;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final status = await di.sl<FirebaseFriendsDataSource>().followStatus(widget.uid);
    if (mounted) setState(() { _status = status; _loading = false; });
  }

  Future<void> _onButtonTap() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      if (_status == FollowStatus.none) {
        await di.sl<FirebaseFriendsDataSource>().followUser(widget.uid);
        setState(() { _status = FollowStatus.pending; _loading = false; });
      } else if (_status == FollowStatus.following) {
        await di.sl<FirebaseFriendsDataSource>().unfollowUserFull(widget.uid);
        setState(() { _status = FollowStatus.none; _loading = false; });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget button;
    if (_loading) {
      button = const SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary));
    } else if (_status == FollowStatus.following) {
      button = OutlinedButton(
        onPressed: _onButtonTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        ),
        child: const Text('Following', style: TextStyle(fontSize: 12)),
      );
    } else if (_status == FollowStatus.pending) {
      button = OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.grey),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        ),
        child: const Text('Pending', style: TextStyle(fontSize: 12, color: Colors.grey)),
      );
    } else {
      button = ElevatedButton(
        onPressed: _onButtonTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          elevation: 0,
        ),
        child: const Text('Follow', style: TextStyle(fontSize: 12)),
      );
    }

    final initial = widget.name.isNotEmpty ? widget.name[0].toUpperCase() : 'T';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        ProfileAvatar(
          photoBase64: widget.photoBase64,
          initial: initial,
          radius: 24,
          backgroundColor: AppColors.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            if (widget.bio.isNotEmpty)
              Text(widget.bio,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            Text('${widget.followersCount} followers',
                style: TextStyle(color: AppColors.primary.withAlpha(180), fontSize: 11)),
          ]),
        ),
        const SizedBox(width: 8),
        // Fixed width so the button never causes a Row overflow
        SizedBox(width: 96, child: button),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PENDING REQUEST TILE — Accept / Reject
// ─────────────────────────────────────────────────────────────────────────────

class _PendingRequestTile extends StatefulWidget {
  final String requesterUid, currentUid;
  const _PendingRequestTile({required this.requesterUid, required this.currentUid});
  @override
  State<_PendingRequestTile> createState() => _PendingRequestTileState();
}

class _PendingRequestTileState extends State<_PendingRequestTile> {
  bool _processing = false;

  Future<void> _accept() async {
    setState(() => _processing = true);
    await di.sl<FirebaseFriendsDataSource>().acceptRequest(widget.requesterUid);
    // No setState needed — StreamBuilder will rebuild
  }

  Future<void> _reject() async {
    setState(() => _processing = true);
    await di.sl<FirebaseFriendsDataSource>().rejectFollowRequest(widget.requesterUid);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: di.sl<FirebaseProfileDataSource>().getUserProfile(widget.requesterUid),
      builder: (context, snap) {
        final data = snap.data ?? {};
        final name = data['name']?.toString() ?? 'Traveler';
        final photo = data['photoBase64']?.toString();
        final initial = name.isNotEmpty ? name[0].toUpperCase() : 'T';

        return ListTile(
          leading: ProfileAvatar(photoBase64: photo, initial: initial, radius: 22, backgroundColor: AppColors.gold),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Wants to follow you', style: TextStyle(color: Colors.grey, fontSize: 12)),
          trailing: _processing
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  GestureDetector(
                    onTap: _reject,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.red.withAlpha(20), shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.red, size: 18),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _accept,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: AppColors.primary.withAlpha(20), shape: BoxShape.circle),
                      child: const Icon(Icons.check, color: AppColors.primary, size: 18),
                    ),
                  ),
                ]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SIMPLE USER TILE — just name + avatar (for accepted followers list)
// ─────────────────────────────────────────────────────────────────────────────

class _SimpleUserTile extends StatelessWidget {
  final String uid;
  const _SimpleUserTile({required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: di.sl<FirebaseProfileDataSource>().getUserProfile(uid),
      builder: (context, snap) {
        final data = snap.data ?? {};
        final name = data['name']?.toString() ?? 'Traveler';
        final photo = data['photoBase64']?.toString();
        final initial = name.isNotEmpty ? name[0].toUpperCase() : 'T';
        return ListTile(
          leading: ProfileAvatar(photoBase64: photo, initial: initial, radius: 22, backgroundColor: AppColors.cyan),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(data['bio']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOLLOWING TILE — with Unfollow button
// ─────────────────────────────────────────────────────────────────────────────

class _FollowingTile extends StatefulWidget {
  final String targetUid, currentUid;
  const _FollowingTile({required this.targetUid, required this.currentUid});
  @override
  State<_FollowingTile> createState() => _FollowingTileState();
}

class _FollowingTileState extends State<_FollowingTile> {
  bool _unfollowing = false;

  Future<void> _unfollow() async {
    setState(() => _unfollowing = true);
    await di.sl<FirebaseFriendsDataSource>().unfollowUserFull(widget.targetUid);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: di.sl<FirebaseProfileDataSource>().getUserProfile(widget.targetUid),
      builder: (context, snap) {
        final data = snap.data ?? {};
        final name = data['name']?.toString() ?? 'Traveler';
        final photo = data['photoBase64']?.toString();
        final initial = name.isNotEmpty ? name[0].toUpperCase() : 'T';
        return ListTile(
          leading: ProfileAvatar(photoBase64: photo, initial: initial, radius: 22, backgroundColor: AppColors.primaryLight),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(data['bio']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          trailing: _unfollowing
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : TextButton(
                  onPressed: _unfollow,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Unfollow', style: TextStyle(fontSize: 12)),
                ),
        );
      },
    );
  }
}
