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
import 'dart:convert';
import 'dart:typed_data';

/// App-wide LRU cache for base64-decoded images.
///
/// Problem it solves: [base64Decode] is an expensive CPU operation. When
/// [ProfileAvatar] or [_EntryPhoto] renders inside a scrolling list, `build()`
/// is called on every frame. Calling `base64Decode` 60× per second for 20 items
/// wastes ~1200 decodes/second for data that hasn't changed.
///
/// This cache stores up to [_maxEntries] decoded [Uint8List] values keyed by a
/// prefix of the base64 string. Older entries are evicted when capacity is full
/// (LRU by insertion order).
class Base64Cache {
  Base64Cache._();

  static const int _maxEntries = 100;

  // LinkedHashMap-style: Map preserves insertion order in Dart.
  static final Map<String, Uint8List> _cache = {};

  /// Returns decoded bytes for [base64Str], caching the result on first call.
  /// Returns `null` if the string is null, empty, or malformed.
  static Uint8List? decode(String? base64Str) {
    if (base64Str == null || base64Str.isEmpty) return null;

    // Use a 64-char prefix as the cache key to avoid storing full MB strings as keys.
    final key = base64Str.length > 64
        ? base64Str.substring(0, 64)
        : base64Str;

    // Cache hit — move to end (most recently used) and return.
    if (_cache.containsKey(key)) {
      final bytes = _cache.remove(key)!;
      _cache[key] = bytes; // re-insert at tail
      return bytes;
    }

    // Cache miss — decode and store.
    try {
      final bytes = base64Decode(base64Str);
      _evictIfFull();
      _cache[key] = bytes;
      return bytes;
    } catch (_) {
      return null; // malformed base64 — callers fall back to placeholder
    }
  }

  static void _evictIfFull() {
    if (_cache.length >= _maxEntries) {
      _cache.remove(_cache.keys.first); // evict oldest (LRU)
    }
  }

  /// Clears the cache. Call on user sign-out or in low-memory conditions.
  static void clear() => _cache.clear();

  /// Number of currently cached images (for debugging / diagnostics).
  static int get size => _cache.length;
}
