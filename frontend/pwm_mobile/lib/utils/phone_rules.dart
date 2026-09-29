/// Mirrors `PhoneRules` in the API's `UserRequestValidators`, so the form
/// refuses what the API would refuse, with the same wording.
class PhoneRules {
  PhoneRules._();

  static final _pattern = RegExp(r'^\+?[0-9][0-9 /-]{5,18}[0-9]$');

  static const message =
      'Enter a phone number like +387 61 234 567 - digits, spaces, / or -, with an optional leading +.';

  /// Null when [value] is empty - the field is optional - or looks like a
  /// phone number; otherwise [message].
  static String? validate(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return _pattern.hasMatch(trimmed) ? null : message;
  }
}
