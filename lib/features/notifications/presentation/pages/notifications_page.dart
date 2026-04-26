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
import '../../../../injection_container.dart' as di;
import '../../data/datasources/firebase_notification_datasource.dart';

// ─── Notification Type ────────────────────────────────
enum _NotifType { trip, friend, system }

_NotifType _typeFromString(String? s) {
  switch (s) {
    case 'trip': return _NotifType.trip;
    case 'friend': return _NotifType.friend;
    default: return _NotifType.system;
  }
}

// ─── Page ─────────────────────────────────────────────
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  String _filter = 'All';
  late final FirebaseNotificationDataSource _dataSource;

  @override
  void initState() {
    super.initState();
    _dataSource = di.sl<FirebaseNotificationDataSource>();
  }

  List<QueryDocumentSnapshot> _applyFilter(List<QueryDocumentSnapshot> docs) {
    if (_filter == 'Unread') {
      return docs.where((d) {
        final data = d.data() as Map<String, dynamic>;
        return data['read'] != true;
      }).toList();
    }
    if (_filter == 'Trips') {
      return docs.where((d) {
        final data = d.data() as Map<String, dynamic>;
        return data['type'] == 'trip';
      }).toList();
    }
    return docs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<QuerySnapshot>(
          stream: _dataSource.streamNotifications(),
          builder: (context, snap) {
            final unread = snap.hasData
                ? snap.data!.docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return data['read'] != true;
                  }).length
                : 0;

            return Row(children: [
              const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
              if (unread > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                  child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ]);
          },
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _dataSource.markAllAsRead();
            },
            child: const Text('Mark all read', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Column(children: [
        // ── Filter Chips ──────────────────────────────
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final label in ['All', 'Unread', 'Trips'])
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                child: ChoiceChip(
                  label: Text(label),
                  selected: _filter == label,
                  onSelected: (_) => setState(() => _filter = label),
                  selectedColor: AppColors.primary.withAlpha(30),
                  labelStyle: TextStyle(
                    color: _filter == label ? AppColors.primary : Theme.of(context).colorScheme.onSurface,
                    fontWeight: _filter == label ? FontWeight.w700 : FontWeight.normal,
                  ),
                  side: BorderSide(color: _filter == label ? AppColors.primary : Colors.grey.withAlpha(60)),
                ),
              ),
          ]),
        ),
        const Divider(height: 1),

        // ── Notification List (Live from Firestore) ───
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _dataSource.streamNotifications(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              // Sort newest-first on the client (no index required)
              final allDocs = List<QueryDocumentSnapshot>.from(snapshot.data?.docs ?? [])
                ..sort((a, b) {
                  final aT = (a.data() as Map)['createdAt'];
                  final bT = (b.data() as Map)['createdAt'];
                  if (aT == null && bT == null) return 0;
                  if (aT == null) return 1;
                  if (bT == null) return -1;
                  return (bT as Timestamp).compareTo(aT as Timestamp);
                });
              final filtered = _applyFilter(allDocs);

              if (filtered.isEmpty) {
                return Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.notifications_none_outlined, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text('No notifications', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                  ]),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
                itemBuilder: (ctx, i) {
                  final doc = filtered[i];
                  final data = doc.data() as Map<String, dynamic>;
                  return Dismissible(
                    key: Key(doc.id),
                    onDismissed: (_) => _dataSource.deleteNotification(doc.id),
                    background: Container(
                      color: Colors.red.withAlpha(30),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      child: const Icon(Icons.delete_outline, color: Colors.red),
                    ),
                    child: _NotifTile(
                      data: data,
                      onTap: () => _dataSource.markAsRead(doc.id),
                    ),
                  ).animate().fadeIn(delay: (i * 30).ms).slideX(begin: 0.05, end: 0);
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ─── Tile ─────────────────────────────────────────────
class _NotifTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  const _NotifTile({required this.data, required this.onTap});

  _NotifType get _type => _typeFromString(data['type']?.toString());
  bool get _read => data['read'] == true;
  String get _title => data['title']?.toString() ?? 'Notification';
  String get _body => data['body']?.toString() ?? '';
  String get _timeAgo {
    final ts = data['createdAt'];
    if (ts == null) return 'Just now';
    final dt = (ts as Timestamp).toDate();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  IconData get _icon => switch (_type) {
    _NotifType.trip => Icons.luggage_outlined,
    _NotifType.friend => Icons.person_outline,
    _NotifType.system => Icons.campaign_outlined,
  };

  Color get _color => switch (_type) {
    _NotifType.trip => AppColors.primary,
    _NotifType.friend => AppColors.secondary,
    _NotifType.system => const Color(0xFFf7971e),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        color: _read ? Colors.transparent : _color.withAlpha(10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: _color.withAlpha(20), shape: BoxShape.circle),
            child: Icon(_icon, color: _color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(_title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: _read ? FontWeight.normal : FontWeight.bold))),
              if (!_read)
                Container(width: 8, height: 8, decoration: BoxDecoration(color: _color, shape: BoxShape.circle)),
            ]),
            const SizedBox(height: 3),
            Text(_body, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha(160)), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(_timeAgo, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          ])),
        ]),
      ),
    );
  }
}
