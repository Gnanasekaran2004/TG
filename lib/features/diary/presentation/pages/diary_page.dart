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
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/base64_cache.dart';
import '../../../../injection_container.dart' as di;
import '../../../social/data/datasources/firebase_trip_datasource.dart';

// ─────────────────────────────────────────────────────
// Data Models & Extensions
// ─────────────────────────────────────────────────────

enum DiaryMood { happy, excited, tired, peaceful, adventurous }

enum DiaryWeather { sunny, cloudy, rainy, windy, snowy }

extension MoodExt on DiaryMood {
  String get label => const {
    DiaryMood.happy: 'Happy',
    DiaryMood.excited: 'Excited',
    DiaryMood.tired: 'Tired',
    DiaryMood.peaceful: 'Peaceful',
    DiaryMood.adventurous: 'Adventurous',
  }[this]!;

  IconData get icon => const {
    DiaryMood.happy: Icons.sentiment_satisfied_alt,
    DiaryMood.excited: Icons.celebration_outlined,
    DiaryMood.tired: Icons.bedtime_outlined,
    DiaryMood.peaceful: Icons.spa_outlined,
    DiaryMood.adventurous: Icons.terrain,
  }[this]!;

  Color get color => const {
    DiaryMood.happy: Color(0xFFf7971e),
    DiaryMood.excited: Color(0xFFFF6584),
    DiaryMood.tired: Color(0xFF8E2DE2),
    DiaryMood.peaceful: Color(0xFF11998e),
    DiaryMood.adventurous: Color(0xFF6C63FF),
  }[this]!;
}

extension WeatherExt on DiaryWeather {
  String get label => const {
    DiaryWeather.sunny: 'Sunny',
    DiaryWeather.cloudy: 'Cloudy',
    DiaryWeather.rainy: 'Rainy',
    DiaryWeather.windy: 'Windy',
    DiaryWeather.snowy: 'Snowy',
  }[this]!;

  IconData get icon => const {
    DiaryWeather.sunny: Icons.wb_sunny_outlined,
    DiaryWeather.cloudy: Icons.cloud_outlined,
    DiaryWeather.rainy: Icons.water_drop_outlined,
    DiaryWeather.windy: Icons.air,
    DiaryWeather.snowy: Icons.ac_unit,
  }[this]!;

  Color get color => const {
    DiaryWeather.sunny: Color(0xFFf7971e),
    DiaryWeather.cloudy: Colors.blueGrey,
    DiaryWeather.rainy: Color(0xFF6C63FF),
    DiaryWeather.windy: Color(0xFF11998e),
    DiaryWeather.snowy: Colors.lightBlue,
  }[this]!;
}

// ─────────────────────────────────────────────────────
// Main Page
// ─────────────────────────────────────────────────────

class DiaryPage extends StatefulWidget {
  /// Set to true when opened from Profile page (shows AppBar + back button).
  final bool standalone;
  const DiaryPage({super.key, this.standalone = false});

  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  int _selectedTripIndex = 0;
  final Set<String> _expandedEntries = {};
  late final Stream<QuerySnapshot> _userTripsStream;

