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
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/colors.dart';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  Future<void> _launchEmail() async {
    final uri = Uri(scheme: 'mailto', path: 'sgnana238@gmail.com', query: 'subject=Trip-GUY Support');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchPhone() async {
    final uri = Uri(scheme: 'tel', path: '+919876543210');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Hero Section ──────────────────────────────────
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
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                child: Column(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/tripguy_logo.jpg',
                      width: 100, height: 100, fit: BoxFit.cover,
                    ),
                  ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 16),
                  const Text('Trip-GUY', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold))
                      .animate().fade(delay: 200.ms),
                  const SizedBox(height: 6),
                  const Text('Your AI-Powered Travel Companion', style: TextStyle(color: Colors.white70, fontSize: 14))
                      .animate().fade(delay: 300.ms),
                  const SizedBox(height: 6),
                  Chip(
                    label: const Text('Version 2.0.0', style: TextStyle(color: Colors.white, fontSize: 12)),
                    backgroundColor: Colors.white.withAlpha(40),
                    side: BorderSide(color: Colors.white.withAlpha(60)),
                  ).animate().fade(delay: 400.ms),
                ]),
              ),
            ),

            // ── Contact Cards ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('Get in Touch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
                  ),

                  _ContactCard(
                    icon: Icons.email_outlined,
                    label: 'Email Support',
                    subtitle: 'gnanas057@gmail.com',
                    color: AppColors.primary,
                    onTap: _launchEmail,
                  ).animate().slideX(begin: -0.2, duration: 300.ms, delay: 100.ms),

                  const SizedBox(height: 12),

                  _ContactCard(
                    icon: Icons.phone_outlined,
                    label: 'Phone Support',
                    subtitle: '+91 8248094569',
                    color: const Color(0xFF11998e),
                    onTap: _launchPhone,
                  ).animate().slideX(begin: -0.2, duration: 300.ms, delay: 200.ms),

                  const SizedBox(height: 24),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('Quick Help', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
                  ),

                  _FaqTile(
                    question: 'How do I plan a new trip?',
                    answer: 'Tap the ➕ floating button on the Feed page. Fill in your destination, budget, dates and category, then save. Your trip will appear in the Global Feed!',
                  ),
                  _FaqTile(
                    question: 'How do I change my profile picture?',
                    answer: 'Go to Profile and tap your avatar photo. Your phone gallery will open — pick any image and it will update across the whole app instantly.',
                  ),
                  _FaqTile(
                    question: 'How does the AI TripBot work?',
                    answer: 'TripBot is powered by Google Gemini AI. Tap the "Ask TripBot" button and type any travel question — destinations, budgets, packing tips and more!',
                  ),
                  _FaqTile(
                    question: 'Can I delete my posts?',
                    answer: 'Yes! On any post you created, you will see a red 🗑️ delete icon on the top-right of the card. Tap it to permanently remove the post.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ContactCard({required this.icon, required this.label, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
            ])),
            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
          ]),
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;
  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: const Icon(Icons.help_outline, color: AppColors.primary, size: 20),
        title: Text(question, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(answer, style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.5)),
          ),
        ],
      ),
    );
  }
}
