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
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import '../../data/datasources/firebase_auth_datasource.dart';
import '../../../../injection_container.dart' as di;

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? const Color(0xFFEF4444) : const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _onSendOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _snack('Please enter your email address.');
      return;
    }
    if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _snack('Please enter a valid email address.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // ⚠️  BUG FIX: The previous code called userExistsByEmail() here,
      // which reads the Firestore users collection.  Unauthenticated callers
      // are blocked by the "require auth != null" Firestore rule, causing a
      // permission-denied exception.  We now send the OTP directly.  If the
      // email has no associated account, the final password-reset link is
      // simply never used — safe and intentional.
      await di.sl<FirebaseAuthDataSource>().sendEmailOtp(
        email:      email,
        name:       'Traveller',
        serviceId:  dotenv.env['EMAILJS_SERVICE_ID']?.trim()  ?? '',
        templateId: dotenv.env['EMAILJS_TEMPLATE_ID']?.trim() ?? '',
        publicKey:  dotenv.env['EMAILJS_PUBLIC_KEY']?.trim()  ?? '',
      );
      if (!mounted) return;

      context.push('/otp', extra: {
        'email':    email,
        'name':     'Traveller',
        'password': '',
        'mode':     'forgotPassword',
      });
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF080D1C),
      body: Stack(
        children: [
          // ── Background gradient ──────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF080D1C), Color(0xFF0B1F5C), Color(0xFF1640A8)],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),

          // ── Decorative glows ─────────────────────────────────────────────
          Positioned(top: -100, right: -60,
              child: _Blob(color: const Color(0xFF4F6AF5), size: 280)),
          Positioned(bottom: 160, left: -60,
              child: _Blob(color: const Color(0xFF38BDF8), size: 200)),

          // ── Content ──────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Back button row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(20),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withAlpha(40)),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ).animate().fade(duration: 400.ms),

                // ── Hero ─────────────────────────────────────────────────
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 88, height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF5C80FF), Color(0xFF2040C0)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4F6AF5).withAlpha(120),
                                blurRadius: 36, spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.lock_reset_outlined,
                              size: 42, color: Colors.white),
                        )
                        .animate()
                        .scale(duration: 600.ms, curve: Curves.easeOutBack),

                        const SizedBox(height: 20),
                        const Text('Forgot Password?',
                          style: TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ))
                        .animate().fade(delay: 200.ms).slideY(begin: -0.2),

                        const SizedBox(height: 8),
                        const Text(
                          "We'll send a 6-digit OTP to verify\nyour identity before resetting.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.5),
                        )
                        .animate().fade(delay: 350.ms),
                      ],
                    ),
                  ),
                ),

                // ── Form card ────────────────────────────────────────────
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFB),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(color: Color(0x40000000), blurRadius: 40, offset: Offset(0, -8)),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      28, 20, 28,
                      MediaQuery.of(context).viewInsets.bottom + 28,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Handle
                          Center(
                            child: Container(
                              width: 44, height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          const Text('Reset via OTP',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A))),
                          const SizedBox(height: 4),
                          const Text('Enter your registered email address',
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                          const SizedBox(height: 22),

                          // Email field
                          _FpField(controller: _emailCtrl),
                          const SizedBox(height: 14),

                          // Info row
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F6AF5).withAlpha(15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFF4F6AF5).withAlpha(40)),
                            ),
                            child: const Row(children: [
                              Icon(Icons.shield_outlined,
                                  color: Color(0xFF4F6AF5), size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'A 6-digit OTP will be sent to verify your email. '
                                  'Then you can set a new password via a secure link.',
                                  style: TextStyle(
                                    color: Color(0xFF4F6AF5), fontSize: 12, height: 1.4),
                                ),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 22),

                          // Send OTP button
                          _SendBtn(isLoading: _isLoading, onTap: _onSendOtp),
                          const SizedBox(height: 16),

                          TextButton(
                            onPressed: () => context.go('/login'),
                            child: const Text('← Back to Login',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().slideY(begin: 0.12, end: 0,
                    duration: 500.ms, curve: Curves.easeOutCubic),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private helpers
// ─────────────────────────────────────────────────────────────────────────────

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color.withAlpha(22)),
  );
}

class _FpField extends StatelessWidget {
  final TextEditingController controller;
  const _FpField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15),
      decoration: InputDecoration(
        labelText: 'Email Address',
        labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        prefixIcon: const Icon(Icons.email_outlined,
            color: Color(0xFF4F6AF5), size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF4F6AF5), width: 2),
        ),
      ),
    );
  }
}

class _SendBtn extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;
  const _SendBtn({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF4F6AF5), Color(0xFF2540C0)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F6AF5).withAlpha(80),
            blurRadius: 16, offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isLoading ? null : onTap,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.send_outlined, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Send OTP',
                      style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold,
                        fontSize: 16, letterSpacing: 0.5,
                      )),
                  ]),
          ),
        ),
      ),
    );
  }
}
