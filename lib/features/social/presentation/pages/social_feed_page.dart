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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../injection_container.dart' as di;
import '../../data/datasources/firebase_trip_datasource.dart';
import '../../data/datasources/firebase_friends_datasource.dart';
import '../../profile/data/datasources/firebase_profile_datasource.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Feed-level profile cache
// Shared by all _LiveTripCard instances — same author → single Firestore read.
// File-level (not class-level) so it can be cleared externally on sign-out.
// ─────────────────────────────────────────────────────────────────────────────
final Map<String, Future<Map<String, dynamic>?>> _feedProfileCache = {};

/// Clears the in-memory profile cache used by the social feed.
/// Call this on sign-out to prevent stale profile data for the next user.
void clearFeedProfileCache() => _feedProfileCache.clear();

class SocialFeedPage extends StatefulWidget {
  const SocialFeedPage({super.key});
  @override
  State<SocialFeedPage> createState() => _SocialFeedPageState();
}

class _SocialFeedPageState extends State<SocialFeedPage> {
  // Streams stored as fields — recreating them inside build() leaks subscriptions.
  late final Stream<QuerySnapshot> _publicStream;
  Stream<QuerySnapshot> _friendsStream = const Stream.empty();

  @override
  void initState() {
    super.initState();
    _publicStream = di.sl<FirebaseTripDataSource>().streamAllTrips();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final ids = await di.sl<FirebaseFriendsDataSource>().getFriendIds();
    if (!mounted) return;
    setState(() {
      _friendsStream = ids.isNotEmpty
          ? di.sl<FirebaseTripDataSource>().streamFriendsTrips(ids)
          : const Stream.empty();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _publicStream,
      builder: (context, publicSnap) {
        return StreamBuilder<QuerySnapshot>(
      stream: _friendsStream,
          builder: (context, friendsSnap) {
            if (publicSnap.hasError) {
              return const Center(
                  child: Text('Failed to load. Check your connection.',
                      style: TextStyle(color: Colors.grey)));
            }
            if (publicSnap.connectionState == ConnectionState.waiting && !publicSnap.hasData) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }

            // ── Merge public + friends posts, de-duplicate by doc ID ──
            final publicDocs = (publicSnap.data?.docs ?? []).where((doc) {
              final v = (doc.data() as Map<String, dynamic>)['visibility']?.toString().toLowerCase();
              return v == null || v == 'public';
            }).toList();

            final friendsDocs = (friendsSnap.data?.docs ?? []).toList();

            final seen = <String>{};
            final merged = <QueryDocumentSnapshot>[];
            for (final doc in [...publicDocs, ...friendsDocs]) {
              if (seen.add(doc.id)) merged.add(doc);
            }

            merged.sort((a, b) {
              final aT = (a.data() as Map)['createdAt'] as Timestamp?;
              final bT = (b.data() as Map)['createdAt'] as Timestamp?;
              if (aT == null || bT == null) return 0;
              return bT.compareTo(aT);
            });

            if (merged.isEmpty) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.flight_takeoff_rounded, size: 56, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  const Text('No trips yet!',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 6),
                  const Text('Tap the + button to share your first adventure.',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ]),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: merged.length,
              itemBuilder: (context, index) {
                final doc = merged[index];
                return _LiveTripCard(
                  key: ValueKey(doc.id), // PERF: stable key prevents full card rebuild on list reorder
                  tripDocId: doc.id,
                  tripData: doc.data() as Map<String, dynamic>,
                  animationDelay: (index * 60).ms,
                );
              },
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trip Card
// ─────────────────────────────────────────────────────────────────────────────
class _LiveTripCard extends StatefulWidget {
  final String tripDocId;
  final Map<String, dynamic> tripData;
  final Duration animationDelay;

  const _LiveTripCard({
    super.key, // required for ValueKey to work from the ListView
    required this.tripDocId,
    required this.tripData,
    required this.animationDelay,
  });

  @override
  State<_LiveTripCard> createState() => _LiveTripCardState();
}

class _LiveTripCardState extends State<_LiveTripCard> {
  // PERF: Backed by the file-level _feedProfileCache map so sign-out cleanup
  // in main.dart (which calls clearFeedProfileCache()) also clears this.
  static final Map<String, Future<Map<String, dynamic>?>> _profileCache = _feedProfileCache;

  late Future<Map<String, dynamic>?> _userProfileFuture;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  bool get _isOwner {
    final ownerId = widget.tripData['ownerId']?.toString();
    if (ownerId == null || ownerId.isEmpty) return false;
    return ownerId == _currentUserId;
  }

  @override
  void initState() {
    super.initState();
    final ownerId = widget.tripData['ownerId']?.toString() ?? '';
    // putIfAbsent ensures the Future is shared for the same ownerId —
    // concurrent cards for the same author don't fire duplicate reads.
    _userProfileFuture = _profileCache.putIfAbsent(
      ownerId,
      () => di.sl<FirebaseProfileDataSource>().getUserProfile(ownerId),
    );
  }


  // ── 3-Dots Menu ─────────────────────────────────────────────
  void _showPostOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            if (_isOwner) ...[
              _OptionTile(
                icon: Icons.edit_outlined,
                color: AppColors.primary,
                label: 'Edit Post',
                onTap: () { Navigator.pop(context); _showEditDialog(context); },
              ),
              _OptionTile(
                icon: Icons.delete_outline,
                color: Colors.red,
                label: 'Delete Post',
                labelColor: Colors.red,
                onTap: () { Navigator.pop(context); _confirmDelete(context); },
              ),
            ],
            _OptionTile(
              icon: Icons.share_outlined,
              color: const Color(0xFF25D366),
              label: 'Share Trip',
              onTap: () {
                Navigator.pop(context);
                _showShareSheet(context);
              },
            ),
            if (!_isOwner)
              _OptionTile(
                icon: Icons.flag_outlined,
                color: Colors.orange,
                label: 'Report Post',
                onTap: () => Navigator.pop(context),
              ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  // ── Share Trip ───────────────────────────────────────────────
  String _buildShareText() {
    final title  = widget.tripData['title']?.toString() ?? 'My Trip';
    final source = widget.tripData['source']?.toString() ?? 'Origin';
    final dest   = widget.tripData['destination']?.toString() ?? 'Destination';
    final budget = widget.tripData['budget']?.toString() ?? '0';
    final cat    = widget.tripData['category']?.toString() ?? 'Adventure';
    final mode   = widget.tripData['travelMode']?.toString() ?? '';
    final start  = widget.tripData['startDate']?.toString();
    final end    = widget.tripData['endDate']?.toString();

    String dateStr = '';
    if (start != null && end != null) {
      try {
        final s = DateTime.parse(start);
        final e = DateTime.parse(end);
        final days = e.difference(s).inDays + 1;
        dateStr = '\n📅 ${s.day}/${s.month}/${s.year} → ${e.day}/${e.month}/${e.year} ($days days)';
      } catch (_) {}
    }

    return '✈️ *$title*\n'
        '🗺️ $source  →  $dest\n'
        '🏷️ $cat${mode.isNotEmpty ? ' · $mode' : ''}\n'
        '💰 ₹$budget$dateStr\n\n'
        '📱 Shared via Trip-GUY App';
  }

  void _showShareSheet(BuildContext context) {
    final text = _buildShareText();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ShareSheet(shareText: text),
    );
  }

  // ── Edit ─────────────────────────────────────────────────────
  Future<void> _showEditDialog(BuildContext context) async {
    final descCtrl = TextEditingController(
        text: widget.tripData['description']?.toString() ??
            widget.tripData['title']?.toString() ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Post'),
        content: TextField(
          controller: descCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Description / Caption',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (result == true) {
      await di.sl<FirebaseTripDataSource>().updateTrip(widget.tripDocId, {
        'description': descCtrl.text.trim(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Post updated!')),
        );
      }
    }
  }

  // ── Delete ───────────────────────────────────────────────────
  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Post?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await di.sl<FirebaseTripDataSource>().deleteTrip(widget.tripDocId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🗑️ Post deleted.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: ${e.toString().split(' ').take(10).join(' ')}...'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ── Comments Sheet ────────────────────────────────────────────
  void _openComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(
        tripId: widget.tripDocId,
        currentUserId: _currentUserId ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final caption = widget.tripData['description']?.toString() ??
        widget.tripData['title']?.toString() ??
        'An exciting new adventure!';
    final source = widget.tripData['source']?.toString() ?? 'Origin';
    final destination = widget.tripData['destination']?.toString() ?? 'Destination';
    final budget = '₹${widget.tripData['budget']?.toString() ?? '0'}';
    final category = widget.tripData['category']?.toString() ?? 'Adventure';

    List<Color> gradient = const [Color(0xFF2453E0), Color(0xFF4272FF)];
    if (category == 'Beach') {
      gradient = const [Color(0xFF42EAFF), Color(0xFF00C8E0)];
    } else if (category == 'Cultural') {
      gradient = const [Color(0xFFFF7E42), Color(0xFFFFB343)];
    } else if (category == 'Road Trip') {
      gradient = const [Color(0xFFE06C2E), Color(0xFFF4A261)];
    } else if (category == 'Cruise') {
      gradient = const [Color(0xFF0F7A55), Color(0xFF27AE81)];
    } else if (category == 'Business') {
      gradient = const [Color(0xFF2C3E59), Color(0xFF4A6FA5)];
    }

    final visRaw = widget.tripData['visibility']?.toString().toLowerCase();
    final IconData visIcon;
    final Color visColor;
    if (visRaw == 'friends') {
      visIcon = Icons.group_outlined;
      visColor = AppColors.cyan;
    } else if (visRaw == 'private') {
      visIcon = Icons.lock_outline;
      visColor = Colors.grey;
    } else {
      visIcon = Icons.public;
      visColor = AppColors.primary;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 6),
          child: FutureBuilder<Map<String, dynamic>?>(
            future: _userProfileFuture,
            builder: (context, snapshot) {
              final displayName = snapshot.data?['name']?.toString() ?? 'Traveler';
              final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'T';
              return Row(children: [
                ProfileAvatar(
                  photoBase64: snapshot.data?['photoBase64']?.toString(),
                  initial: initial,
                  radius: 18,
                  backgroundColor: gradient.first,
                ),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Row(children: [
                    Text(category,
                        style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                    const SizedBox(width: 6),
                    Icon(visIcon, size: 11, color: visColor),
                  ]),
                ])),
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                  onPressed: () => _showPostOptions(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]);
            },
          ),
        ),

        // ── Route Banner ──────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            const Icon(Icons.location_on, color: Colors.white70, size: 13),
            const SizedBox(width: 4),
            Text(source,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            const Spacer(),
            const Icon(Icons.arrow_forward, color: Colors.white54, size: 13),
            const Spacer(),
            Text(destination,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.flag, color: Colors.white70, size: 13),
          ]),
        ),

        // ── Caption ───────────────────────────────────────
        if (caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Text(caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),

        // ── Budget tag ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
          child: Chip(
            label: Text(budget,
                style: TextStyle(fontSize: 10, color: gradient.first, fontWeight: FontWeight.bold)),
            backgroundColor: gradient.first.withAlpha(15),
            side: BorderSide(color: gradient.first.withAlpha(50)),
            padding: const EdgeInsets.symmetric(horizontal: 2),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),

        // ── Likes / Comments Bar ──────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
          child: Row(children: [
            _LikeButton(tripId: widget.tripDocId, userId: _currentUserId ?? ''),
            const SizedBox(width: 4),
            StreamBuilder<QuerySnapshot>(
              stream: di.sl<FirebaseTripDataSource>().streamComments(widget.tripDocId),
              builder: (context, snap) {
                final count = snap.data?.docs.length ?? 0;
                return TextButton.icon(
                  onPressed: () => _openComments(context),
                  icon: const Icon(Icons.chat_bubble_outline, size: 15, color: Colors.grey),
                  label: Text('$count',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 28),
                  ),
                );
              },
            ),
          ]),
        ),
      ]),
    ).animate(delay: animationDelay).fade(duration: 300.ms).slideY(begin: 0.05, end: 0);
  }

