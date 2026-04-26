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
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/colors.dart';
import '../../data/datasources/firebase_auth_datasource.dart';
import '../../../../injection_container.dart' as di;

/// mode: 'registration' or 'forgotPassword'
class OtpVerificationPage extends StatefulWidget {
  final String email;
  final String name;        // used for registration greeting
  final String password;    // used for registration account creation
  final String mode;        // 'registration' | 'forgotPassword'

  const OtpVerificationPage({
    super.key,
    required this.email,
    required this.name,
    required this.password,
    required this.mode,
  });

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  // 6 individual controllers & focus nodes
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  bool _isResending = false;
  int _resendSeconds = 60;
  Timer? _timer;

  late final FirebaseAuthDataSource _authDs;

  @override
  void initState() {
    super.initState();
    _authDs = di.sl<FirebaseAuthDataSource>();
    _startResendTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes)  { f.dispose(); }
    super.dispose();
  }

  // ── Timer ──────────────────────────────────────────────────────────────────

  void _startResendTimer() {
    _resendSeconds = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_resendSeconds > 0) { _resendSeconds--; } else { t.cancel(); }
      });
    });
  }

  // ── OTP input helpers ──────────────────────────────────────────────────────

  String get _enteredOtp =>
      _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    // Auto-submit when all 6 digits entered
    if (_enteredOtp.length == 6) _verifyOtp();
  }

  void _clearOtpBoxes() {
    for (final c in _controllers) { c.clear(); }
    _focusNodes[0].requestFocus();
  }

  // ── Snackbar ───────────────────────────────────────────────────────────────

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : Colors.green,
    ));
  }

  // ── Verify OTP ─────────────────────────────────────────────────────────────

  Future<void> _verifyOtp() async {
    final otp = _enteredOtp;
    if (otp.length < 6) {
      _snack('Please enter all 6 digits.', error: true);
      return;
    }
    if (_isVerifying) return;

    setState(() => _isVerifying = true);
    try {
      final valid = await _authDs.verifyEmailOtp(
        email: widget.email,
        enteredOtp: otp,
      );

      if (!mounted) return;

      if (!valid) {
        _snack('Incorrect OTP. Please try again.', error: true);
        _clearOtpBoxes();
        setState(() => _isVerifying = false);
        return;
      }

      // ── OTP verified ──────────────────────────────────────────────────────
      if (widget.mode == 'registration') {
        // Create Firebase account
        await _authDs.createAccountAfterOtp(
          email: widget.email,
          password: widget.password,
          name: widget.name,
        );
        await _authDs.deleteOtp(widget.email);
        if (!mounted) return;
        _snack('Account created! Set up your profile 🎉');
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        // Redirect to Setup Profile — new users must complete it before accessing the feed
        context.go('/setup-profile', extra: {'name': widget.name});
      } else {
        // Forgot password — send Firebase reset link
        await _authDs.sendResetAfterOtp(widget.email);
        await _authDs.deleteOtp(widget.email);
        if (!mounted) return;
        _showResetSentDialog();
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'email-already-in-use') {
        // ── Duplicate account detected at creation time ─────────────────────
        // fetchSignInMethodsForEmail is removed in firebase_auth 6.x so we
        // detect duplicates here instead of before sending the OTP.
        _snack(
          'An account already exists with this email. Redirecting to sign in…',
          error: true,
        );
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        context.go('/login');
      } else {
        _snack(
          e.message ?? e.code,
          error: true,
        );
        _clearOtpBoxes();
        setState(() => _isVerifying = false);
      }
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceAll('Exception: ', ''), error: true);
      _clearOtpBoxes();
      setState(() => _isVerifying = false);
    }
  }

  // ── Resend OTP ─────────────────────────────────────────────────────────────

  Future<void> _resendOtp() async {
    if (_resendSeconds > 0 || _isResending) return;
    setState(() => _isResending = true);
    try {
      await _authDs.sendEmailOtp(
        email: widget.email,
        name: widget.name.isNotEmpty ? widget.name : 'User',
        serviceId:  dotenv.env['EMAILJS_SERVICE_ID']?.trim()  ?? '',
        templateId: dotenv.env['EMAILJS_TEMPLATE_ID']?.trim() ?? '',
        publicKey:  dotenv.env['EMAILJS_PUBLIC_KEY']?.trim()  ?? '',
      );
      if (!mounted) return;
      _snack('New OTP sent to ${widget.email}');
      _clearOtpBoxes();
      _startResendTimer();
    } catch (e) {
      if (!mounted) return;
      _snack('Failed to resend OTP. Try again.', error: true);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  // ── Reset Sent Dialog ──────────────────────────────────────────────────────

  void _showResetSentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(children: [
          Icon(Icons.mark_email_read_outlined, size: 56, color: AppColors.primary),
          SizedBox(height: 12),
          Text('Reset Link Sent!', textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        content: Text(
          'Identity verified ✅\n\nWe\'ve sent a password reset link to:\n${widget.email}\n\nClick the link in your inbox to set a new password.',
          textAlign: TextAlign.center,
          style: const TextStyle(height: 1.6),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () { Navigator.pop(context); context.go('/login'); },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Back to Login', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isRegistration = widget.mode == 'registration';
    return Scaffold(
      body: Stack(children: [
        // Background gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFF0D1224), Color(0xFF4272FF), Color(0xFFFF7E42)],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),

        // Decorative blobs
        Positioned(top: -70, right: -50,
          child: Container(width: 200, height: 200,
            decoration: BoxDecoration(color: Colors.white.withAlpha(12), shape: BoxShape.circle))),
        Positioned(bottom: 80, left: -60,
          child: Container(width: 180, height: 180,
            decoration: BoxDecoration(color: Colors.white.withAlpha(10), shape: BoxShape.circle))),

        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(children: [
              const SizedBox(height: 20),

              // Back button
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withAlpha(50)),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                  ),
                ),
              ).animate().fade(duration: 400.ms),

              const SizedBox(height: 30),

              // Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withAlpha(60), width: 2),
                ),
                child: const Icon(Icons.mark_email_unread_outlined, size: 42, color: Colors.white),
              ).animate().fade(duration: 500.ms).scale(delay: 100.ms),

              const SizedBox(height: 24),

              Text(
                isRegistration ? 'Verify Your Email ✉️' : 'Confirm Your Identity 🔐',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white),
                textAlign: TextAlign.center,
              ).animate().fade(delay: 200.ms),

              const SizedBox(height: 8),

              Text(
                'We sent a 6-digit code to\n${widget.email}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
              ).animate().fade(delay: 300.ms),

              const SizedBox(height: 36),

              // ── 6-digit OTP boxes ────────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withAlpha(50), width: 1.5),
                  ),
                  child: Column(children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(6, (i) => _OtpBox(
                        controller: _controllers[i],
                        focusNode: _focusNodes[i],
                        onChanged: (val) => _onDigitChanged(i, val),
                      )),
                    ),

                    const SizedBox(height: 28),

                    // Verify button
                    SizedBox(
                      width: double.infinity,
                      child: _isVerifying
                          ? const Center(child: CircularProgressIndicator(color: Colors.white))
                          : ElevatedButton(
                              onPressed: _verifyOtp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              child: const Text('Verify OTP',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                    ),

                    const SizedBox(height: 20),

                    // Resend row
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Text("Didn't receive it? ", style: TextStyle(color: Colors.white70, fontSize: 13)),
                      _isResending
                          ? const SizedBox(width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : GestureDetector(
                              onTap: _resendSeconds == 0 ? _resendOtp : null,
                              child: Text(
                                _resendSeconds > 0
                                    ? 'Resend in ${_resendSeconds}s'
                                    : 'Resend OTP',
                                style: TextStyle(
                                  color: _resendSeconds > 0 ? Colors.white38 : Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  decoration: _resendSeconds == 0 ? TextDecoration.underline : null,
                                ),
                              ),
                            ),
                    ]),
                  ]),
                ),
              ).animate().fade(delay: 400.ms).slideY(begin: 0.08),

              const SizedBox(height: 24),

              // Expiry note
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.timer_outlined, color: Colors.white54, size: 14),
                const SizedBox(width: 6),
                const Text('OTP expires in 5 minutes',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              ]).animate().fade(delay: 600.ms),

              const SizedBox(height: 20),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── Single OTP digit box ──────────────────────────────────────────────────────
class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _OtpBox({required this.controller, required this.focusNode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 54,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textAlign: TextAlign.center,
        maxLength: 1,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withAlpha(60), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white, width: 2),
          ),
          filled: true,
          fillColor: Colors.white.withAlpha(20),
        ),
      ),
    );
  }
}
