import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../layouts/master_screen.dart';
import '../providers/auth_provider.dart';
import '../utils/api_client_exception.dart';
import '../utils/app_theme.dart';

/// Sign-in. Every other screen needs the token this one fetches, so it is what
/// `main` opens on.
///
/// It is the desktop's `login_screen.dart` with the same wording, the same
/// field decoration and the same error banner — what differs is that the
/// desktop's wide layout puts a brand panel beside the form, and a phone has
/// only one column, so the brand sits above it and the panel's feature list is
/// dropped: with a keyboard up there is no room for marketing copy.
///
/// Unlike the desktop, no role is turned away here. A production worker is sent
/// away from the desktop because no desktop screen is theirs; the reverse does
/// not hold, and the dashboard shows the signed-in account's own hours, which
/// reads the same whoever signs in.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onSignedIn});

  /// Where to go once the token is in hand. Defaults to the app frame; a test
  /// passes its own so signing in does not start loading the dashboard.
  final VoidCallback? onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// Padding above and below the form, and the height the centring allows for.
  static const double _verticalPadding = 32;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();

    if (auth.isBusy || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    // Out of the way, so the button's spinner is not behind the keyboard.
    FocusScope.of(context).unfocus();
    setState(() => _errorMessage = null);

    try {
      await auth.login(_emailController.text, _passwordController.text);

      if (!mounted) return;

      // Tells the platform the credentials worked, which is what prompts the
      // offer to save them. Skipped on failure, so a wrong password is not
      // what gets stored.
      TextInput.finishAutofillContext();

      if (widget.onSignedIn != null) {
        widget.onSignedIn!();
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MasterScreen()),
      );
    } on ApiClientException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      // A dead API throws http's own ClientException, whose wording is no help here
      setState(() => _errorMessage =
          'The server could not be reached. Check that the API is running.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = context.watch<AuthProvider>().isBusy;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            // `SingleChildScrollView` shrink-wraps, so the form would sit at the
            // top of a tall phone. The minimum height plus `Center` holds it in
            // the middle, and it still scrolls once the keyboard takes the room.
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: _verticalPadding,
            ),
            child: ConstrainedBox(
              // Clamped, because the height left over goes **negative** when the
              // viewport is shorter than the padding — a zero-height layout pass
              // on startup, or a keyboard over a small screen — and a negative
              // minimum is an assertion, not a squeeze.
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - _verticalPadding * 2)
                    .clamp(0.0, double.infinity),
              ),
              child: Center(
                child: ConstrainedBox(
                  // A tablet or a landscape phone would otherwise stretch the
                  // fields the width of the screen.
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _form(isBusy),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(bool isBusy) {
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _Brand(),
            const SizedBox(height: 36),
            Text(
              'Sign in',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Use your Project Work Manager account.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 28),
            _FieldLabel('Email'),
            TextFormField(
              controller: _emailController,
              enabled: !isBusy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
              onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
              decoration: _fieldDecoration(
                hint: 'name@pwm.ba',
                icon: Icons.mail_outline,
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) {
                  return 'Enter your email address.';
                }
                if (!email.contains('@')) {
                  return 'That does not look like an email address.';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            _FieldLabel('Password'),
            TextFormField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              enabled: !isBusy,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              decoration: _fieldDecoration(
                hint: 'Your password',
                icon: Icons.lock_outline,
                suffix: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              validator: (value) =>
                  (value ?? '').isEmpty ? 'Enter your password.' : null,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 20),
              _ErrorBanner(message: _errorMessage!),
            ],
            const SizedBox(height: 28),
            SizedBox(
              // Taller than the desktop's 46: this one is pressed with a thumb,
              // sometimes with a glove on.
              height: 52,
              child: FilledButton(
                onPressed: isBusy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.6),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: isBusy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Sign in',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Forgotten your password? Ask an administrator to reset it.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  /// The desktop's field decoration, with a phone's padding. The per-state
  /// borders are spelled out here rather than left to the theme because this
  /// screen wants a 10px radius to match the button, where the theme's forms
  /// sit at the app's usual one.
  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color colour, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colour, width: width),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 14, color: AppColors.textMuted),
      prefixIcon: Icon(icon, size: 20, color: AppColors.textMuted),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.fieldFill,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      enabledBorder: border(AppColors.fieldBorder),
      disabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.accent, width: 1.4),
      errorBorder: border(AppColors.dangerBorder),
      focusedErrorBorder: border(AppColors.danger, width: 1.4),
      errorStyle: TextStyle(fontSize: 12, color: AppColors.danger),
    );
  }
}

/// The desktop brand panel's mark and title, stacked for one column.
class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.precision_manufacturing_outlined,
            size: 28,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Project Work Manager',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Metal fabrication shop',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.dangerBorder),
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
