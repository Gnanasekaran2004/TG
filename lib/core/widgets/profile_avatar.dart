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
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../utils/base64_cache.dart';

/// A reusable avatar widget that can display:
/// 1. A base64-encoded image from Firestore (free, no Storage needed)
/// 2. A letter-based fallback avatar
///
/// Performance: Uses [Base64Cache] to avoid re-decoding the same base64 string
/// on every rebuild. The [MemoryImage] is also managed by Flutter's image cache
/// so it isn't re-uploaded to the GPU on every frame.
class ProfileAvatar extends StatelessWidget {
  final String? photoBase64;
  final String initial;
  final double radius;
  final Color backgroundColor;

  const ProfileAvatar({
    super.key,
    required this.initial,
    required this.radius,
    required this.backgroundColor,
    this.photoBase64,
  });

  @override
  Widget build(BuildContext context) {
    final Uint8List? bytes = Base64Cache.decode(photoBase64);
    if (bytes != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(bytes),
        backgroundColor: backgroundColor,
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.85,
        ),
      ),
    );
  }
}
