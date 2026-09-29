import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:provider/provider.dart';

import '../layouts/window_chrome.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../utils/api_client_exception.dart';
import '../utils/app_theme.dart';
import '../utils/dialogs.dart';
import '../utils/password_rules.dart';
import '../utils/phone_rules.dart';
import 'widgets/form_fields.dart';
import 'widgets/user_avatar.dart';

/// Mirrored on the API by `PictureRules.MaxSizeBytes` - this is a friendlier,
/// earlier refusal, not the only check.
const _maxPictureBytes = 5 * 1024 * 1024;

const _pictureTypeGroup = XTypeGroup(
  label: 'Images',
  extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
);

/// Opens the signed-in user's own account. Pushed on the **root** navigator: it
/// is reached from the top bar, which sits outside the per-destination navigator
/// `MasterScreen` hands out, so there is no nested one to push onto.
Future<void> openAccountSettings(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(builder: (_) => AccountSettingsScreen()),
  );
}

/// What the signed-in user may change about themselves: their name, how they are
/// reached, and their password.
///
/// Role and whether the account is active are **not** here, and the API will not
/// take them from this screen either — those stay an administrator's job on the
/// Workers screen. See `UserProfileUpdateRequest`.
class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key, this.userProvider});

  /// Lets a test swap in a provider backed by a fake.
  final UserProvider? userProvider;

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _formKey = GlobalKey<FormBuilderState>();

  /// The password fields are driven by controllers this state owns, because two
  /// of them are checked against a third. A field's value read back out of the
  /// form is not reliably current while the form is validating; a controller's
  /// text always is.
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _currentPasswordFocus = FocusNode();
  final _newPasswordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  late final UserProvider _users = widget.userProvider ?? UserProvider();

  /// Base64, seeded from the signed-in user and replaced when a new picture
  /// is picked, or cleared back to null (the name-letters avatar) by Remove.
  String? _picture;

  bool _saving = false;
  String? _error;

  /// False until Save has been pressed once. `FormBuilder`'s own
  /// `autovalidateMode` validates every field the moment any one of them
  /// changes, not just the one being typed in - so each field is instead
  /// re-checked by hand, on its own `onChanged`, and only once there is
  /// something on screen worth keeping in step.
  bool _saveAttempted = false;

  /// Fields that have been focused and then left, each the first time it
  /// happens - from then on that one field validates live too, the same
  /// as every field does once Save has been pressed.
  final _touchedFields = <String>{};

  final _nameFocus = FocusNode();
  final _surnameFocus = FocusNode();
  final _emailFocus = FocusNode();

  /// Validates a field the moment it is left, not only once Save is pressed -
  /// so leaving a broken field behind (typed, then emptied again) is caught
  /// on the way out rather than staying silent until submit.
  void _onFieldBlurred(String name, FocusNode node) {
    if (node.hasFocus) return;
    _touchedFields.add(name);
    _formKey.currentState?.fields[name]?.validate(focusOnInvalid: false);
  }

  /// Re-validates one field in isolation - never the whole form, which would
  /// surface every other untouched field's error along with it.
  void _revalidateField(String name) {
    if (!_saveAttempted && !_touchedFields.contains(name)) return;
    _formKey.currentState?.fields[name]?.validate(focusOnInvalid: false);
  }

  /// What is wrong with the password section, shown under it. Null until a save
  /// has been refused, then kept in step as the fields are corrected.
  String? _passwordError;

  String? _checkPasswords() => PasswordRules.validateChange(
        newPassword: _newPassword.text,
        confirmation: _confirmPassword.text,
        currentPassword: _currentPassword.text,
      );

  /// Only once a complaint is on screen, so it clears as the fields are fixed
  /// rather than nagging halfway through the first word.
  void _recheckPasswords() {
    if (_passwordError == null) return;
    setState(() => _passwordError = _checkPasswords());
  }

  /// Checks the trio the moment any one of them is left, not only once Save
  /// is pressed - same treatment leaving the name/e-mail fields already gets.
  void _onPasswordFieldBlurred(FocusNode node) {
    if (node.hasFocus) return;
    setState(() => _passwordError = _checkPasswords());
  }

  @override
  void initState() {
    super.initState();
    _picture = AuthProvider.user?.picture;
    _nameFocus.addListener(() => _onFieldBlurred('name', _nameFocus));
    _surnameFocus.addListener(() => _onFieldBlurred('surname', _surnameFocus));
    _emailFocus.addListener(() => _onFieldBlurred('email', _emailFocus));
    _currentPasswordFocus
        .addListener(() => _onPasswordFieldBlurred(_currentPasswordFocus));
    _newPasswordFocus.addListener(() => _onPasswordFieldBlurred(_newPasswordFocus));
    _confirmPasswordFocus
        .addListener(() => _onPasswordFieldBlurred(_confirmPasswordFocus));
  }

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    _currentPasswordFocus.dispose();
    _newPasswordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _nameFocus.dispose();
    _surnameFocus.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _pickPicture() async {
    final file = await openFile(acceptedTypeGroups: const [_pictureTypeGroup]);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    if (bytes.length > _maxPictureBytes) {
      if (!mounted) return;
      setState(() => _error = 'Pick an image under 5 MB.');
      return;
    }

    if (!mounted) return;
    setState(() {
      _picture = base64Encode(bytes);
      _error = null;
    });
  }

  void _removePicture() => setState(() => _picture = null);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          AppWindowBar(
            title: 'Account settings',
            subtitle: user == null
                ? 'Nobody is signed in'
                : '${user.email} · ${auth.currentRole}',
            leading: IconButton(
              onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back, size: 20),
              color: AppColors.textSecondary,
            ),
            actions: [
              FilledButton.icon(
                onPressed: user == null || _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check, size: 18),
                label: const Text('Save'),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: user == null
                ? _NotSignedIn()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.pagePadding),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: _Form(
                          formKey: _formKey,
                          user: user,
                          role: auth.currentRole,
                          error: _error,
                          picture: _picture,
                          onPickPicture: _pickPicture,
                          onRemovePicture: _removePicture,
                          currentPassword: _currentPassword,
                          newPassword: _newPassword,
                          confirmPassword: _confirmPassword,
                          passwordError: _passwordError,
                          onPasswordChanged: _recheckPasswords,
                          onFieldChanged: _revalidateField,
                          nameFocus: _nameFocus,
                          surnameFocus: _surnameFocus,
                          emailFocus: _emailFocus,
                          currentPasswordFocus: _currentPasswordFocus,
                          newPasswordFocus: _newPasswordFocus,
                          confirmPasswordFocus: _confirmPasswordFocus,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    _saveAttempted = true;

    final passwordError = _checkPasswords();
    final detailsValid = _formKey.currentState?.saveAndValidate() ?? false;

    if (!detailsValid || passwordError != null) {
      setState(() => _passwordError = passwordError);
      return;
    }

    final values = _formKey.currentState!.value;
    final newPassword = _newPassword.text.isEmpty ? null : _newPassword.text;

    setState(() {
      _saving = true;
      _error = null;
      _passwordError = null;
    });

    try {
      final updated = await _users.updateProfile(
        name: (values['name'] as String).trim(),
        surname: (values['surname'] as String).trim(),
        email: (values['email'] as String).trim(),
        phoneNumber: _trimToNull(values['phoneNumber']),
        picture: _picture,
        // Only sent when the password is actually being changed.
        currentPassword: newPassword == null ? null : _currentPassword.text,
        newPassword: newPassword,
      );

      if (!mounted) return;

      // The top bar reads the signed-in user, so it has to hear about this.
      context.read<AuthProvider>().updateCurrentUser(updated);

      // Emptied rather than left holding what was typed.
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();

      showSavedSnackBar(context, 'Account updated');
    } catch (error) {
      setState(() {
        _error = error is ApiClientException
            ? error.message
            : 'Your account could not be saved: $error';
      });
    }

    if (mounted) setState(() => _saving = false);
  }

  static String? _trimToNull(Object? value) {
    final text = (value as String?)?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.formKey,
    required this.user,
    required this.role,
    required this.error,
    required this.picture,
    required this.onPickPicture,
    required this.onRemovePicture,
    required this.currentPassword,
    required this.newPassword,
    required this.confirmPassword,
    required this.passwordError,
    required this.onPasswordChanged,
    required this.onFieldChanged,
    required this.nameFocus,
    required this.surnameFocus,
    required this.emailFocus,
    required this.currentPasswordFocus,
    required this.newPasswordFocus,
    required this.confirmPasswordFocus,
  });

  final GlobalKey<FormBuilderState> formKey;
  final User user;
  final String role;
  final String? error;
  final String? picture;
  final VoidCallback onPickPicture;
  final VoidCallback onRemovePicture;
  final TextEditingController currentPassword;
  final TextEditingController newPassword;
  final TextEditingController confirmPassword;
  final String? passwordError;
  final VoidCallback onPasswordChanged;

  /// Re-validates the one named field - never the whole form, which would
  /// surface every other untouched field's error along with it.
  final ValueChanged<String> onFieldChanged;

  final FocusNode nameFocus;
  final FocusNode surnameFocus;
  final FocusNode emailFocus;
  final FocusNode currentPasswordFocus;
  final FocusNode newPasswordFocus;
  final FocusNode confirmPasswordFocus;

  @override
  Widget build(BuildContext context) {
    return FormBuilder(
      key: formKey,
      initialValue: {
        'name': user.name,
        'surname': user.surname,
        'email': user.email,
        'phoneNumber': user.phoneNumber,
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) ...[
            _ErrorBanner(message: error!),
            const SizedBox(height: AppSpacing.gap),
          ],
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionHeader(
                  title: 'Your details',
                  caption: 'How the rest of the shop sees you',
                ),
                const SizedBox(height: AppSpacing.gap),
                _PictureField(
                  picture: picture,
                  initials: user.initials,
                  onPick: onPickPicture,
                  onRemove: onRemovePicture,
                ),
                const SizedBox(height: AppSpacing.gap),
                Row(
                  // Top-aligned, not centred: a validator error grows only
                  // the field it belongs to, and centring would sink its
                  // neighbour to match instead of leaving it where it started.
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: FormBuilderTextField(
                        name: 'name',
                        focusNode: nameFocus,
                        decoration: appInputDecoration('First name'),
                        validator: FormBuilderValidators.required(
                          errorText: 'A first name is required.',
                        ),
                        onChanged: (_) => onFieldChanged('name'),
                      ),
                    ),
                    const SizedBox(width: formFieldGap),
                    Expanded(
                      child: FormBuilderTextField(
                        name: 'surname',
                        focusNode: surnameFocus,
                        decoration: appInputDecoration('Surname'),
                        validator: FormBuilderValidators.required(
                          errorText: 'A surname is required.',
                        ),
                        onChanged: (_) => onFieldChanged('surname'),
                      ),
                    ),
                  ],
                ),
                // Wider than formFieldGap: a validator error appends its own
                // line under the field, and the ordinary gap reads as
                // cramped once that red text sits right above what follows.
                const SizedBox(height: formFieldGap + 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: FormBuilderTextField(
                        name: 'email',
                        focusNode: emailFocus,
                        decoration: appInputDecoration('E-mail'),
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(
                            errorText: 'Sign-in needs an e-mail address.',
                          ),
                          FormBuilderValidators.email(
                            errorText: 'That is not an e-mail address.',
                          ),
                        ]),
                        onChanged: (_) => onFieldChanged('email'),
                      ),
                    ),
                    const SizedBox(width: formFieldGap),
                    Expanded(
                      child: FormBuilderTextField(
                        name: 'phoneNumber',
                        decoration: appInputDecoration(
                          'Phone',
                          hintText: 'Not set',
                        ),
                        validator: PhoneRules.validate,
                        onChanged: (_) => onFieldChanged('phoneNumber'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: formFieldGap + 10),
                // Read-only on purpose: an account cannot promote itself.
                _ReadOnlyRow(label: 'Role', value: role),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.gap),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionHeader(
                  title: 'Password',
                  caption: 'Leave these empty to keep the one you have',
                ),
                const SizedBox(height: AppSpacing.gap),
                _PasswordFields(
                  currentPassword: currentPassword,
                  newPassword: newPassword,
                  confirmPassword: confirmPassword,
                  error: passwordError,
                  onChanged: onPasswordChanged,
                  currentPasswordFocus: currentPasswordFocus,
                  newPasswordFocus: newPasswordFocus,
                  confirmPasswordFocus: confirmPasswordFocus,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The avatar plus the controls to change or remove it. Sits above the name
/// fields, the same spot the identity block occupies on the mobile screen.
class _PictureField extends StatelessWidget {
  const _PictureField({
    required this.picture,
    required this.initials,
    required this.onPick,
    required this.onRemove,
  });

  final String? picture;
  final String initials;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        UserAvatar(picture: picture, initials: initials, size: 64, fontSize: 20),
        const SizedBox(width: 16),
        TextButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.photo_camera_outlined, size: 18),
          label: Text(picture == null ? 'Add picture' : 'Change picture'),
        ),
        if (picture != null)
          TextButton(
            onPressed: onRemove,
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Remove'),
          ),
      ],
    );
  }
}