  Duration get animationDelay => widget.animationDelay;
}

// ─────────────────────────────────────────────────────────────────────────────
// Like Button
// ─────────────────────────────────────────────────────────────────────────────
class _LikeButton extends StatefulWidget {
  final String tripId;
  final String userId;
  const _LikeButton({required this.tripId, required this.userId});

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton> {
  bool _isLiked = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLikeStatus();
  }

  Future<void> _loadLikeStatus() async {
    if (widget.userId.isEmpty) { setState(() => _loading = false); return; }
    final liked = await di.sl<FirebaseTripDataSource>().isPostLikedByUser(widget.tripId, widget.userId);
    if (mounted) setState(() { _isLiked = liked; _loading = false; });
  }

  Future<void> _toggle() async {
    if (widget.userId.isEmpty || _loading) return;
    setState(() => _isLiked = !_isLiked);
    try {
      if (_isLiked) {
        await di.sl<FirebaseTripDataSource>().likePost(widget.tripId, widget.userId);
      } else {
        await di.sl<FirebaseTripDataSource>().unlikePost(widget.tripId, widget.userId);
      }
    } catch (_) {
      if (mounted) setState(() => _isLiked = !_isLiked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: di.sl<FirebaseTripDataSource>().streamLikeCount(widget.tripId),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return TextButton.icon(
          onPressed: _toggle,
          icon: Icon(
            _isLiked ? Icons.favorite : Icons.favorite_border,
            size: 15,
            color: _isLiked ? Colors.red : Colors.grey,
          ),
          label: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              color: _isLiked ? Colors.red : Colors.grey,
              fontWeight: _isLiked ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(0, 28),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Comments Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _CommentsSheet extends StatefulWidget {
  final String tripId;
  final String currentUserId;
  const _CommentsSheet({required this.tripId, required this.currentUserId});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _commentController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || widget.currentUserId.isEmpty) return;
    setState(() => _sending = true);
    try {
      final profile = await di.sl<FirebaseProfileDataSource>().getUserProfile(widget.currentUserId);
      await di.sl<FirebaseTripDataSource>().addComment(
        widget.tripId,
        authorId: widget.currentUserId,
        authorName: profile?['name']?.toString() ?? 'Traveler',
        text: text,
        authorPhotoBase64: profile?['photoBase64']?.toString(),
      );
      _commentController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(children: [
              const Text('Comments',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: di.sl<FirebaseTripDataSource>().streamComments(widget.tripId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.chat_bubble_outline, size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No comments yet.\nBe the first to comment!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ]),
                  );
                }

                final comments = snapshot.data!.docs;
                return ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final data = comments[index].data() as Map<String, dynamic>;
                    final name = data['authorName']?.toString() ?? 'Traveler';
                    final text = data['text']?.toString() ?? '';
                    final photoBase64 = data['authorPhotoBase64']?.toString();
                    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'T';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _Base64Avatar(photoBase64: photoBase64, initial: initial, radius: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(name,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(text,
                                style: const TextStyle(fontSize: 13, height: 1.4)),
                          ]),
                        ),
                      ]),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _postComment(),
                ),
              ),
              const SizedBox(width: 8),
              _sending
                  ? const SizedBox(
                      width: 40, height: 40,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
                  : GestureDetector(
                      onTap: _postComment,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      ),
                    ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Base64 Avatar Helper
// ─────────────────────────────────────────────────────────────────────────────
class _Base64Avatar extends StatelessWidget {
  final String? photoBase64;
  final String initial;
  final double radius;
  const _Base64Avatar({required this.photoBase64, required this.initial, required this.radius});

  @override
  Widget build(BuildContext context) {
    if (photoBase64 != null && photoBase64!.isNotEmpty) {
      try {
        final Uint8List bytes = base64Decode(photoBase64!);
        return CircleAvatar(radius: radius, backgroundImage: MemoryImage(bytes), backgroundColor: AppColors.primary);
      } catch (_) {}
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary,
      child: Text(initial, style: TextStyle(color: Colors.white, fontSize: radius * 0.7, fontWeight: FontWeight.bold)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Option Tile (3-dots menu items)
// ─────────────────────────────────────────────────────────────────────────────
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final Color? labelColor;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.color,
    required this.label,
    this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withAlpha(20), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: TextStyle(color: labelColor, fontWeight: FontWeight.w500)),
      onTap: onTap,
      dense: true,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Share Trip Bottom Sheet  —  WhatsApp · Copy Text · SMS
// ─────────────────────────────────────────────────────────────────────────────
class _ShareSheet extends StatelessWidget {
  final String shareText;
  const _ShareSheet({required this.shareText});

  Future<void> _shareWhatsApp(BuildContext context) async {
    Navigator.pop(context);
    final encoded = Uri.encodeComponent(shareText);
    final uri = Uri.parse('whatsapp://send?text=$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      final webUri = Uri.parse('https://api.whatsapp.com/send?text=$encoded');
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('WhatsApp is not installed on this device.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _copyLink(BuildContext context) async {
    Navigator.pop(context);
    await Clipboard.setData(ClipboardData(text: shareText));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text('Trip details copied to clipboard!'),
          ]),
          backgroundColor: const Color(0xFF2453E0),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _shareSMS(BuildContext context) async {
    Navigator.pop(context);
    final encoded = Uri.encodeComponent(shareText);
    final uri = Uri.parse('sms:?body=$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS is not available on this device.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2453E0), Color(0xFF8E2DE2)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Share Trip', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    Text('Choose how you want to share', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ]),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            const Divider(height: 1, indent: 20, endIndent: 20),
            // Preview card
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF2453E0).withAlpha(12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2453E0).withAlpha(40)),
              ),
              child: Text(
                shareText,
                style: const TextStyle(fontSize: 13, height: 1.6, color: Colors.black87),
              ),
            ).animate().fade(duration: 250.ms).slideY(begin: 0.05),
            const SizedBox(height: 4),
            // WhatsApp — Icons.whatsapp does NOT exist in Material; use branded 'W' text
            _ShareOption(
              customIconWidget: const Text(
                'W',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Georgia',
                ),
              ),
              iconBg: const Color(0xFF25D366),
              label: 'WhatsApp',
              subtitle: 'Send via WhatsApp',
              delay: 0.ms,
              onTap: () => _shareWhatsApp(context),
            ),
            _ShareOption(
              icon: Icons.copy_rounded,
              iconBg: const Color(0xFF2453E0),
              label: 'Copy Text',
              subtitle: 'Copy trip details to clipboard',
              delay: 60.ms,
              onTap: () => _copyLink(context),
            ),
            _ShareOption(
              icon: Icons.message_rounded,
              iconBg: const Color(0xFF8E2DE2),
              label: 'SMS',
              subtitle: 'Send as a text message',
              delay: 120.ms,
              onTap: () => _shareSMS(context),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual share option row
// ─────────────────────────────────────────────────────────────────────────────
class _ShareOption extends StatelessWidget {
  /// Provide [icon] for a Material icon, OR [customIconWidget] for a custom widget.
  final IconData? icon;
  final Widget? customIconWidget;
  final Color iconBg;
  final String label;
  final String subtitle;
  final Duration delay;
  final VoidCallback onTap;

  const _ShareOption({
    this.icon,
    this.customIconWidget,
    required this.iconBg,
    required this.label,
    required this.subtitle,
    required this.delay,
    required this.onTap,
  }) : assert(icon != null || customIconWidget != null,
            '_ShareOption: provide either icon or customIconWidget');

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: iconBg.withAlpha(80),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: customIconWidget ?? Icon(icon, color: Colors.white, size: 22),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ]),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ]),
        ),
      ),
    ).animate(delay: delay).fade(duration: 280.ms).slideX(begin: 0.04, end: 0);
  }
}