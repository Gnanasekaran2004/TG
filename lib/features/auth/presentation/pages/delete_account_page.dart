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

import 'account_feedback_page.dart';

class DeleteAccountPage extends StatelessWidget {
  const DeleteAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Delete Account'),
        titleTextStyle: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const SizedBox(height: 12),

              // ── Warning Icon ──────────────────────────────────────────────
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(20),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red.withAlpha(80), width: 2),
                ),
                child: const Icon(Icons.delete_forever_rounded, size: 44, color: Colors.red),
              ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),

              const SizedBox(height: 24),

              const Text(
                'Delete Your Account?',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ).animate().fade(delay: 150.ms),

              const SizedBox(height: 10),

              Text(
                'Deleting your account is permanent. All your data will be erased and cannot be recovered.',
                style: TextStyle(fontSize: 14, color: Colors.white.withAlpha(160), height: 1.6),
                textAlign: TextAlign.center,
              ).animate().fade(delay: 250.ms),

              const SizedBox(height: 30),

              // ── What gets deleted ─────────────────────────────────────────
              _DangerInfoCard(
                title: 'What will be permanently deleted:',
                items: const [
                  '🧳  All your trips and travel plans',
                  '📖  Your travel diary & journal entries',
                  '💬  All chat history with friends',
                  '👤  Your profile, followers & following',
                  '🔔  All notifications and activity',
                  '🔐  Your login credentials',
                ],
              ).animate().fade(delay: 350.ms).slideY(begin: 0.06),

              const SizedBox(height: 20),

              // ── Contact / Support ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withAlpha(25)),
                ),
                child: Column(children: [
                  Row(children: [
                    const Icon(Icons.support_agent_outlined, color: Colors.amber, size: 22),
                    const SizedBox(width: 10),
                    const Text('Have a query before leaving?',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  ]),
                  const SizedBox(height: 10),
                  const Text(
                    'Our support team is happy to help resolve any issue that\'s making you consider leaving.',
                    style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.withAlpha(60)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.email_outlined, color: Colors.amber, size: 18),
                      const SizedBox(width: 10),
                      const Text('gnanas057@gmail.com',
                        style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w600, fontSize: 14)),
                    ]),
                  ),
                ]),
              ).animate().fade(delay: 450.ms),

              const SizedBox(height: 32),

              // ── Action Buttons ────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    side: const BorderSide(color: Colors.white30),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Keep My Account',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ).animate().fade(delay: 550.ms),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.delete_forever_rounded, size: 20),
                  label: const Text('Delete Account Permanently',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AccountFeedbackPage(userEmail: email),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ).animate().fade(delay: 600.ms),

              const SizedBox(height: 16),

              Text(
                'You\'ll be asked to complete a short feedback form before your account is deleted.',
                style: TextStyle(color: Colors.white.withAlpha(80), fontSize: 11),
                textAlign: TextAlign.center,
              ).animate().fade(delay: 700.ms),

              const SizedBox(height: 20),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Danger info card ──────────────────────────────────────────────────────────
class _DangerInfoCard extends StatelessWidget {
  final String title;
  final List<String> items;
  const _DangerInfoCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withAlpha(50)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
          style: const TextStyle(
            color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 12),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Text(item,
            style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 13, height: 1.4)),
        )),
      ]),
    );
  }
}
