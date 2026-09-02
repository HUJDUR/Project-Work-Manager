import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../layouts/master_screen.dart';
import '../layouts/window_chrome.dart';
import '../providers/auth_provider.dart';
import '../utils/api_client_exception.dart';
import '../utils/app_theme.dart';

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
            _FieldLabel('Email'),
            TextFormField(
              controller: _emailController,
              autofocus: true,
              enabled: !isBusy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
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
              child: Text(
                'Forgotten your password? Ask an administrator to reset it.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
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
