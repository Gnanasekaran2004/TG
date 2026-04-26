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
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../features/ai_assistant/presentation/pages/ai_assistant_page.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_event.dart';
import '../../../social/profile/data/datasources/firebase_profile_datasource.dart';
import '../../../../features/notifications/presentation/pages/notifications_page.dart';
import '../../../../features/diary/presentation/pages/diary_page.dart';
import '../../../../features/help/presentation/pages/help_support_page.dart';
import '../../../../features/social/presentation/pages/friends_page.dart';
import '../../../../features/social/presentation/pages/private_feed_page.dart';
import '../../../../injection_container.dart' as di;
import 'delete_account_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  late Future<Map<String, dynamic>?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _refreshProfile();
  }

  void _refreshProfile() {
    final uid = _currentUser?.uid ?? '';
    _profileFuture = di.sl<FirebaseProfileDataSource>().getUserProfile(uid);
  }

  Future<void> _showEditProfileDialog(Map<String, dynamic> currentData) async {
    final nameCtrl = TextEditingController(text: currentData['name']?.toString() ?? '');
    final bioCtrl = TextEditingController(text: currentData['bio']?.toString() ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Display Name', prefixIcon: Icon(Icons.person_outline))),
          const SizedBox(height: 12),
          TextField(controller: bioCtrl, decoration: const InputDecoration(labelText: 'Bio', prefixIcon: Icon(Icons.edit_outlined)), maxLines: 2),
        ]),
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

    if (result == true && _currentUser != null) {
      await di.sl<FirebaseProfileDataSource>().updateUserProfile(
        uid: _currentUser.uid,
        updates: {'name': nameCtrl.text.trim(), 'bio': bioCtrl.text.trim()},
      );
      setState(() => _refreshProfile());
    }
  }

  Future<void> _signOut(BuildContext context) async {
    // Use AuthBloc to properly sign out — it updates the auth state stream
    // which triggers router redirect to login automatically
    context.read<AuthBloc>().add(SignOutRequested());
    if (!context.mounted) return;
    context.go('/login');
  }

  Future<void> _pickAndUploadPhoto() async {
    final uid = _currentUser?.uid;
    if (uid == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 300,
      maxHeight: 300,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 14),
          Text('Uploading photo...'),
        ]),
        duration: Duration(seconds: 10),
      ),
    );

    try {
      await di.sl<FirebaseProfileDataSource>().uploadProfilePicture(uid: uid, imageBytes: bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Profile photo updated!'), backgroundColor: Colors.green),
        );
        setState(() => _refreshProfile());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiAssistantFullPage())),
        backgroundColor: const Color(0xFF8E2DE2),
        icon: const Icon(Icons.smart_toy_outlined, color: Colors.white),
        label: const Text('Ask TripBot', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final profile = snapshot.data ?? {};
          final name = profile['name']?.toString() ?? _currentUser?.email?.split('@').first ?? 'Traveler';
          final email = profile['email']?.toString() ?? _currentUser?.email ?? '';
          final bio = profile['bio']?.toString() ?? 'Exploring the world one trip at a time! 🌍';
          final initial = name.isNotEmpty ? name[0].toUpperCase() : 'T';

          return SingleChildScrollView(
            child: Column(
              children: [
                // ── Profile Header ─────────────────────────
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, Color(0xFF8E2DE2)],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                    child: Column(children: [
                      GestureDetector(
                        onTap: _pickAndUploadPhoto,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            ProfileAvatar(
                              photoBase64: profile['photoBase64']?.toString(),
                              initial: initial,
                              radius: 48,
                              backgroundColor: Colors.white,
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                            ),
                          ],
                        ),
                      ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                      const SizedBox(height: 14),
                      Text(name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22))
                          .animate().fade(delay: 200.ms),
                      const SizedBox(height: 4),
                      Text(email,
                          style: const TextStyle(color: Colors.white70, fontSize: 14))
                          .animate().fade(delay: 300.ms),
                      const SizedBox(height: 8),
                      Text(bio,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white54, fontSize: 13))
                          .animate().fade(delay: 350.ms),
                      const SizedBox(height: 20),
                      // Show real stats (trips count from Firestore)
                      _RealProfileStats(uid: _currentUser?.uid ?? '').animate().fade(delay: 400.ms),
                    ]),
                  ),
                ),

                // ── Menu Items ─────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  child: Column(
                    children: [
                      const _SectionTitle('Account'),
                      _MenuItem(
                          icon: Icons.person_outline,
                          label: 'Edit Profile',
                          color: AppColors.primary,
                          onTap: () => _showEditProfileDialog(profile)),
                      _MenuItem(
                          icon: Icons.notifications_outlined,
                          label: 'Notifications',
                          color: AppColors.primary,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage()))),
                      const SizedBox(height: 16),
                      const _SectionTitle('My Content'),
                      _MenuItem(
                          icon: Icons.flight_takeoff_rounded,
                          label: 'My Trips',
                          color: AppColors.secondary,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _MyTripsPage(uid: _currentUser?.uid ?? '')))),
                      _MenuItem(
                          icon: Icons.book_outlined,
                          label: 'My Diary',
                          color: AppColors.secondary,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DiaryPage(standalone: true)))),
                      _MenuItem(
                          icon: Icons.lock_outline,
                          label: 'Private Posts',
                          color: AppColors.gold,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivateFeedPage()))),
                      _MenuItem(
                          icon: Icons.group_outlined,
                          label: 'Friends',
                          color: AppColors.cyan,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendsPage()))),
                      const SizedBox(height: 16),
                      const _SectionTitle('App'),
                      _MenuItem(
                          icon: Icons.smart_toy_outlined,
                          label: 'Ask TripBot AI',
                          color: const Color(0xFF8E2DE2),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiAssistantFullPage()))),
                      _MenuItem(icon: Icons.help_outline, label: 'Help & Support', color: const Color(0xFF8E2DE2),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportPage()))),
                      const SizedBox(height: 16),
                      const _SectionTitle('Danger Zone'),
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.red.withAlpha(45)),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const DeleteAccountPage())),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(children: [
                                Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.delete_forever_rounded, color: Colors.red, size: 20),
                                ),
                                SizedBox(width: 14),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('Delete Account',
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.red)),
                                    SizedBox(height: 2),
                                    Text('Permanently remove your account',
                                      style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w400)),
                                  ]),
                                ),
                                Icon(Icons.arrow_forward_ios, size: 14, color: Colors.red),
                              ]),
                            ),
                          ),
                        ),
                      ).animate().fade(delay: 650.ms),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _signOut(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: const Icon(Icons.logout, color: Colors.red),
                          label: const Text('Sign Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ).animate().fade(delay: 600.ms),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── My Trips Page ─────────────────────────────────────────
class _MyTripsPage extends StatelessWidget {
  final String uid;
  const _MyTripsPage({required this.uid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Trips'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new), onPressed: () => Navigator.pop(context)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('trips')
            .where('ownerId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.flight_takeoff_rounded, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No trips yet!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                SizedBox(height: 8),
                Text('Tap the + button on the Feed page to plan your first trip.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              ]),
            );
          }
          final trips = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final aT = (a.data() as Map)['createdAt'] as Timestamp?;
              final bT = (b.data() as Map)['createdAt'] as Timestamp?;
              if (aT == null || bT == null) return 0;
              return bT.compareTo(aT);
            });
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final data = trips[index].data() as Map<String, dynamic>;
              final title = data['destination']?.toString() ?? 'Untitled Trip';
              final source = data['source']?.toString() ?? 'Origin';
              final budget = '₹${data['budget']?.toString() ?? '0'}';
              final category = data['category']?.toString() ?? 'Adventure';
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.primary.withAlpha(20), shape: BoxShape.circle),
                    child: const Icon(Icons.flight_takeoff_rounded, color: AppColors.primary, size: 22),
                  ),
                  title: Text('$source → $title', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: Text('$category · $budget', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Real Stats Widget: Reads trip count from Firestore ──
class _RealProfileStats extends StatelessWidget {
  final String uid;
  const _RealProfileStats({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('trips')
          .where('ownerId', isEqualTo: uid)
          .snapshots(),
      builder: (ctx, snap) {
        final tripCount = snap.data?.docs.length ?? 0;
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
          builder: (ctx2, userSnap) {
            final userData = (userSnap.data?.data() as Map<String, dynamic>?) ?? {};
            final followers = userData['followersCount'] ?? 0;
            final following = userData['followingCount'] ?? 0;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ProfileStat(count: '$tripCount', label: 'Trips'),
                _ProfileStat(count: '$followers', label: 'Followers'),
                _ProfileStat(count: '$following', label: 'Following'),
              ],
            );
          },
        );
      },
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String count, label;
  const _ProfileStat({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(count, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ]);
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15))),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ]),
          ),
        ),
      ),
    );
  }
}