/// The three password fields. They check each other rather than themselves, so
/// the complaint is worked out in one place by [PasswordRules.validateChange]
/// and shown once, under all three.
class _PasswordFields extends StatelessWidget {
  const _PasswordFields({
    required this.currentPassword,
    required this.newPassword,
    required this.confirmPassword,
    required this.error,
    required this.onChanged,
    required this.currentPasswordFocus,
    required this.newPasswordFocus,
    required this.confirmPasswordFocus,
  });

  final TextEditingController currentPassword;
  final TextEditingController newPassword;
  final TextEditingController confirmPassword;
  final String? error;
  final VoidCallback onChanged;
  final FocusNode currentPasswordFocus;
  final FocusNode newPasswordFocus;
  final FocusNode confirmPasswordFocus;

  @override
  Widget build(BuildContext context) {
    // The confirm field is just empty so far, not actually wrong - shown as
    // an unfinished (red, captionless) field rather than as an error message.
    final unconfirmed = error == PasswordRules.confirmationNeeded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PasswordField(
          controller: currentPassword,
          focusNode: currentPasswordFocus,
          label: 'Current password',
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: formFieldGap),
        Row(
          children: [
            Expanded(
              child: PasswordField(
                controller: newPassword,
                focusNode: newPasswordFocus,
                label: 'New password',
                onChanged: (_) => onChanged(),
              ),
            ),
            const SizedBox(width: formFieldGap),
            Expanded(
              child: PasswordField(
                controller: confirmPassword,
                focusNode: confirmPasswordFocus,
                label: 'Confirm new password',
                onChanged: (_) => onChanged(),
                hasError: unconfirmed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          unconfirmed ? PasswordRules.describe : (error ?? PasswordRules.describe),
          style: TextStyle(
            fontSize: 12,
            color: error == null || unconfirmed
                ? AppColors.textSecondary
                : AppColors.danger,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.caption});

  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          caption,
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        Text(
          value.isEmpty ? 'Unknown' : value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Only an administrator can change this, on the Workers screen.',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}

class _NotSignedIn extends StatelessWidget {
  const _NotSignedIn();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_off_outlined, size: 40, color: AppColors.textMuted),
          const SizedBox(height: 12),
          const Text(
            'Nobody is signed in',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'There is no account to edit until someone signs in.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        border: Border.all(color: AppColors.dangerBorder),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
