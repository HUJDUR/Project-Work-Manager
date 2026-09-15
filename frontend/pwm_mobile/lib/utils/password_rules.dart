/// What a password has to satisfy before it is accepted.
///
/// This is the desktop's file verbatim, the same bargain `BaseProvider` and the
/// `User` model strike: the two apps must refuse the same password. It is
/// **mirrored on the API** besides, by `UserRequestValidators` and
/// `UserProfileUpdateRequestValidator`. Three copies, and changing one means
/// changing all three.
abstract final class PasswordRules {
  static const int minLength = 8;

  /// Shown under the field, so the rules are known before they are broken.
  static const String describe =
      'At least $minLength characters, with an upper-case letter, a lower-case '
      'letter and a number.';

  /// The complaint about [value], or null when it passes.
  static String? validate(String? value) {
    final password = value ?? '';

    if (password.isEmpty) return 'A password is required.';
    if (password.length < minLength) {
      return 'At least $minLength characters.';
    }
    if (!password.contains(RegExp('[A-Z]'))) {
      return 'Needs an upper-case letter.';
    }
    if (!password.contains(RegExp('[a-z]'))) {
      return 'Needs a lower-case letter.';
    }
    if (!password.contains(RegExp('[0-9]'))) {
      return 'Needs a number.';
    }

    return null;
  }

  /// The same, but a blank one is allowed — editing an account keeps the
  /// current password when the field is left empty.
  static String? validateOptional(String? value) =>
      (value ?? '').isEmpty ? null : validate(value);

  /// The whole password section in one pass, in the order a person fills it
  /// in: the new password, then its confirmation, then proof of the old one.
  /// Answers null when there is nothing to complain about — including the case
  /// where no password is being set at all.
  ///
  /// This is checked explicitly rather than through per-field validators: three
  /// fields that check each other need one place that sees all three.
  static String? validateChange({
    required String newPassword,
    required String confirmation,
    String? currentPassword,
  }) {
    if (newPassword.isEmpty) {
      return confirmation.isEmpty ? null : 'Type the new password first.';
    }

    final broken = validate(newPassword);
    if (broken != null) return broken;

    final mismatched = confirm(confirmation, newPassword);
    if (mismatched != null) return mismatched;

    if (currentPassword != null && currentPassword.isEmpty) {
      return 'Type your current password to change it.';
    }

    return null;
  }

  /// Checks the second field against the first.
  static String? confirm(String? value, String? password) {
    final typedPassword = password ?? '';
    if (typedPassword.isEmpty) return null;

    if ((value ?? '').isEmpty) return 'Type the password again.';
    if (value != typedPassword) return 'The two passwords do not match.';

    return null;
  }
}
