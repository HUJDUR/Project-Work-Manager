import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../layouts/master_screen.dart';
import '../layouts/window_chrome.dart';
import '../providers/auth_provider.dart';
import '../utils/api_client_exception.dart';
import '../utils/app_roles.dart';
import '../utils/app_theme.dart';
import '../utils/dialogs.dart';

/// Sign-in. Every other screen needs the token this one fetches, so it is what
/// `main` opens on.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onSignedIn});

  /// Where to go once the token is in hand. Defaults to the app frame; a test
  /// passes its own so signing in does not start loading dashboards.
  final VoidCallback? onSignedIn;

  static const _wideLayoutFrom = 880.0;
  static const _cardWidth = 900.0;
  static const _formWidth = 420.0;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();

    if (auth.isBusy || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _errorMessage = null);

    try {
      await auth.login(_emailController.text, _passwordController.text);

      if (!mounted) {
        return;
      }

      // The shop floor books its hours from the mobile app; there is no desktop
      // screen a production worker may open, so the session is dropped again.
      if (!AppRoles.usesDesktop(auth.currentRole)) {
        await auth.signOut();

        if (!mounted) return;

        setState(() => _errorMessage =
            'This account works from the mobile app, not the desktop one.');
        return;
      }

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

  /// Opens the identifier dialog and, once it reports a request was actually
  /// sent, tells the office it happened - the same generic wording either
  /// way, since the API itself never says whether the account existed.
  Future<void> _forgotPassword() async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) => _ForgotPasswordDialog(),
    );

    if (sent == true && mounted) {
      showSavedSnackBar(
        context,
        'If that account exists, an administrator has been notified.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      // Sign-in has no top bar to hang the caption buttons off, and the OS one
      // is hidden, so the window would otherwise be impossible to move or close
      // before signing in.
      body: Column(
        children: [
          const SizedBox(
            height: 36,
            child: DraggableBar(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [WindowControls(height: 36)],
              ),
            ),
          ),
          Expanded(child: _card()),
        ],
      ),
    );
  }

  /// The sign-in card itself, below the caption strip.
  Widget _card() {
    return LayoutBuilder(
        builder: (context, constraints) {
          // Room left for the card once the page padding is taken off both sides
          final available = constraints.maxWidth - AppSpacing.pagePadding * 2;
          final isWide = available >= LoginScreen._wideLayoutFrom;
          final width = math.min(
            available,
            isWide ? LoginScreen._cardWidth : LoginScreen._formWidth,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            child: ConstrainedBox(
              // Centres the card on a tall window, scrolls it on a short one
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - AppSpacing.pagePadding * 2,
              ),
              child: Center(
                child: Container(
                  width: width,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    border: Border.all(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isWide) _BrandPanel(),
                        Expanded(child: _form()),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
    );
  }

  Widget _form() {
    final isBusy = context.watch<AuthProvider>().isBusy;

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sign in',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Use your Project Work Manager account.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 28),
            _FieldLabel('Email or username'),
            TextFormField(
              controller: _emailController,
              autofocus: true,
              enabled: !isBusy,
              textInputAction: TextInputAction.next,
              decoration: _fieldDecoration(
                hint: 'name@pwm.ba or NameSurname',
                icon: Icons.person_outline,
              ),
              validator: (value) => (value?.trim() ?? '').isEmpty
                  ? 'Enter your email or username.'
                  : null,
            ),
            const SizedBox(height: 18),
            _FieldLabel('Password'),
            TextFormField(
              controller: _passwordController,
              enabled: !isBusy,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
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
                    size: 19,
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
              height: 46,
              width: double.infinity,
              child: FilledButton(
                onPressed: isBusy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: isBusy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Sign in',
                        style:
                            TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: isBusy ? null : _forgotPassword,
                child: Text(
                  'Forgotten your password? Notify an administrator.',
                  style: TextStyle(fontSize: 12, color: AppColors.accent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: AppColors.textMuted),
      prefixIcon: Icon(icon, size: 19, color: AppColors.textMuted),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.canvas,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      enabledBorder: border(AppColors.border),
      disabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.accent),
      errorBorder: border(AppColors.dangerBorder),
      focusedErrorBorder: border(AppColors.danger),
      errorStyle: TextStyle(fontSize: 12, color: AppColors.danger),
    );
  }
}

/// Asks for the one thing "Reset password" needs from someone who cannot sign
/// in to give anything else: the identifier the account is known by. Pops
/// `true` once the request has actually gone out, so the caller knows to show
/// its own confirmation - the dialog closes the moment that happens rather
/// than showing one of its own and waiting to be dismissed.
class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog();

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _controller = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Enter your email or username.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await context.read<AuthProvider>().requestPasswordReset(value);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiClientException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(
          () => _error = 'The request could not be sent. Please try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset password'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'An administrator will be notified to reset it for you.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              enabled: !_sending,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                labelText: 'Email or username',
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _sending ? null : _send,
          child: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send request'),
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

/// The left half of the wide layout: the brand block the app's top bar wears,
/// with what the app is for underneath it.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  static const _features = [
    (Icons.folder_outlined, 'Projects, from order to delivery'),
    (Icons.schedule_outlined, 'Hours booked on the shop floor'),
    (Icons.local_shipping_outlined, 'Transport loads and reports'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      color: AppColors.accentSoft,
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.precision_manufacturing_outlined,
              size: 24,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Project Work Manager',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Metal fabrication shop',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          for (final (icon, label) in _features)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: AppColors.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
