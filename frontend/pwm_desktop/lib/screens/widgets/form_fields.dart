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
      // Unset, a long errorText is clipped to one line with an ellipsis
      // instead of wrapping - cutting the message off mid-sentence.
      errorMaxLines: 2,
    );

/// A password field with the same show/hide eye button the login screen uses,
/// so every place an account's password is typed behaves the same way.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    this.onChanged,
    this.hasError = false,
    this.focusNode,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;

  /// True for an unfinished confirm field - a red outline with no caption of
  /// its own, since nothing has actually been typed wrong yet.
  final bool hasError;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: _obscure,
      onChanged: widget.onChanged,
      decoration: appInputDecoration(widget.label, hintText: widget.hintText).copyWith(
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscure = !_obscure),
          tooltip: _obscure ? 'Show password' : 'Hide password',
          icon: Icon(
            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 19,
            color: AppColors.textMuted,
          ),
        ),
        // The theme's own errorBorder colour, with the caption suppressed -
        // this reaches for the field's built-in error styling on purpose,
        // rather than duplicating that colour and border shape by hand.
        errorText: widget.hasError ? '' : null,
        errorStyle: const TextStyle(fontSize: 0, height: 0),
      ),
    );
  }
}

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
