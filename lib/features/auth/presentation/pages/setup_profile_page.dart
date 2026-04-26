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
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/colors.dart';
import '../../../../injection_container.dart' as di;
import '../../../social/profile/data/datasources/firebase_profile_datasource.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Setup Profile Page
// Shown to new users right after OTP verification.
// On completion, sets profileComplete:true and navigates to /home.
// ─────────────────────────────────────────────────────────────────────────────

class SetupProfilePage extends StatefulWidget {
  final String prefilledName;
  const SetupProfilePage({super.key, this.prefilledName = ''});

  @override
  State<SetupProfilePage> createState() => _SetupProfilePageState();
}

class _SetupProfilePageState extends State<SetupProfilePage> {
  final _formKey       = GlobalKey<FormState>();
  final _nameCtrl      = TextEditingController();
  final _usernameCtrl  = TextEditingController();
  final _taglineCtrl   = TextEditingController();
  final _cityCtrl      = TextEditingController();
  final _bioCtrl       = TextEditingController();
  final _scrollCtrl    = ScrollController();

  // Photo
  File?   _photoFile;
  String? _photoBase64;

  // Pickers
  DateTime? _dob;
  String?   _gender;
  String?   _travelStyle;

  // Multi-select interests
  final Set<String> _interests = {};

  // Username check
  bool?  _usernameAvailable;
  bool   _checkingUsername = false;
  Timer? _usernameDebounce;

  // Submission
  bool _isSaving = false;

  // ── Options ───────────────────────────────────────────────────────────────
  static const _genders      = ['Male', 'Female', 'Non-binary', 'Prefer not to say'];
  static const _travelStyles = ['Solo', 'Couple', 'Group', 'Family'];
  static const _interestOptions = [
    ('🏔️', 'Adventure'), ('🏖️', 'Beach'),    ('🏛️', 'Cultural'),
    ('🍜', 'Food'),       ('🌿', 'Nature'),    ('🏙️', 'City Life'),
    ('🚢', 'Cruise'),     ('💼', 'Business'),  ('📸', 'Photography'),
    ('🎭', 'Nightlife'),  ('🧘', 'Wellness'),  ('🎿', 'Winter Sports'),
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.prefilledName.isNotEmpty
        ? widget.prefilledName
        : FirebaseAuth.instance.currentUser?.displayName ?? '';
    _usernameCtrl.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _usernameCtrl.dispose(); _taglineCtrl.dispose();
    _cityCtrl.dispose(); _bioCtrl.dispose();      _scrollCtrl.dispose();
    _usernameDebounce?.cancel();
    super.dispose();
  }

  // ── Username uniqueness check ─────────────────────────────────────────────

