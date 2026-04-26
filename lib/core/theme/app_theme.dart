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
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class AppTheme {
  AppTheme._(); // prevent instantiation

  // ── Cached themes ─────────────────────────────────────────────────────────
  // Using `static final` ensures each ThemeData (and the Google Fonts text-theme
  // it embeds) is built ONCE for the lifetime of the app.  Previously these were
  // getters, so the full ThemeData object was reconstructed on every call to
  // `ListenableBuilder` when the ThemeProvider notified its listeners (e.g. on
  // system theme change, or on every hot-reload cycle).
  static final ThemeData lightTheme = _buildLight();
  static final ThemeData darkTheme  = _buildDark();

  // ── Builders (called once) ────────────────────────────────────────────────

  static ThemeData _buildLight() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary:   AppColors.primary,
        secondary: AppColors.secondary,
        surface:   AppColors.surfaceLight,
        error:     AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.backgroundLight,
      textTheme: GoogleFonts.outfitTextTheme().apply(
        bodyColor:    AppColors.textPrimaryLight,
        displayColor: AppColors.textPrimaryLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimaryLight),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimaryLight,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static ThemeData _buildDark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary:   AppColors.primary,
        secondary: AppColors.secondary,
        surface:   AppColors.surfaceDark,
        error:     AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.backgroundDark,
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor:    AppColors.textPrimaryDark,
        displayColor: AppColors.textPrimaryDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimaryDark),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimaryDark,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
