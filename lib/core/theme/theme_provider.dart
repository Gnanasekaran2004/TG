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

/// Holds the current ThemeMode and broadcasts changes app-wide.
class ThemeProvider extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  void setMode(ThemeMode mode) {
    _mode = mode;
    notifyListeners();
  }

  void toggle() {
    _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  bool get isDark => _mode == ThemeMode.dark;
}

/// InheritedNotifier that makes [ThemeProvider] accessible everywhere.
class ThemeProviderWidget extends InheritedNotifier<ThemeProvider> {
  const ThemeProviderWidget({
    super.key,
    required ThemeProvider super.notifier,
    required super.child,
  });

  static ThemeProvider of(BuildContext context) {
    final widget = context
        .dependOnInheritedWidgetOfExactType<ThemeProviderWidget>();
    assert(widget != null, 'No ThemeProviderWidget found in widget tree');
    return widget!.notifier!;
  }
}
