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
import 'package:flutter/services.dart';
import '../../../../core/theme/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../injection_container.dart' as di;
import '../../data/datasources/firebase_trip_datasource.dart';

// ─────────────────────────────────────────────
// Data classes
// ─────────────────────────────────────────────
class _TripCategory {
  final String label;
  final IconData icon;
  final Color color;
  const _TripCategory(this.label, this.icon, this.color);
}

const _categories = [
  _TripCategory('Adventure', Icons.terrain, Color(0xFF11998e)),
  _TripCategory('Beach', Icons.beach_access, Color(0xFFFF6584)),
  _TripCategory('Cultural', Icons.museum_outlined, Color(0xFF8E2DE2)),
  _TripCategory('Business', Icons.business_center_outlined, Color(0xFF6C63FF)),
  _TripCategory('Road Trip', Icons.directions_car_outlined, Color(0xFFf7971e)),
  _TripCategory('Cruise', Icons.directions_boat_outlined, Color(0xFF38ef7d)),
];

class _TravelMode {
  final String label;
  final IconData icon;
  const _TravelMode(this.label, this.icon);
}

const _travelModes = [
  _TravelMode('Flight', Icons.flight),
  _TravelMode('Train', Icons.train),
  _TravelMode('Road', Icons.directions_car),
  _TravelMode('Cruise', Icons.directions_boat),
];

// ─────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────
class AddTripModal extends StatefulWidget {
  const AddTripModal({super.key});

  @override
  State<AddTripModal> createState() => _AddTripModalState();
}

