import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// The vertical rhythm of a details form, and the horizontal gap between two
/// fields sharing a row.
const double formFieldGap = 16;

/// Dates in a form are typed and read back in the same shape the tables show.
final DateFormat formFieldDateFormat = DateFormat('d MMM yyyy');

/// One decoration for every FormBuilder field, so the three details screens
/// look like one form rather than three.
InputDecoration appInputDecoration(
  String label, {
  String? hintText,
  String? suffixText,
}) =>
    InputDecoration(
      labelText: label,
      hintText: hintText,
      suffixText: suffixText,
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    );
