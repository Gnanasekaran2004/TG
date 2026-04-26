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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure    = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _submit(BuildContext ctx) {
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text.trim();
    if (email.isEmpty || pass.isEmpty) {
      _snack(ctx, 'Please fill in all fields');
      return;
    }
    ctx.read<AuthBloc>().add(SignInRequested(email: email, password: pass));
  }

  void _snack(BuildContext ctx, String msg, {bool isError = true}) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (ctx, state) async {
        if (state is Authenticated) {
          // ── Profile-complete gate ─────────────────────────────────────────
          // Check whether the user has finished the Setup Profile step.
          // Falls back to /home on any Firestore error (graceful for existing users).
          try {
            final doc = await FirebaseFirestore.instance
                .collection('users')
                .doc(state.user.uid)
                .get();
            final done = doc.data()?['profileComplete'] as bool? ?? false;
            if (ctx.mounted) ctx.go(done ? '/home' : '/setup-profile');
          } catch (_) {
            if (ctx.mounted) ctx.go('/home');
          }
        }
        if (state is AuthError && ctx.mounted) _snack(ctx, state.message);
      },
      builder: (ctx, state) => Scaffold(
        // resizeToAvoidBottomInset: false is intentional — the hero section
        // should not shrink when keyboard appears. _LoginCard handles keyboard
        // avoidance via MediaQuery.viewInsets.bottom + SingleChildScrollView.
        resizeToAvoidBottomInset: false,
        backgroundColor: const Color(0xFF080D1C),
        body: Stack(
          children: [
            // ── Full-screen gradient ─────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF080D1C),
                    Color(0xFF0B1F5C),
                    Color(0xFF1640A8),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),

            // ── Decorative glows ─────────────────────────────────────────
            Positioned(
              top: -120, left: -80,
              child: _Blob(color: const Color(0xFF4F6AF5), size: 320),
            ),
            Positioned(
              bottom: 240, right: -60,
              child: _Blob(color: const Color(0xFF38BDF8), size: 220),
            ),
            Positioned(
              bottom: 100, left: 60,
              child: _Blob(color: const Color(0xFFFF7432), size: 100),
            ),

            // ── Main layout ──────────────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  // ── Hero branding ─────────────────────────────────────
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Glowing logo
                            Container(
                              width: 82, height: 82,
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
                                    blurRadius: 36, spreadRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.flight_takeoff_rounded,
                                  size: 40, color: Colors.white),
                            )
                            .animate()
                            .scale(duration: 600.ms, curve: Curves.easeOutBack),

                            const SizedBox(height: 18),
                            const Text(
                              'TRIP-GUY',
                              style: TextStyle(
                                fontSize: 38, fontWeight: FontWeight.w900,
                                color: Colors.white, letterSpacing: 4,
                              ),
                            )
                            .animate().fade(delay: 200.ms).slideY(begin: -0.2),

                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.white.withAlpha(35)),
                              ),
                              child: const Text(
                                '✈  Your AI Travel Companion',
                                style: TextStyle(
                                  color: Colors.white70, fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            )
                            .animate().fade(delay: 350.ms),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Form card ────────────────────────────────────────
                  _LoginCard(
                    emailCtrl: _emailCtrl,
                    passCtrl:  _passCtrl,
                    obscure:   _obscure,
                    isLoading: state is AuthLoading,
                    onToggle:  () => setState(() => _obscure = !_obscure),
                    onSubmit:  () => _submit(ctx),
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

// ─────────────────────────────────────────────────────────────────────────────
// Login form card (white, rounded top)
// ─────────────────────────────────────────────────────────────────────────────

class _LoginCard extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool obscure;
  final bool isLoading;
  final VoidCallback onToggle;
  final VoidCallback onSubmit;

  const _LoginCard({
    required this.emailCtrl,
    required this.passCtrl,
    required this.obscure,
    required this.isLoading,
    required this.onToggle,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFB),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
              color: Color(0x40000000), blurRadius: 40, offset: Offset(0, -8)),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          28, 20, 28,
          MediaQuery.of(context).viewInsets.bottom + 24,
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

              // Heading
              const Text('Welcome Back 👋',
                style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                )),
              const SizedBox(height: 4),
              const Text('Sign in to continue your adventure',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 24),

              // Email
              _AuthField(
                controller: emailCtrl,
                label: 'Email Address',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),

              // Password
              _AuthField(
                controller: passCtrl,
                label: 'Password',
                icon: Icons.lock_outline,
                obscure: obscure,
                suffix: GestureDetector(
                  onTap: onToggle,
                  child: Icon(
                    obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF94A3B8), size: 20,
                  ),
                ),
              ),

              // Forgot password
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Forgot Password?',
                    style: TextStyle(
                        color: Color(0xFF4F6AF5), fontSize: 13)),
                ),
              ),
              const SizedBox(height: 4),

              // Sign in button
              _PrimaryBtn(
                label: 'Sign In',
                icon: Icons.login_rounded,
                isLoading: isLoading,
                onTap: onSubmit,
              ),
              const SizedBox(height: 20),

              // Divider
              Row(children: [
                const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text('or',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                ),
                const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
              ]),
              const SizedBox(height: 14),

              // Sign up link
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text("Don't have an account?",
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                TextButton(
                  onPressed: () => context.push('/register'),
                  child: const Text('Sign Up',
                    style: TextStyle(
                      color: Color(0xFF4F6AF5),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    )),
                ),
              ]),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    )
    .animate()
    .slideY(begin: 0.12, end: 0, duration: 500.ms, curve: Curves.easeOutCubic);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared field + button widgets (used by login; similar ones in register)
// ─────────────────────────────────────────────────────────────────────────────

class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffix;

  const _AuthField({
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

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onTap;

  const _PrimaryBtn({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onTap,
  });

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
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(label,
                      style: const TextStyle(
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
