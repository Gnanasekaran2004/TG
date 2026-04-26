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

/// Trip-GUY Color System — "Vivid Horizon" palette
/// Primary: Royal Blue #4272FF | Cyan #42EAFF | Gold #FFB343 | Orange #FF7E42
class AppColors {
  // ── Primary Brand ────────────────────────────────────────────────────
  static const Color primary      = Color(0xFF4272FF); // Royal Blue
  static const Color primaryDark  = Color(0xFF2453E0); // Deep Blue
  static const Color primaryLight = Color(0xFF7A9FFF); // Soft Blue

  // ── Accent Cyan ───────────────────────────────────────────────────────
  static const Color cyan     = Color(0xFF42EAFF); // Electric Cyan
  static const Color cyanDark = Color(0xFF00C8E0); // Deep Cyan

  // ── Warm Accents ──────────────────────────────────────────────────────
  static const Color secondary = Color(0xFFFF7E42); // Warm Orange
  static const Color gold      = Color(0xFFFFB343); // Golden Amber
  static const Color orange    = Color(0xFFFF7E42); // Warm Orange (alias)

  // ── Backgrounds ──────────────────────────────────────────────────────
  static const Color backgroundLight = Color(0xFFF4F6FF); // Soft blue-white
  static const Color backgroundDark  = Color(0xFF0D1224); // Deep midnight

  // ── Surfaces ──────────────────────────────────────────────────────────
  static const Color surfaceLight = Colors.white;
  static const Color surfaceDark  = Color(0xFF1A2038); // Dark navy card

  // ── Text ─────────────────────────────────────────────────────────────
  static const Color textPrimaryLight = Color(0xFF0B1120); // Near-black
  static const Color textPrimaryDark  = Color(0xFFE8EEFF); // Soft white
  static const Color textSecondary    = Color(0xFF6B7A99); // Cool grey-blue

  // ── Semantic ─────────────────────────────────────────────────────────
  static const Color error   = Color(0xFFFF4747); // Bright red
  static const Color success = Color(0xFF1DBF73); // Fresh green
  static const Color warning = Color(0xFFFFB343); // Golden amber
}
