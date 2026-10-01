import 'package:material_ui/material_ui.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
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

/// Every list this long or longer gets a search box rather than a plain
/// scroll - past this, scanning by eye stops being faster than typing.
const int _searchableDropdownThreshold = 8;

/// A dropdown that can be typed into to filter its entries, standing in for
/// `FormBuilderDropdown` everywhere there is a real list to pick from - the
/// customer, the worker, the role, and so on - not just the project fields
/// this started on.
///
/// Two things this fixes that a plain `DropdownMenu` does not on its own:
/// - The menu is capped at [_menuHeight] and scrolls past that, rather than
///   growing to fit however many entries there are - unbounded, a list of
///   thirty workers or projects reads as covering most of the window instead
///   of a panel that opens under the field.
/// - It is keyed on the current value, so an external reset (the lookup
///   screen clearing a dependent field when its parent changes) is reflected
///   immediately - `DropdownMenu` only picks up a changed `initialSelection`
///   when the new value is one of its entries, which a reset to null never is.
class SearchableDropdownField<T> extends StatelessWidget {
  const SearchableDropdownField({
    super.key,
    required this.name,
    required this.label,
    required this.entries,
    this.hintText,
    this.validator,
    this.enabled = true,
    this.onChanged,
  });

  final String name;
  final String label;
  final String? hintText;
  final List<DropdownMenuEntry<T>> entries;
  final FormFieldValidator<T>? validator;
  final bool enabled;

  /// Fires after the form field's own value has already been updated.
  final ValueChanged<T?>? onChanged;

  static const double _menuHeight = 320;

  @override
  Widget build(BuildContext context) {
    return FormBuilderField<T>(
      name: name,
      validator: validator,
      enabled: enabled,
      builder: (field) => DropdownMenu<T>(
        key: ValueKey(field.value),
        initialSelection: field.value,
        expandedInsets: EdgeInsets.zero,
        // Only turns a search box on past the point scrolling stops being
        // the faster way to find something - four priorities do not need one.
        enableFilter: entries.length >= _searchableDropdownThreshold,
        menuHeight: _menuHeight,
        requestFocusOnTap: true,
        enabled: enabled,
        label: Text(label),
        hintText: hintText,
        errorText: field.errorText,
        dropdownMenuEntries: entries,
        onSelected: (value) {
          field.didChange(value);
          onChanged?.call(value);
        },
      ),
    );
  }
}

/// [SearchableDropdownField] for a filter bar rather than a form, for the long
/// lists - projects, workers - so always searchable: the first entry,
/// [allLabel], stands for no filter (null), and the field matches the filter
/// bar's other dropdowns in height.
class SearchableFilterDropdown<T> extends StatefulWidget {
  const SearchableFilterDropdown({
    super.key,
    required this.value,
    required this.allLabel,
    required this.entries,
    required this.onChanged,
  });

  final T? value;
  final String allLabel;
  final List<DropdownMenuEntry<T>> entries;
  final ValueChanged<T?> onChanged;

  @override
  State<SearchableFilterDropdown<T>> createState() => _SearchableFilterDropdownState<T>();
}

class _SearchableFilterDropdownState<T> extends State<SearchableFilterDropdown<T>> {
  /// The [SearchableFilterDropdown.allLabel] entry's value. It is not null, so
  /// no filter (a null value) matches no entry and the field stays empty, with
  /// "All ..." only as its placeholder - nothing to delete before typing.
  static const Object _all = Object();

  final _text = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _showValue();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant SearchableFilterDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _showValue();
  }

  @override
  void dispose() {
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  /// The picked entry's label, or nothing for no filter.
  void _showValue() {
    final value = widget.value;
    _text.text = value == null
        ? ''
        : widget.entries.where((entry) => entry.value == value).firstOrNull?.label ?? '';
  }

  /// The placeholder goes while the field is being typed into; leaving it
  /// without picking anything puts back what was picked before.
  void _onFocusChanged() {
    if (!_focus.hasFocus) _showValue();
    setState(() {});
  }

  void _onSelected(Object? selected) {
    if (identical(selected, _all)) {
      _text.clear();
      widget.onChanged(null);
    } else if (selected is T) {
      widget.onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<Object?>(
      controller: _text,
      focusNode: _focus,
      initialSelection: widget.value,
      expandedInsets: EdgeInsets.zero,
      enableFilter: true,
      menuHeight: SearchableDropdownField._menuHeight,
      requestFocusOnTap: true,
      hintText: _focus.hasFocus ? null : widget.allLabel,
      inputDecorationTheme: const InputDecorationThemeData(
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      ),
      dropdownMenuEntries: [
        DropdownMenuEntry<Object?>(value: _all, label: widget.allLabel),
        for (final entry in widget.entries)
          DropdownMenuEntry<Object?>(value: entry.value, label: entry.label),
      ],
      onSelected: _onSelected,
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
