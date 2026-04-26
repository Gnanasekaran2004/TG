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
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_state.dart';
import '../../data/datasources/firebase_auth_datasource.dart';
import '../../../../injection_container.dart' as di;

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameCtrl        = TextEditingController();
  final _emailCtrl       = TextEditingController();
  final _passCtrl        = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms  = false;
  bool _isSendingOtp   = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error
          ? const Color(0xFFEF4444)
          : const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _onRegister() async {
    final name     = _nameCtrl.text.trim();
    final email    = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();
    final confirm  = _confirmPassCtrl.text.trim();

    // ── Client-side validation ────────────────────────────────────────────
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _snack('Please fill in all fields.', error: true);
      return;
    }
    if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _snack('Please enter a valid email address.', error: true);
      return;
    }
    if (password.length < 6) {
      _snack('Password must be at least 6 characters.', error: true);
      return;
    }
    if (password != confirm) {
      _snack('Passwords do not match.', error: true);
      return;
    }
    if (!_agreedToTerms) {
      _snack('Please accept the Terms & Privacy Policy.', error: true);
      return;
    }

    setState(() => _isSendingOtp = true);
    try {
      // ── Duplicate account guard (BEFORE sending OTP) ──────────────────────
      // checkEmailExists() does an unauthenticated Firestore point-read on the
      // registered_emails index (rule: allow get: if true). No deprecated API.
      final ds = di.sl<FirebaseAuthDataSource>();
      final alreadyExists = await ds.checkEmailExists(email);
      if (!mounted) return;
      if (alreadyExists) {
        _snack(
          'An account already exists with this email.\nPlease sign in instead.',
          error: true,
        );
        setState(() => _isSendingOtp = false);
        return;
      }

      // ── Send OTP ─────────────────────────────────────────────────────────
      await ds.sendEmailOtp(
        email:      email,
        name:       name,
        serviceId:  dotenv.env['EMAILJS_SERVICE_ID']?.trim()  ?? '',
        templateId: dotenv.env['EMAILJS_TEMPLATE_ID']?.trim() ?? '',
        publicKey:  dotenv.env['EMAILJS_PUBLIC_KEY']?.trim()  ?? '',
      );
      if (!mounted) return;

      context.push('/otp', extra: {
        'email':    email,
        'name':     name,
        'password': password,
        'mode':     'registration',
      });
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (ctx, state) {
        if (state is Authenticated) ctx.go('/home');
        if (state is AuthError) _snack(state.message, error: true);
      },
      child: Scaffold(
        // ← Use default resizeToAvoidBottomInset: true so the scaffold
        //   shrinks with the keyboard. LayoutBuilder + SingleChildScrollView
        //   below ensure the form card always fills the remaining space
        //   without overflow.
        backgroundColor: const Color(0xFF080D1C),
        body: Stack(
          children: [
            // ── Background gradient (always full-screen) ─────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    Color(0xFF080D1C),
                    Color(0xFF0C1E57),
                    Color(0xFF1640A8),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),

            // ── Decorative glow blobs ────────────────────────────────────
            Positioned(top: -80, right: -60,
                child: _Blob(color: const Color(0xFF6C63FF), size: 280)),
            Positioned(top: 120, left: -80,
                child: _Blob(color: const Color(0xFF38BDF8), size: 180)),
            Positioned(bottom: 180, right: 20,
                child: _Blob(color: const Color(0xFFFF7432), size: 120)),

            // ── Content ──────────────────────────────────────────────────
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  // Scrollable from the root; no Expanded usage.
                  // When the keyboard appears the scaffold height shrinks
                  // (resizeToAvoidBottomInset: true) and the user can scroll
                  // to reach any field — zero overflow risk.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [

                      // ── Header row ─────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                        child: Row(
                          children: [
                            // Back button
                            GestureDetector(
                              onTap: () => context.pop(),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(20),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white.withAlpha(40)),
                                ),
                                child: const Icon(Icons.arrow_back_ios_new,
                                    color: Colors.white, size: 16),
                              ),
                            ).animate().fade(duration: 400.ms),

                            const Spacer(),

                            // Compact logo
                            Column(
                              children: [
                                Container(
                                  width: 46, height: 46,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFF6C63FF), Color(0xFF3730C0)],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF6C63FF).withAlpha(100),
                                        blurRadius: 20, spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.flight_takeoff_rounded,
                                      size: 22, color: Colors.white),
                                )
                                .animate()
                                .scale(duration: 600.ms, curve: Curves.easeOutBack),
                                const SizedBox(height: 4),
                                const Text('TRIP-GUY',
                                  style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w900,
                                    color: Colors.white, letterSpacing: 2,
                                  )),
                              ],
                            ).animate().fade(delay: 150.ms),

                            const Spacer(),
                            const SizedBox(width: 46), // balances back button
                          ],
                        ),
                      ),

                      // ── Page title ─────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Create Account ✈️',
                              style: TextStyle(
                                fontSize: 26, fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ))
                            .animate().fade(delay: 200.ms).slideY(begin: -0.2),
                            const SizedBox(height: 4),
                            const Text('Join thousands of travellers worldwide',
                              style: TextStyle(color: Colors.white60, fontSize: 13))
                            .animate().fade(delay: 300.ms),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Form card ──────────────────────────────────────
                      // ConstrainedBox ensures the card always fills at least
                      // the remaining screen height so the white area reaches
                      // the bottom edge, even when there's little content.
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 148,
                          // 148 ≈ header row (70) + title section (62) + spacing (16)
                        ),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFB),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(32),
                              topRight: Radius.circular(32),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x40000000),
                                blurRadius: 40,
                                offset: Offset(0, -8),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
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
                                const SizedBox(height: 14),

                                // OTP info badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4F6AF5).withAlpha(12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: const Color(0xFF4F6AF5).withAlpha(40)),
                                  ),
                                  child: const Row(children: [
                                    Icon(Icons.verified_user_outlined,
                                        color: Color(0xFF4F6AF5), size: 16),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "We'll verify your email with a 6-digit OTP",
                                        style: TextStyle(
                                          color: Color(0xFF4F6AF5), fontSize: 12),
                                      ),
                                    ),
                                  ]),
                                ),
                                const SizedBox(height: 14),

                                // Full Name
                                _RegField(
                                  controller: _nameCtrl,
                                  label: 'Full Name',
                                  icon: Icons.person_outline,
                                ),
                                const SizedBox(height: 12),

                                // Email
                                _RegField(
                                  controller: _emailCtrl,
                                  label: 'Email Address',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 12),

                                // Password
                                _RegField(
                                  controller: _passCtrl,
                                  label: 'Password (min 6 chars)',
                                  icon: Icons.lock_outline,
                                  obscure: _obscurePass,
                                  suffix: GestureDetector(
                                    onTap: () => setState(
                                        () => _obscurePass = !_obscurePass),
                                    child: Icon(
                                      _obscurePass
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: const Color(0xFF94A3B8), size: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Confirm Password
                                _RegField(
                                  controller: _confirmPassCtrl,
                                  label: 'Confirm Password',
                                  icon: Icons.lock_outline,
                                  obscure: _obscureConfirm,
                                  suffix: GestureDetector(
                                    onTap: () => setState(
                                        () => _obscureConfirm = !_obscureConfirm),
                                    child: Icon(
                                      _obscureConfirm
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: const Color(0xFF94A3B8), size: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Terms checkbox
                                Row(children: [
                                  SizedBox(
                                    width: 24, height: 24,
                                    child: Checkbox(
                                      value: _agreedToTerms,
                                      onChanged: (v) => setState(
                                          () => _agreedToTerms = v ?? false),
                                      activeColor: const Color(0xFF4F6AF5),
                                      side: const BorderSide(
                                          color: Color(0xFFCBD5E1), width: 1.5),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(4)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'I agree to the Terms & Privacy Policy',
                                      style: TextStyle(
                                          color: Color(0xFF64748B), fontSize: 12),
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 16),

                                // Register button
                                _RegisterBtn(
                                  isLoading: _isSendingOtp,
                                  onTap: _onRegister,
                                ),
                                const SizedBox(height: 14),

                                // Sign in link
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('Already have an account?',
                                      style: TextStyle(
                                          color: Color(0xFF64748B), fontSize: 13)),
                                    TextButton(
                                      onPressed: () => context.pop(),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        minimumSize: Size.zero,
                                      ),
                                      child: const Text('Sign In',
                                        style: TextStyle(
                                          color: Color(0xFF4F6AF5),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        )),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ).animate()
                       .slideY(begin: 0.1, end: 0,
                           duration: 500.ms, curve: Curves.easeOutCubic),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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
    decoration: BoxDecoration(
        shape: BoxShape.circle, color: color.withAlpha(22)),
  );
}

class _RegField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffix;

  const _RegField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscure = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xFF4F6AF5), size: 20),
        suffixIcon: suffix,
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

class _RegisterBtn extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;
  const _RegisterBtn({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF3730C0)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withAlpha(80),
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
                    Icon(Icons.mark_email_read_outlined,
                        color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Send OTP & Verify',
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