  @override
  void initState() {
    super.initState();
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    // Use a simple orderBy-free query to avoid Firestore composite index requirement.
    // Sorting is done client-side.
    _userTripsStream = FirebaseFirestore.instance
        .collection('trips')
        .where('ownerId', isEqualTo: userId)
        .snapshots();
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _deleteEntry(String tripId, String entryId) {
    FirebaseFirestore.instance
        .collection('trips')
        .doc(tripId)
        .collection('entries')
        .doc(entryId)
        .delete();
    _showSnack('Entry deleted');
  }

  void _confirmDelete(String tripId, String entryId, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Entry?'),
        content: Text('Remove "$title" from your diary?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteEntry(tripId, entryId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  List<Color> _getGradient(String category) {
    if (category == 'Beach') {
      return const [Color(0xFFFF6584), Color(0xFFFF8C42)];
    }
    if (category == 'Cultural') {
      return const [Color(0xFF8E2DE2), Color(0xFF4A00E0)];
    }
    if (category == 'Road Trip') {
      return const [Color(0xFFf7971e), Color(0xFFffd200)];
    }
    if (category == 'Cruise') {
      return const [Color(0xFF11998e), Color(0xFF38ef7d)];
    }
    if (category == 'Business') {
      return const [Color(0xFF2C3E50), Color(0xFF3498DB)];
    }
    return const [Color(0xFF6C63FF), Color(0xFF8E2DE2)]; // Default Adventure
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: widget.standalone
          ? AppBar(
              title: const Text(
                'Travel Diary',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: StreamBuilder<QuerySnapshot>(
        stream: _userTripsStream,
        builder: (context, tripSnapshot) {
          // ─── THE MISSING ERROR BLOCK ───
          if (tripSnapshot.hasError) {
            // This forces the magic link to print in your Chrome Console!
            debugPrint('🔥 FIRESTORE INDEX ERROR: ${tripSnapshot.error}');
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'Database Index Required!\n\nPlease open your Chrome Developer Console (F12) and click the blue link to build the index.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }
          // ───────────────────────────────

          if (tripSnapshot.connectionState == ConnectionState.waiting &&
              !tripSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (!tripSnapshot.hasData || tripSnapshot.data!.docs.isEmpty) {
            return _EmptyDiary(
              onAdd: () {
                // Try to go back to root (main shell) which lands on Feed
                // Works whether opened from nav bar or from ProfilePage
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            );
          }

          // Sort client-side by createdAt DESC (no Firestore composite index needed)
          final trips = tripSnapshot.data!.docs.toList()
            ..sort((a, b) {
              final aT = (a.data() as Map)['createdAt'] as Timestamp?;
              final bT = (b.data() as Map)['createdAt'] as Timestamp?;
              if (aT == null || bT == null) return 0;
              return bT.compareTo(aT);
            });

          // Safety check in case a trip is deleted
          if (_selectedTripIndex >= trips.length) {
            _selectedTripIndex = 0;
          }

          final currentTripDoc = trips[_selectedTripIndex];
          final tripData = currentTripDoc.data() as Map<String, dynamic>;
          final tripId = currentTripDoc.id;
          final tripGradient = _getGradient(
            tripData['category']?.toString() ?? '',
          );

          return Column(
            children: [
              // ── 1. Trip Horizontal Selector ──────────────────────────
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  itemCount: trips.length + 1,
                  itemBuilder: (context, i) {
                    if (i == trips.length) {
                      return _AddTripChip(
                        onTap: () => Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst),
                      );
                    }

                    final tData = trips[i].data() as Map<String, dynamic>;
                    final isSelected = i == _selectedTripIndex;
                    final grad = _getGradient(
                      tData['category']?.toString() ?? '',
                    );

                    return GestureDetector(
                      onTap: () => setState(() => _selectedTripIndex = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(colors: grad)
                              : null,
                          color: isSelected
                              ? null
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: grad.first.withAlpha(80),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              tData['title']?.toString() ?? 'Unnamed Trip',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tData['destination']?.toString() ?? 'Unknown',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white70
                                    : Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── 2. Inner Stream for Diary Entries ──────────────────────
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: di.sl<FirebaseTripDataSource>().streamTripEntries(
                    tripId,
                  ),
                  builder: (context, entrySnapshot) {
                    final entries = entrySnapshot.data?.docs ?? [];

                    return Column(
                      children: [
                        // Trip Stats Banner (Now has live entry count)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _TripStatsBanner(
                            title: tripData['title']?.toString() ?? 'Trip',
                            gradient: tripGradient,
                            entryCount: entries.length,
                            photoCount: entries.where((d) {
                              final b = (d.data() as Map<String, dynamic>)['imageBase64'];
                              return b != null && (b as String).isNotEmpty;
                            }).length,
                          ),
                        ).animate().fade(duration: 300.ms),

                        const SizedBox(height: 8),

                        // Timeline Entries
                        Expanded(
                          child: entries.isEmpty
                              ? _EmptyDiaryEntries(
                                  onAdd: () => _openAddEntrySheet(
                                    tripId,
                                    tripData['title']?.toString() ?? 'Trip',
                                    entries.length + 1,
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    4,
                                    16,
                                    100,
                                  ),
                                  itemCount: entries.length,
                                  itemBuilder: (context, index) {
                                    final entryDoc = entries[index];
                                    final entryData =
                                        entryDoc.data() as Map<String, dynamic>;
                                    final isLast = index == entries.length - 1;
                                    final isExpanded = _expandedEntries
                                        .contains(entryDoc.id);

                                    return _DiaryEntryCard(
                                      entryId: entryDoc.id,
                                      entryData: entryData,
                                      isLast: isLast,
                                      isExpanded: isExpanded,
                                      tripGradient: tripGradient,
                                      onExpand: () => setState(() {
                                        if (isExpanded) {
                                          _expandedEntries.remove(entryDoc.id);
                                        } else {
                                          _expandedEntries.add(entryDoc.id);
                                        }
                                      }),
                                      onDelete: () => _confirmDelete(
                                        tripId,
                                        entryDoc.id,
                                        entryData['dayLabel'] ?? 'Entry',
                                      ),
                                      animationDelay: (index * 80).ms,
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: StreamBuilder<QuerySnapshot>(
        stream: _userTripsStream,
        builder: (context, snapshot) {
          // Only show FAB if user has at least one trip
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const SizedBox();
          }

          return FloatingActionButton.extended(
            onPressed: () {
              final trips = snapshot.data!.docs;
              if (_selectedTripIndex < trips.length) {
                final doc = trips[_selectedTripIndex];
                _openAddEntrySheet(
                  doc.id,
                  (doc.data() as Map<String, dynamic>)['title'] ?? 'Trip',
                  1,
                );
              }
            },
            backgroundColor: AppColors.secondary,
            icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
            label: const Text(
              'New Entry',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
    );
  }

  void _openAddEntrySheet(String tripId, String tripTitle, int newEntryNum) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEntrySheet(
        tripId: tripId,
        tripTitle: tripTitle,
        entryNumber: newEntryNum,
        onSaveSuccess: () =>
            _showSnack('Entry added to $tripTitle!', success: true),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Trip Stats Banner
// ─────────────────────────────────────────────────────

class _TripStatsBanner extends StatelessWidget {
  final String title;
  final List<Color> gradient;
  final int entryCount;
  final int photoCount;

  const _TripStatsBanner({
    required this.title,
    required this.gradient,
    required this.entryCount,
    required this.photoCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                const Text(
                  'Live Cloud Diary',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          _Stat(
            value: '$entryCount',
            label: 'Entries',
            icon: Icons.edit_outlined,
          ),
          const SizedBox(width: 16),
          _Stat(
            value: '$photoCount',
            label: 'Photos',
            icon: Icons.photo_outlined,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value, label;
  final IconData icon;
  const _Stat({required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 10),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────
// Diary Entry Card
// ─────────────────────────────────────────────────────

class _DiaryEntryCard extends StatelessWidget {
  final String entryId;
  final Map<String, dynamic> entryData;
  final bool isLast, isExpanded;
  final List<Color> tripGradient;
  final VoidCallback onExpand, onDelete;
  final Duration animationDelay;

  const _DiaryEntryCard({
    required this.entryId,
    required this.entryData,
    required this.isLast,
    required this.isExpanded,
    required this.tripGradient,
    required this.onExpand,
    required this.onDelete,
    required this.animationDelay,
  });

  @override
  Widget build(BuildContext context) {
    // Parse enums safely
    final moodStr = entryData['mood']?.toString() ?? 'happy';
    final mood = DiaryMood.values.firstWhere(
      (e) => e.name == moodStr,
      orElse: () => DiaryMood.happy,
    );

    final weatherStr = entryData['weather']?.toString() ?? 'sunny';
    final weather = DiaryWeather.values.firstWhere(
      (e) => e.name == weatherStr,
      orElse: () => DiaryWeather.sunny,
    );

    return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Spine
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: tripGradient),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: tripGradient.first.withAlpha(80),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(mood.icon, size: 11, color: Colors.white),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: isExpanded ? null : 120,
                      color: Colors.grey.withAlpha(50),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Card
            Expanded(
              child: GestureDetector(
                onTap: onExpand,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(10),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Card header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entryData['dayLabel']?.toString() ??
                                        'Entry',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_outlined,
                                        size: 12,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        entryData['location']?.toString() ??
                                            'Location',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        entryData['date']?.toString() ?? '',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: Colors.grey,
                              ),
                              onPressed: onDelete,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),

                      // Mood & Weather chips
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            _Chip(
                              icon: mood.icon,
                              label: mood.label,
                              color: mood.color,
                            ),
                            const SizedBox(width: 8),
                            _Chip(
                              icon: weather.icon,
                              label: weather.label,
                              color: weather.color,
                            ),
                          ],
                        ),
                      ),

                      // Content
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: Text(
                          entryData['content']?.toString() ?? '',
                          maxLines: isExpanded ? null : 2,
                          overflow: isExpanded ? null : TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withAlpha(220),
                          ),
                        ),
                      ),

                      // ── Photo (only visible when card is expanded) ──────────
                      if (isExpanded)
                        _EntryPhoto(
                          base64: entryData['imageBase64']?.toString(),
                        ),

                      // Expand hint
                      if (!isExpanded)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                          child: Text(
                            'Tap to read more...',
                            style: TextStyle(
                              color: tripGradient.first,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ],
        )
        .animate()
        .fade(delay: animationDelay, duration: 350.ms)
        .slideX(begin: 0.06, end: 0, curve: Curves.easeOut);
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Entry Photo — shown when a diary card is expanded
// ─────────────────────────────────────────────────────

class _EntryPhoto extends StatelessWidget {
  final String? base64;
  const _EntryPhoto({this.base64});

  @override
  Widget build(BuildContext context) {
    // PERF: Use the global Base64Cache — avoids re-decoding the same image
    // bytes on every rebuild while the card is expanded during scroll.
    final Uint8List? bytes = Base64Cache.decode(base64);
    if (bytes == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.memory(
          bytes,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      )
          .animate()
          .fade(duration: 350.ms)
          .scale(
            begin: const Offset(0.95, 0.95),
            end: const Offset(1, 1),
            curve: Curves.easeOut,
          ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Add Entry Bottom Sheet
// ─────────────────────────────────────────────────────

class _AddEntrySheet extends StatefulWidget {
  final String tripId;
  final String tripTitle;
  final int entryNumber;
  final VoidCallback onSaveSuccess;

  const _AddEntrySheet({
    required this.tripId,
    required this.tripTitle,
    required this.entryNumber,
    required this.onSaveSuccess,
  });

  @override
  State<_AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<_AddEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _contentController = TextEditingController();

  DiaryMood _mood = DiaryMood.happy;
  DiaryWeather _weather = DiaryWeather.sunny;
  DateTime _date = DateTime.now();
  bool _isSubmitting = false;

  // ── Strict 1-image-per-entry rule ─────────────────────────────────────────
  File?   _imageFile;       // local file preview
  String? _imageBase64;     // base64 string persisted to Firestore
  bool    _isPickingImage = false;

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // Picks exactly ONE image from gallery (enforced by ImagePicker single-select).
  Future<void> _pickImage() async {
    if (_isPickingImage) return; // debounce double-taps
    setState(() => _isPickingImage = true);
    try {
      final picked = await ImagePicker().pickImage(
        source:       ImageSource.gallery,
        maxWidth:     900,
        maxHeight:    900,
        imageQuality: 75,
      );
      if (picked == null) return; // user cancelled
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageFile   = File(picked.path);
        _imageBase64 = base64Encode(bytes);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not pick image — please try again.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  // Removes the selected image (user must remove before picking a different one).
  void _removeImage() => setState(() {
    _imageFile   = null;
    _imageBase64 = null;
  });

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} / ${d.month.toString().padLeft(2, '0')} / ${d.year}';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final entryData = {
      'dayLabel':    _titleController.text.trim(),
      'date':        _formatDate(_date),
      'location':    _locationController.text.trim(),
      'content':     _contentController.text.trim(),
      'mood':        _mood.name,
      'weather':     _weather.name,
      'imageBase64': _imageBase64 ?? '', // '' = no photo attached
      'createdAt':   FieldValue.serverTimestamp(),
    };

    try {
      await di.sl<FirebaseTripDataSource>().addDiaryEntry(
        widget.tripId,
        entryData,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSaveSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save entry'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, Color(0xFF8E2DE2)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.edit_note_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'New Diary Entry',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.tripTitle,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 20),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Title required' : null,
                      decoration: _fieldDeco(
                        context,
                        'Day title (e.g. "Day 1 - Arrival")',
                        Icons.title,
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _locationController,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Location required' : null,
                      decoration: _fieldDeco(
                        context,
                        'Location (e.g. Paris, France)',
                        Icons.location_on_outlined,
                      ),
                    ),
                    const SizedBox(height: 12),

                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.primary.withAlpha(80),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              color: AppColors.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _formatDate(_date),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'How did you feel?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: DiaryMood.values.map((m) {
                        final sel = _mood == m;
                        return GestureDetector(
                          onTap: () => setState(() => _mood = m),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: sel
                                  ? m.color.withAlpha(30)
                                  : Colors.grey.withAlpha(15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: sel ? m.color : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  m.icon,
                                  size: 16,
                                  color: sel ? m.color : Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  m.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: sel ? m.color : Colors.grey,
                                    fontWeight: sel
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Weather today?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: DiaryWeather.values.map((w) {
                        final sel = _weather == w;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _weather = w),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: EdgeInsets.only(
                                right: w != DiaryWeather.snowy ? 6 : 0,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: sel
                                    ? w.color.withAlpha(25)
                                    : Colors.grey.withAlpha(12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: sel ? w.color : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    w.icon,
                                    size: 20,
                                    color: sel ? w.color : Colors.grey,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    w.label,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: sel ? w.color : Colors.grey,
                                      fontWeight: sel
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _contentController,
                      maxLines: 5,
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Write something about today'
                          : null,
                      decoration: _fieldDeco(
                        context,
                        'Write your diary entry... What happened today? How did you feel?',
                        Icons.notes_outlined,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Photo Upload — strict 1 image per entry ───────────────
                    _imageFile == null
                        ? GestureDetector(
                            onTap: _isPickingImage ? null : _pickImage,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.primary.withAlpha(80),
                                  width: 1.5,
                                ),
                              ),
                              child: _isPickingImage
                                  ? const Center(
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    )
                                  : const Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.add_photo_alternate_outlined,
                                          color: AppColors.primary,
                                          size: 30,
                                        ),
                                        SizedBox(height: 7),
                                        Text(
                                          'Upload Photo',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'One photo per entry',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          )
                        : Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.file(
                                  _imageFile!,
                                  width: double.infinity,
                                  height: 180,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              // ✓ badge — top left
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(150),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle_rounded,
                                          color: Color(0xFF1DBF73), size: 13),
                                      SizedBox(width: 5),
                                      Text(
                                        'Photo added',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // ✕ remove button — top right
                              Positioned(
                                top: 6,
                                right: 6,
                                child: GestureDetector(
                                  onTap: _removeImage,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withAlpha(230),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(60),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ).animate().scale(
                              duration: 280.ms,
                              curve: Curves.easeOutBack),

                    const SizedBox(height: 20),

                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline, size: 20),
                        label: const Text(
                          'Save Entry',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDeco(BuildContext context, String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Empty States
// ─────────────────────────────────────────────────────

class _EmptyDiary extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyDiary({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.flight_takeoff_rounded,
              size: 56,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Trips Yet',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(height: 8),
          const Text(
            'You need to create a trip before writing a diary!',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.arrow_back),
            label: const Text(
              'Go to Feed to Add a Trip',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDiaryEntries extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyDiaryEntries({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_stories_outlined,
            size: 48,
            color: Colors.grey.withAlpha(100),
          ),
          const SizedBox(height: 16),
          const Text(
            'No entries for this trip yet.',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, color: AppColors.primary),
            label: const Text(
              'Write the first entry',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTripChip extends StatelessWidget {
  final VoidCallback onTap;
  const _AddTripChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary.withAlpha(80), width: 2),
          borderRadius: BorderRadius.circular(16),
          color: AppColors.primary.withAlpha(10),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, color: AppColors.primary, size: 22),
            SizedBox(height: 4),
            Text(
              'Use the Feed',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
