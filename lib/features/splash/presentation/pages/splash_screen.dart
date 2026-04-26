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
import '../../../../core/theme/colors.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SplashScreen({super.key, required this.onDone});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    // Navigate after animation finishes (2.8 s)
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Logo mark ─────────────────────────────────
            Image.asset(
              'assets/images/tripguy_logo.jpg',
              width: 200,
              height: 200,
              errorBuilder: (_, _, _) => const _FallbackLogo(),
            )
                .animate()
                .scale(begin: const Offset(0.6, 0.6), end: const Offset(1, 1),
                    duration: 700.ms, curve: Curves.easeOutBack)
                .fade(duration: 500.ms),

            const SizedBox(height: 24),

            // ── App name ──────────────────────────────────
            const Text(
              'TRIPGUY',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
                color: Color(0xFF5C4400),
              ),
            )
                .animate(delay: 400.ms)
                .fade(duration: 500.ms)
                .slideY(begin: 0.3, end: 0),

            const SizedBox(height: 8),

            // ── Tagline ───────────────────────────────────
            const Text(
              'CONNECT. PLAN. EXPLORE.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
                color: Color(0xFFD4821A),
              ),
            )
                .animate(delay: 700.ms)
                .fade(duration: 600.ms)
                .slideY(begin: 0.2, end: 0),

            const SizedBox(height: 60),

            // ── Progress dots ─────────────────────────────
            _AnimatedDots()
                .animate(delay: 1000.ms)
                .fade(duration: 400.ms),
          ],
        ),
      ),
    );
  }
}

// ─── Fallback logo (if image not found) ──────────────
class _FallbackLogo extends StatelessWidget {
  const _FallbackLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF8E2DE2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: AppColors.primary.withAlpha(80), blurRadius: 40, offset: const Offset(0, 10)),
        ],
      ),
      child: const Center(
        child: Icon(Icons.travel_explore_rounded, color: Colors.white, size: 90),
      ),
    );
  }
}

// ─── Animated bouncing dots ───────────────────────────
class _AnimatedDots extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: Color(0xFFD4821A),
            shape: BoxShape.circle,
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .moveY(
                begin: 0, end: -10,
                duration: 500.ms, delay: Duration(milliseconds: i * 160),
                curve: Curves.easeInOut)
            .then()
            .moveY(begin: -10, end: 0, duration: 500.ms, curve: Curves.easeIn);
      }),
    );
  }
}
