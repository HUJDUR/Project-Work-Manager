import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';

/// A picture if the account has one, otherwise the name-letters avatar every
/// screen used before pictures existed. [picture] is base64, the shape the
/// API's `byte[]?` column comes across as in JSON.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.picture,
    required this.initials,
    this.size = 32,
    this.radius,
    this.fontSize = 12,
  });

  final String? picture;
  final String initials;
  final double size;

  /// Corner radius; defaults to a full circle.
  final double? radius;

  final double fontSize;

  /// Keyed on the base64 string, so every avatar showing the same picture -
  /// including the same one across two rebuilds - hands `Image.memory` the
  /// identical `Uint8List` instance. `MemoryImage` compares its bytes by
  /// identity, not content, so decoding fresh on every build (a screen
  /// change rebuilds the top bar, and each rebuild used to produce a new
  /// list) made every avatar look like a brand-new image each time and
  /// flash as it redecoded. A plain `Map` is fine here: pictures are a
  /// handful of users' worth, not an unbounded stream.
  static final Map<String, Uint8List> _decodeCache = {};

  Uint8List? get _bytes {
    final data = picture;
    if (data == null || data.isEmpty) return null;

    final cached = _decodeCache[data];
    if (cached != null) return cached;

    try {
      final decoded = base64Decode(data);
      _decodeCache[data] = decoded;
      return decoded;
    } catch (_) {
      // A picture that fails to decode falls back to initials rather than
      // taking the row down with it.
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    final effectiveRadius = radius ?? size / 2;

    return ClipRRect(
      borderRadius: BorderRadius.circular(effectiveRadius),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        color: AppColors.accentSoft,
        child: bytes == null
            ? Text(
                initials,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              )
            : Image.memory(
                bytes,
                width: size,
                height: size,
                fit: BoxFit.cover,
                // Keeps the previous frame on screen instead of a blank gap
                // while a new picture (not this cached one) decodes.
                gaplessPlayback: true,
              ),
      ),
    );
  }
}
