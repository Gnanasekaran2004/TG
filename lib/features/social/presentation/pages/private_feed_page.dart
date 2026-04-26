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
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/colors.dart';
import '../../../../injection_container.dart' as di;
import '../../data/datasources/firebase_trip_datasource.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Private Feed Page — only shows visibility:'private' posts owned by the user
// ─────────────────────────────────────────────────────────────────────────────

class PrivateFeedPage extends StatelessWidget {
  const PrivateFeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2453E0), Color(0xFF4272FF)],
            ),
          ),
          child: SafeArea(
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Private Posts',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: di.sl<FirebaseTripDataSource>().streamPrivateTrips(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_outline, size: 52, color: AppColors.primary.withAlpha(100)),
                ),
                const SizedBox(height: 20),
                const Text('No private posts yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'When you post a trip with "Private" visibility, it will only be visible here — to you.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
                  ),
                ),
              ]),
            );
          }

          // Sort client-side by createdAt desc (no composite index needed)
          final trips = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final aT = (a.data() as Map)['createdAt'] as Timestamp?;
              final bT = (b.data() as Map)['createdAt'] as Timestamp?;
              if (aT == null || bT == null) return 0;
              return bT.compareTo(aT);
            });

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final data = trips[index].data() as Map<String, dynamic>;
              return _PrivateTripCard(
                docId: trips[index].id,
                data: data,
              ).animate(delay: (index * 50).ms).fade(duration: 280.ms).slideY(begin: 0.05);
            },
          );
        },
      ),
    );
  }
}

// ── Private Trip Card ──────────────────────────────────────────────────────

class _PrivateTripCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;

  const _PrivateTripCard({required this.docId, required this.data});

  @override
  Widget build(BuildContext context) {
    final destination = data['destination']?.toString() ?? 'Destination';
    final source = data['source']?.toString() ?? 'Origin';
    final category = data['category']?.toString() ?? 'Adventure';
    final budget = '₹${data['budget']?.toString() ?? '0'}';
    final description = data['description']?.toString() ??
        data['title']?.toString() ?? 'A private trip memory.';

    final createdAt = data['createdAt'] as Timestamp?;
    final dateStr = createdAt != null
        ? '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF2453E0), Color(0xFF4272FF)]),
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Row(children: [
            const Icon(Icons.lock_outline, color: Colors.white70, size: 14),
            const SizedBox(width: 6),
            Text('$source  →  $destination',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            _VisibilityChip(label: 'Private', icon: Icons.lock_outline, color: Colors.white70),
          ]),
        ),

        // ── Content
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(category, style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.gold.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(budget, style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              if (dateStr.isNotEmpty)
                Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ]),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.black87)),
            ],

            // ── Delete button
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Private Post?'),
                      content: const Text('This action cannot be undone.'),
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
                    await di.sl<FirebaseTripDataSource>().deleteTrip(docId);
                  }
                },
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                label: const Text('Delete', style: TextStyle(color: Colors.red, fontSize: 12)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Visibility badge chip ──────────────────────────────────────────────────

class _VisibilityChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _VisibilityChip({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
    ]);
  }
}