  void _onUsernameChanged() {
    _usernameDebounce?.cancel();
    final val = _usernameCtrl.text.trim().toLowerCase();
    if (val.isEmpty) { setState(() => _usernameAvailable = null); return; }
    setState(() { _usernameAvailable = null; _checkingUsername = true; });
    _usernameDebounce = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: val)
            .limit(1)
            .get();
        if (mounted) {
          setState(() {
            _usernameAvailable = snap.docs.isEmpty;
            _checkingUsername  = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _checkingUsername = false);
      }
    });
  }

  // ── Photo picker ─────────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 400, maxHeight: 400, imageQuality: 75,
    );
    if (picked == null) return;
    final bytes  = await picked.readAsBytes();
    setState(() {
      _photoFile   = File(picked.path);
      _photoBase64 = base64Encode(bytes);
    });
  }

  // ── Date picker ──────────────────────────────────────────────────────────

  Future<void> _pickDob() async {
    final now    = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 13, now.month, now.day),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary, onSurface: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  String _formatDob(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} / ${d.month.toString().padLeft(2, '0')} / ${d.year}';

  // ── Snack ────────────────────────────────────────────────────────────────

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_usernameAvailable == false) {
      _snack('Username is already taken.', error: true); return;
    }
    if (_dob == null) {
      _snack('Please select your date of birth.', error: true); return;
    }
    if (_gender == null) {
      _snack('Please select your gender.', error: true); return;
    }
    if (_interests.isEmpty) {
      _snack('Select at least one travel interest.', error: true); return;
    }

    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final ds  = di.sl<FirebaseProfileDataSource>();

      // Upload photo if selected
      if (_photoBase64 != null) {
        final bytes = base64Decode(_photoBase64!);
        await ds.uploadProfilePicture(uid: uid, imageBytes: bytes);
      }

      // Save all profile fields
      await ds.updateUserProfile(uid: uid, updates: {
        'name':            _nameCtrl.text.trim(),
        'username':        _usernameCtrl.text.trim().toLowerCase(),
        'tagline':         _taglineCtrl.text.trim(),
        'city':            _cityCtrl.text.trim(),
        'bio':             _bioCtrl.text.trim(),
        'dateOfBirth':     _formatDob(_dob!),
        'gender':          _gender,
        'travelStyle':     _travelStyle ?? 'Solo',
        'interests':       _interests.toList(),
        'profileComplete': true,
        'updatedAt':       FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _snack('Profile set up! Welcome to Trip-GUY 🎉');
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _snack('Failed to save: ${e.toString().replaceAll('Exception: ', '')}', error: true);
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        // ── Background ────────────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF0D1224), Color(0xFF1B2A5A), Color(0xFF0D1224)],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
        // Decorative orbs
        Positioned(top: -60, right: -60,
          child: Container(width: 240, height: 240,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(30), shape: BoxShape.circle))),
        Positioned(bottom: 80, left: -80,
          child: Container(width: 280, height: 280,
            decoration: BoxDecoration(
              color: const Color(0xFF8E2DE2).withAlpha(20), shape: BoxShape.circle))),

        SafeArea(
          child: Form(
            key: _formKey,
            child: CustomScrollView(
              controller: _scrollCtrl,
              slivers: [

                // ── Header ──────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: Column(children: [
                      // Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(40),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withAlpha(80)),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 14),
                          SizedBox(width: 6),
                          Text('One-time Setup', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                        ]),
                      ).animate().fade(duration: 400.ms),
                      const SizedBox(height: 14),
                      const Text('Set Up Your Profile ✨',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                        textAlign: TextAlign.center,
                      ).animate().fade(delay: 100.ms).slideY(begin: 0.2),
                      const SizedBox(height: 6),
                      Text('Tell the world who you are, traveller! 🌏',
                        style: TextStyle(fontSize: 13, color: Colors.white.withAlpha(160)),
                        textAlign: TextAlign.center,
                      ).animate().fade(delay: 200.ms),
                    ]),
                  ),
                ),

                // ── Avatar picker ────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Center(
                    child: GestureDetector(
                      onTap: _pickPhoto,
                      child: Stack(alignment: Alignment.center, children: [
                        // Glow ring
                        Container(
                          width: 110, height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const SweepGradient(colors: [
                              AppColors.primary, Color(0xFF8E2DE2),
                              Color(0xFFFF7E42), AppColors.primary
                            ]),
                          ),
                        ),
                        Container(
                          width: 104, height: 104,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0D1224), shape: BoxShape.circle),
                        ),
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: Colors.white.withAlpha(20),
                          backgroundImage: _photoFile != null
                              ? FileImage(_photoFile!) as ImageProvider : null,
                          child: _photoFile == null
                              ? const Icon(Icons.person_outline_rounded,
                                  color: Colors.white70, size: 44)
                              : null,
                        ),
                        // Edit overlay
                        Positioned(bottom: 0, right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [AppColors.primary, Color(0xFF8E2DE2)]),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                      ]),
                    ).animate().scale(delay: 300.ms, duration: 500.ms, curve: Curves.easeOutBack),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                SliverToBoxAdapter(
                  child: Center(
                    child: Text('Tap to add photo',
                      style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 12)),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // ── Section: Identity ────────────────────────────────────
                _sectionCard(
                  delay: 400,
                  icon: Icons.badge_outlined,
                  title: 'Your Identity',
                  child: Column(children: [
                    // Display Name
                    _glassField(
                      controller: _nameCtrl,
                      hint: 'Display Name',
                      icon: Icons.person_outline,
                      validator: (v) => v!.trim().isEmpty ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    // Username
                    _glassField(
                      controller: _usernameCtrl,
                      hint: 'Username (e.g. wanderer_raj)',
                      icon: Icons.alternate_email_rounded,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_.]')),
                        LengthLimitingTextInputFormatter(30),
                      ],
                      validator: (v) {
                        if (v!.trim().isEmpty) return 'Username is required';
                        if (v.trim().length < 3) return 'At least 3 characters';
                        return null;
                      },
                      suffix: _checkingUsername
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54))
                          : _usernameAvailable == true
                              ? const Icon(Icons.check_circle_rounded, color: Color(0xFF1DBF73), size: 18)
                              : _usernameAvailable == false
                                  ? const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 18)
                                  : null,
                    ),
                    if (_usernameAvailable == false)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Row(children: [
                          const Icon(Icons.info_outline, color: Colors.redAccent, size: 13),
                          const SizedBox(width: 4),
                          Text('Username taken. Try another.',
                            style: TextStyle(color: Colors.redAccent.withAlpha(200), fontSize: 11)),
                        ]),
                      ),
                    const SizedBox(height: 12),
                    // Tagline
                    _glassField(
                      controller: _taglineCtrl,
                      hint: 'Tagline (e.g. Explorer | Foodie | Dreamer)',
                      icon: Icons.format_quote_rounded,
                      inputFormatters: [LengthLimitingTextInputFormatter(60)],
                    ),
                  ]),
                ),

                // ── Section: Personal Details ─────────────────────────────
                _sectionCard(
                  delay: 500,
                  icon: Icons.calendar_today_outlined,
                  title: 'Personal Details',
                  child: Column(children: [
                    // Date of birth
                    GestureDetector(
                      onTap: _pickDob,
                      child: _glassDisplay(
                        text: _dob != null ? _formatDob(_dob!) : 'Date of Birth',
                        icon: Icons.cake_outlined,
                        isEmpty: _dob == null,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Gender
                    Align(alignment: Alignment.centerLeft,
                      child: Text('Gender',
                        style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 12, fontWeight: FontWeight.w600))),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8,
                      children: _genders.map((g) => _SelectChip(
                        label: g, selected: _gender == g,
                        onTap: () => setState(() => _gender = g),
                      )).toList(),
                    ),
                    const SizedBox(height: 14),
                    // City
                    _glassField(
                      controller: _cityCtrl,
                      hint: 'City / Hometown',
                      icon: Icons.location_city_outlined,
                    ),
                  ]),
                ),

                // ── Section: About You ────────────────────────────────────
                _sectionCard(
                  delay: 600,
                  icon: Icons.self_improvement_rounded,
                  title: 'About You',
                  child: Column(children: [
                    // Bio
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withAlpha(30)),
                      ),
                      child: TextFormField(
                        controller: _bioCtrl,
                        maxLines: 4,
                        maxLength: 150,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Write a short bio... (max 150 chars)',
                          hintStyle: TextStyle(color: Colors.white.withAlpha(80), fontSize: 13),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 60),
                            child: Icon(Icons.edit_note_rounded, color: Colors.white54, size: 20)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                          counterStyle: TextStyle(color: Colors.white.withAlpha(100), fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Travel style
                    Align(alignment: Alignment.centerLeft,
                      child: Text('Travel Style',
                        style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 12, fontWeight: FontWeight.w600))),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8,
                      children: _travelStyles.map((s) => _SelectChip(
                        label: s, selected: _travelStyle == s,
                        onTap: () => setState(() => _travelStyle = s),
                        selectedColor: const Color(0xFF8E2DE2),
                      )).toList(),
                    ),
                  ]),
                ),

                // ── Section: Travel Interests ─────────────────────────────
                _sectionCard(
                  delay: 700,
                  icon: Icons.travel_explore_rounded,
                  title: 'Travel Interests',
                  subtitle: 'Pick everything that excites you',
                  child: Wrap(
                    spacing: 8, runSpacing: 10,
                    children: _interestOptions.map((pair) {
                      final emoji = pair.$1;
                      final label = pair.$2;
                      final selected = _interests.contains(label);
                      return GestureDetector(
                        onTap: () => setState(() {
                          selected ? _interests.remove(label) : _interests.add(label);
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: selected
                                ? const LinearGradient(colors: [AppColors.primary, Color(0xFF8E2DE2)])
                                : null,
                            color: selected ? null : Colors.white.withAlpha(15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected ? Colors.transparent : Colors.white.withAlpha(40)),
                            boxShadow: selected ? [
                              BoxShadow(color: AppColors.primary.withAlpha(60), blurRadius: 8)
                            ] : [],
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(emoji, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Text(label,
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.white.withAlpha(160),
                                fontSize: 12, fontWeight: FontWeight.w500)),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // ── Save button ──────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                    child: _isSaving
                        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                        : GestureDetector(
                            onTap: _save,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppColors.primary, Color(0xFF8E2DE2), Color(0xFFFF7E42)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withAlpha(80),
                                    blurRadius: 20, offset: const Offset(0, 8)),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
                                  SizedBox(width: 10),
                                  Text('Launch My Profile 🚀',
                                    style: TextStyle(color: Colors.white, fontSize: 16,
                                        fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                ],
                              ),
                            ),
                          ).animate().fade(delay: 800.ms).slideY(begin: 0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionCard({
    required int delay,
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(10),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withAlpha(25)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF8E2DE2)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                if (subtitle != null)
                  Text(subtitle, style: TextStyle(
                    color: Colors.white.withAlpha(120), fontSize: 11)),
              ]),
            ]),
            const SizedBox(height: 16),
            child,
          ]),
        ).animate().fade(delay: Duration(milliseconds: delay)).slideY(begin: 0.06),
      ),
    );
  }

  Widget _glassField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withAlpha(80), fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white54, size: 18),
        suffixIcon: suffix != null ? Padding(
          padding: const EdgeInsets.only(right: 14),
          child: suffix,
        ) : null,
        suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        filled: true,
        fillColor: Colors.white.withAlpha(15),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withAlpha(35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _glassDisplay({
    required String text,
    required IconData icon,
    bool isEmpty = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(35)),
      ),
      child: Row(children: [
        Icon(icon, color: Colors.white54, size: 18),
        const SizedBox(width: 12),
        Text(text,
          style: TextStyle(
            color: isEmpty ? Colors.white.withAlpha(80) : Colors.white,
            fontSize: 14)),
        const Spacer(),
        Icon(Icons.keyboard_arrow_down_rounded,
          color: Colors.white.withAlpha(100), size: 20),
      ]),
    );
  }
}

// ── Reusable select chip ──────────────────────────────────────────────────────
class _SelectChip extends StatelessWidget {
  final String label;
  final bool   selected;
  final VoidCallback onTap;
  final Color selectedColor;

  const _SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? selectedColor : Colors.white.withAlpha(40), width: 1.5),
          boxShadow: selected
              ? [BoxShadow(color: selectedColor.withAlpha(80), blurRadius: 8)]
              : [],
        ),
        child: Text(label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white.withAlpha(160),
            fontSize: 13, fontWeight: FontWeight.w500)),
      ),
    );
  }
}
