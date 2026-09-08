import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../utils/app_theme.dart';

/// The vertical rhythm of a details form, and the horizontal gap between two
/// fields sharing a row.
const double formFieldGap = 16;

/// The gap between two groups of fields that answer different questions - who
/// worked, then when. Wider than [formFieldGap] so the groups read apart.
const double formSectionGap = 28;

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
      // The outline itself comes from AppTheme's inputDecorationTheme, so every
      // field in the app - these and the list screens' filters - shares one.
      // Dense, but not squeezed: the value needs room off the outline on both
      // axes or it reads as crammed into the corner.
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      isDense: true,
    );

/// A hairline "-" between two fields that belong together, such as a date and
/// the times booked against it.
class FieldSeparator extends StatelessWidget {
  const FieldSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        '-',
        style: TextStyle(fontSize: 15, color: AppColors.textMuted),
      ),
    );
  }
}