class _AddTripModalState extends State<AddTripModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _sourceController = TextEditingController();
  final _destController = TextEditingController();
  final _budgetController = TextEditingController();
  final _travelersController = TextEditingController(text: '1');

  DateTime? _startDate;
  DateTime? _endDate;
  String _visibility = 'Public';
  String _selectedCategory = 'Adventure';
  String _selectedMode = 'Flight';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _sourceController.dispose();
    _destController.dispose();
    _budgetController.dispose();
    _travelersController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? now : (_startDate ?? now).add(const Duration(days: 1)),
      firstDate: isStart ? now : (_startDate ?? now),
      lastDate: DateTime(now.year + 3),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Select date';
    return '${dt.day.toString().padLeft(2, '0')} / ${dt.month.toString().padLeft(2, '0')} / ${dt.year}';
  }

  int get _tripDays {
    if (_startDate == null || _endDate == null) return 0;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  // ─────────────────────────────────────────────
  // Enterprise-Grade Firebase Integration
  // ─────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      _showSnack('Please select travel dates');
      return;
    }
    
    // 1. Start the loading spinner locally
    setState(() => _isSubmitting = true);

    final newTrip = {
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'source': _sourceController.text.trim(),
      'destination': _destController.text.trim(),
      'budget': int.tryParse(_budgetController.text.trim()) ?? 0,
      'travelers': int.tryParse(_travelersController.text.trim()) ?? 1,
      'startDate': _startDate?.toIso8601String(),
      'endDate': _endDate?.toIso8601String(),
      'category': _selectedCategory,
      'travelMode': _selectedMode,
      'visibility': _visibility.toLowerCase(),   // always lowercase: 'public' | 'friends' | 'private'
      'ownerId': FirebaseAuth.instance.currentUser?.uid ?? 'anonymous_user',
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      // 2. OPTIMISTIC UI: We fire the data to Firebase but DO NOT 'await' it.
      // Firebase will automatically sync it in the background!
      di.sl<FirebaseTripDataSource>().createTrip(newTrip);
      
      // 3. Because we didn't await, we instantly reset the button and close the modal!
      if (mounted) {
        setState(() => _isSubmitting = false);
        Navigator.pop(context);
        _showSnack('Trip published successfully! ☁️', success: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showSnack('Failed to save trip. Please try again.');
      }
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF8E2DE2)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Plan New Trip',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      Text('Fill in the details to publish your trip',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
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

          const Divider(height: 1),

          // Scrollable form body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Section 1: Basic Info ────────────────
                    _SectionLabel(
                      number: '1',
                      title: 'Basic Info',
                      icon: Icons.info_outline,
                    ),
                    const SizedBox(height: 12),

                    _InputField(
                      controller: _titleController,
                      hint: 'Trip Title (e.g. "Paris Honeymoon 2026")',
                      icon: Icons.title,
                      validator: (v) => (v == null || v.isEmpty) ? 'Title is required' : null,
                    ),
                    const SizedBox(height: 12),

                    _InputField(
                      controller: _descController,
                      hint: 'Description — What\'s this trip about?',
                      icon: Icons.description_outlined,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),

                    // ── Section 2: Route ─────────────────────
                    _SectionLabel(
                      number: '2',
                      title: 'Route',
                      icon: Icons.alt_route,
                    ),
                    const SizedBox(height: 12),

                    _InputField(
                      controller: _sourceController,
                      hint: 'Origin (e.g. Mumbai, India)',
                      icon: Icons.my_location,
                      validator: (v) => (v == null || v.isEmpty) ? 'Origin is required' : null,
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_downward, color: AppColors.primary, size: 18),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _InputField(
                      controller: _destController,
                      hint: 'Destination (e.g. Paris, France)',
                      icon: Icons.location_on_outlined,
                      validator: (v) => (v == null || v.isEmpty) ? 'Destination is required' : null,
                    ),
                    const SizedBox(height: 20),

                    // ── Section 3: Dates ─────────────────────
                    _SectionLabel(number: '3', title: 'Travel Dates', icon: Icons.date_range),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _DateButton(
                            label: 'Start Date',
                            value: _formatDate(_startDate),
                            icon: Icons.flight_takeoff,
                            onTap: () => _pickDate(true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DateButton(
                            label: 'End Date',
                            value: _formatDate(_endDate),
                            icon: Icons.flight_land,
                            onTap: () => _pickDate(false),
                          ),
                        ),
                      ],
                    ),

                    if (_tripDays > 0) ...[
                      const SizedBox(height: 10),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$_tripDays Day${_tripDays > 1 ? "s" : ""} Trip',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // ── Section 4: Category ───────────────────
                    _SectionLabel(number: '4', title: 'Trip Category', icon: Icons.category_outlined),
                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _categories.map((cat) {
                        final selected = _selectedCategory == cat.label;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedCategory = cat.label),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? cat.color.withAlpha(30) : Colors.grey.withAlpha(20),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected ? cat.color : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(cat.icon,
                                    size: 18,
                                    color: selected ? cat.color : Colors.grey),
                                const SizedBox(width: 8),
                                Text(
                                  cat.label,
                                  style: TextStyle(
                                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                    color: selected ? cat.color : Colors.grey[700],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // ── Section 5: Travel Mode ────────────────
                    _SectionLabel(number: '5', title: 'Mode of Travel', icon: Icons.commute_outlined),
                    const SizedBox(height: 12),

                    Row(
                      children: _travelModes.map((mode) {
                        final selected = _selectedMode == mode.label;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedMode = mode.label),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: EdgeInsets.only(right: mode.label != 'Cruise' ? 10 : 0),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: selected ? AppColors.primary.withAlpha(25) : Colors.grey.withAlpha(15),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected ? AppColors.primary : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(mode.icon,
                                      color: selected ? AppColors.primary : Colors.grey,
                                      size: 22),
                                  const SizedBox(height: 4),
                                  Text(
                                    mode.label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                      color: selected ? AppColors.primary : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // ── Section 6: Budget & Travelers ─────────
                    _SectionLabel(number: '6', title: 'Budget & Travelers', icon: Icons.account_balance_wallet_outlined),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _InputField(
                            controller: _budgetController,
                            hint: 'Budget (INR)',
                            icon: Icons.currency_rupee,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TravelerCounter(controller: _travelersController),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Section 7: Visibility ─────────────────
                    _SectionLabel(number: '7', title: 'Visibility', icon: Icons.visibility_outlined),
                    const SizedBox(height: 12),

                    Row(
                      children: ['Public', 'Friends', 'Private'].map((v) {
                        final selected = _visibility == v;
                        final icons = {
                          'Public': Icons.public,
                          'Friends': Icons.group_outlined,
                          'Private': Icons.lock_outline,
                        };
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _visibility = v),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: EdgeInsets.only(right: v != 'Private' ? 8 : 0),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: selected ? AppColors.secondary.withAlpha(25) : Colors.grey.withAlpha(15),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected ? AppColors.secondary : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(icons[v]!,
                                      color: selected ? AppColors.secondary : Colors.grey,
                                      size: 22),
                                  const SizedBox(height: 4),
                                  Text(
                                    v,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                      color: selected ? AppColors.secondary : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 28),

                    // ── Publish Button ────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.primary.withAlpha(120),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 4,
                          shadowColor: AppColors.primary.withAlpha(80),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.publish_rounded, size: 20),
                                  SizedBox(width: 8),
                                  Text('Publish Trip',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Helper Widgets
// ─────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String number, title;
  final IconData icon;
  const _SectionLabel({required this.number, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          child: Center(
            child: Text(number,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
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
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: maxLines > 1 ? 14 : 0,
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final VoidCallback onTap;
  const _DateButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSet = value != 'Select date';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSet
              ? AppColors.primary.withAlpha(20)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSet ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: isSet ? AppColors.primary : Colors.grey),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: isSet ? AppColors.primary : Colors.grey,
                        fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: isSet ? FontWeight.bold : FontWeight.normal,
                color: isSet ? AppColors.primary : Colors.grey,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TravelerCounter extends StatefulWidget {
  final TextEditingController controller;
  const _TravelerCounter({required this.controller});

  @override
  State<_TravelerCounter> createState() => _TravelerCounterState();
}

class _TravelerCounterState extends State<_TravelerCounter> {
  int _count = 1;

  void _change(int delta) {
    final next = (_count + delta).clamp(1, 20);
    setState(() {
      _count = next;
      widget.controller.text = '$next';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Travelers',
              style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              GestureDetector(
                onTap: () => _change(-1),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.remove, size: 16, color: AppColors.primary),
                ),
              ),
              Text('$_count',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: () => _change(1),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add, size: 16, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}