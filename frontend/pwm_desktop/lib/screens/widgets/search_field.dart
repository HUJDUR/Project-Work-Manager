import 'package:flutter/material.dart';

/// The search box every list screen opens its filter bar with: a magnifier,
/// and — once there is something typed — an "x" to clear it in one tap
/// instead of selecting and deleting it by hand.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.onSubmitted,
    this.onClear,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Runs instead of [onChanged] when the clear button is tapped. A debounced
  /// search box passes this to drop its pending timer and search immediately,
  /// rather than queuing one more wait behind a box that is now empty.
  final VoidCallback? onClear;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  @override
  void initState() {
    super.initState();
    // The clear button's own visibility follows the controller directly, so
    // it still shows or hides correctly when the text is set from outside -
    // a screen clearing every filter at once, for one.
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  void _clear() {
    widget.controller.clear();
    if (widget.onClear != null) {
      widget.onClear!();
    } else {
      widget.onChanged('');
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: widget.controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: _clear,
                tooltip: 'Clear search',
                icon: const Icon(Icons.close, size: 18),
              ),
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      ),
    );
  }
}
