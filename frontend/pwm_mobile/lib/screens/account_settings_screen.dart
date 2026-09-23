import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../utils/api_client_exception.dart';
import '../utils/app_theme.dart';
import '../utils/dialogs.dart';
import '../utils/password_rules.dart';

/// The signed-in worker's own account. Reached from the avatar in the top bar
/// and from the Options tab, and pushed on the **root** navigator so it covers
/// the bottom bar — the shell hands no per-tab navigator out, and a full-screen
/// page with its own back arrow is what a phone expects.
Future<void> openAccountSettings(BuildContext context, {UserProvider? users}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(builder: (_) => AccountSettingsScreen(userProvider: users)),
  );
}

/// What a worker may change about themselves, which is **two things**: the
/// number they are reached on, and their password.
///
/// Name, surname, e-mail and role are shown but not editable. That is
/// narrower than the desktop's version of this screen, where the office edits
/// its own name and e-mail — on the shop floor those identify the account to
/// everyone else, so they stay an administrator's job on the Workers screen.
/// The API is not what enforces it: `UserProfileUpdateRequest` would take a new
/// name, so this screen sends the current one back unchanged, the same way the
/// desktop's project form returns a `creationDate` it never showed.
///
/// Role and `IsActive` are a different matter — the request cannot express them
/// at all, so no client can set them on itself.
class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key, this.userProvider});

  /// Lets a test swap in a provider backed by a fake.
  final UserProvider? userProvider;

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  late final UserProvider _users = widget.userProvider ?? UserProvider();

  final _phone = TextEditingController();

  /// Driven by controllers this state owns, because each is checked against the
  /// other two — the desktop's reasoning, and the reason there are no per-field
  /// validators here.
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _currentPasswordFocus = FocusNode();
  final _newPasswordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  bool _saving = false;
  String? _error;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _phone.text = AuthProvider.user?.phoneNumber ?? '';
    _currentPasswordFocus
        .addListener(() => _onPasswordFieldBlurred(_currentPasswordFocus));
    _newPasswordFocus.addListener(() => _onPasswordFieldBlurred(_newPasswordFocus));
    _confirmPasswordFocus
        .addListener(() => _onPasswordFieldBlurred(_confirmPasswordFocus));
  }

  @override
  void dispose() {
    _phone.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    _currentPasswordFocus.dispose();
    _newPasswordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

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
  /// is pressed — the desktop's own treatment of this section, so a broken
  /// password is caught on the way out of the field rather than staying
  /// silent until submit.
  void _onPasswordFieldBlurred(FocusNode node) {
    if (node.hasFocus) return;
    setState(() => _passwordError = _checkPasswords());
  }

  /// The confirm field is just empty so far, not actually wrong - shown as an
  /// unfinished (red, captionless) field rather than as an error message.
  bool get _unconfirmedPassword =>
      _passwordError == PasswordRules.confirmationNeeded;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          tooltip: 'Back',
        ),
        title: Text(
          'Account settings',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: user == null ? _NotSignedIn() : _body(user, auth.currentRole),
    );
  }

  Widget _body(User user, String role) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          _Identity(user: user, role: role),
          const SizedBox(height: AppSpacing.gap),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionHeader(
                  title: 'Your details',
                  caption: 'Only your phone number is yours to change',
                ),
                const SizedBox(height: 14),
                _ReadOnlyRow(label: 'First name', value: user.name),
                _ReadOnlyRow(label: 'Surname', value: user.surname),
                _ReadOnlyRow(label: 'E-mail', value: user.email),
                _ReadOnlyRow(label: 'Role', value: role, isLast: true),
                const SizedBox(height: 14),
                Text(
                  'Phone number',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(hintText: 'Not set'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Anything above the phone number is an administrator\'s to '
                  'change, on the Workers screen.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
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
                const SizedBox(height: 14),
                _PasswordField(
                  label: 'Current password',
                  controller: _currentPassword,
                  focusNode: _currentPasswordFocus,
                  onChanged: _recheckPasswords,
                ),
                const SizedBox(height: 12),
                _PasswordField(
                  label: 'New password',
                  controller: _newPassword,
                  focusNode: _newPasswordFocus,
                  onChanged: _recheckPasswords,
                ),
                const SizedBox(height: 12),
                _PasswordField(
                  label: 'Confirm new password',
                  controller: _confirmPassword,
                  focusNode: _confirmPasswordFocus,
                  onChanged: _recheckPasswords,
                  hasError: _unconfirmedPassword,
                ),
                const SizedBox(height: 10),
                Text(
                  _unconfirmedPassword
                      ? PasswordRules.describe
                      : (_passwordError ?? PasswordRules.describe),
                  style: TextStyle(
                    fontSize: 12,
                    color: _passwordError == null || _unconfirmedPassword
                        ? AppColors.textSecondary
                        : AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Above the button rather than at the top of the page: Save is at the
          // bottom of a form longer than the screen, so a complaint up there is
          // one the thumb that pressed it would never scroll back to see.
          if (_error != null) ...[
            _ErrorBanner(message: _error!),
            const SizedBox(height: 14),
          ],
          SizedBox(
            // A thumb, sometimes gloved — the login button's height, for the
            // same reason.
            height: 52,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save changes',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final user = AuthProvider.user;
    if (user == null) return;

    final passwordError = _checkPasswords();
    if (passwordError != null) {
      setState(() => _passwordError = passwordError);
      return;
    }

    final newPassword = _newPassword.text.isEmpty ? null : _newPassword.text;

    setState(() {
      _saving = true;
      _error = null;
      _passwordError = null;
    });

    try {
      final updated = await _users.updateProfile(
        // Sent back exactly as they came: the request carries them and they are
        // `NotEmpty` on the API, but this screen never offered to change them.
        name: user.name,
        surname: user.surname,
        email: user.email,
        phoneNumber: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        currentPassword: newPassword == null ? null : _currentPassword.text,
        newPassword: newPassword,
      );

      if (!mounted) return;

      // The top bar's avatar reads the signed-in user, so it has to hear.
      context.read<AuthProvider>().updateCurrentUser(updated);

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
}

/// Who this is, in the shape the top bar's avatar already uses.
class _Identity extends StatelessWidget {
  const _Identity({required this.user, required this.role});

  final User user;
  final String role;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            shape: BoxShape.circle,
          ),
          child: Text(
            user.initials,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.fullName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                role.isEmpty ? user.email : '$role · ${user.email}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
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
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          caption,
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// A fact about the account rather than a field. It is deliberately **not** a
/// disabled `TextField`: on a phone a greyed-out box still reads as something to
/// tap, where a plain label and value does not.
class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 104,
                child: Text(
                  label,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
              Expanded(
                child: Text(
                  value.isEmpty ? 'Not set' : value,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: value.isEmpty
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: AppColors.border),
      ],
    );
  }
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.focusNode,
    this.hasError = false,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final FocusNode? focusNode;

  /// True for an unfinished confirm field - a red outline with no caption of
  /// its own, since nothing has actually been typed wrong yet.
  final bool hasError;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: _hidden,
      onChanged: (_) => widget.onChanged(),
      decoration: InputDecoration(
        labelText: widget.label,
        // A phone keyboard has no shift indicator worth the name, so a password
        // typed blind with one wrong character is refused with no way to see why.
        suffixIcon: IconButton(
          onPressed: () => setState(() => _hidden = !_hidden),
          tooltip: _hidden ? 'Show' : 'Hide',
          icon: Icon(
            _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 20,
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

class _NotSignedIn extends StatelessWidget {
  const _NotSignedIn();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_outlined, size: 38, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              'Nobody is signed in',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'There is no account to edit until someone signs in.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        border: Border.all(color: AppColors.dangerBorder),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
