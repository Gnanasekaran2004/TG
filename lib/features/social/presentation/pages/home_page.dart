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

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        automaticallyImplyLeading: false, // Hide back button since we logged in
        actions: [
          IconButton(icon: const Icon(Icons.person_outline), onPressed: () {}),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                    'Welcome to Trip-GUY!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  )
                  .animate()
                  .fade(duration: 400.ms)
                  .slideX(begin: -0.1, end: 0, curve: Curves.easeOut),

              const SizedBox(height: 8),

              const Text(
                'You have successfully logged in. Firebase integration is skipped, so this is just the UI presentation flow.',
                style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
              ).animate().fade(delay: 200.ms),

              const SizedBox(height: 32),

              // Placeholder for future feed/features
              Expanded(
                child:
                    Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.grey.withAlpha(51),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(13),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                      Icons.map_outlined,
                                      size: 64,
                                      color: AppColors.primary.withAlpha(128),
                                    )
                                    .animate(
                                      onPlay: (controller) =>
                                          controller.repeat(reverse: true),
                                    )
                                    .scaleXY(
                                      begin: 1.0,
                                      end: 1.1,
                                      duration: 1500.ms,
                                      curve: Curves.easeInOut,
                                    ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Your Feed will appear here',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .animate()
                        .fade(delay: 400.ms)
                        .slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.secondary,
        child: const Icon(Icons.add, color: Colors.white),
      ).animate().scale(delay: 600.ms, curve: Curves.elasticOut),
    );
  }
}
