/// Mirrors `UsernameRules` in the API's `UserRequestValidators`, so the form
/// refuses what the API would refuse, with the same wording. Whether the name
/// is already taken only the API can tell.
class UsernameRules {
  UsernameRules._();

  static const minLength = 3;
  static const maxLength = 50;

  static final _pattern = RegExp(r'^[A-Za-z0-9._-]+$');

  static String? validate(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Sign-in needs a username.';
    if (trimmed.length < minLength || trimmed.length > maxLength) {
      return 'Use $minLength to $maxLength characters.';
    }
    return _pattern.hasMatch(trimmed)
        ? null
        : 'Use only letters, digits, dots, hyphens and underscores - no spaces.';
  }
}
