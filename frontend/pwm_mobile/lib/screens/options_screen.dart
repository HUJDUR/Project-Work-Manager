import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../utils/app_theme.dart';
import 'account_settings_screen.dart';
import 'widgets/account_menu.dart';

/// The Options tab: the same two things the avatar's menu offers, laid out as
/// rows a thumb can hit, plus the light/dark toggle that also lives beside the
/// bell in the top bar — two ways to reach the same [ThemeController], the same
/// bargain the account settings entry already strikes with the avatar's menu.
///
/// Both ways into account settings are deliberate rather than duplicated by
/// accident. The avatar is where somebody coming from another app looks; the
/// tab is where somebody who only knows this bar looks. They run the same two
/// calls — `openAccountSettings` and `signOutToLogin` — so neither can drift.
///
/// Anything about notifications or units still has nothing to set yet.
class OptionsScreen extends StatelessWidget {
  const OptionsScreen({super.key, this.userProvider});

  /// Lets a test swap in a provider backed by a fake.
  final UserProvider? userProvider;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final theme = context.watch<ThemeController>();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      children: [
        const SizedBox(height: 4),
        Text(
          'Options',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your account and this app',
          style: TextStyle(fontSize: 14.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),
        AppCard(
          padding: EdgeInsets.zero,
          child: _ThemeToggleRow(theme: theme),
        ),
        const SizedBox(height: 16),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _OptionRow(
                icon: Icons.manage_accounts_outlined,
                label: 'Account settings',
                caption: user == null
                    ? 'Nobody is signed in'
                    : 'Phone number and password',
                onTap: () => openAccountSettings(context, users: userProvider),
              ),
              Divider(height: 1, color: AppColors.border),
              _OptionRow(
                icon: Icons.logout,
                label: 'Sign out',
                caption: user == null
                    ? 'Back to sign-in'
                    : 'Signed in as ${user.fullName}',
                colour: AppColors.danger,
                showChevron: false,
                onTap: () => signOutToLogin(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The same toggle the top bar's bell-side icon reaches, laid out as a row
/// with a switch rather than a chevron — flipping it is the whole action,
/// there is nowhere for a tap to navigate to.
///
/// Wrapped in its own transparent `Material`, the same thing `_OptionRow` does
/// for its `InkWell` — a `Switch` needs a `Material` ancestor to paint itself,
/// and this card should not depend on the `Scaffold` a host screen happens to
/// wrap it in.
class _ThemeToggleRow extends StatelessWidget {
  const _ThemeToggleRow({required this.theme});

  final ThemeController theme;

  @override
  Widget build(BuildContext context) {
    final tint = AppColors.accent;

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.chip(tint).$1,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                theme.isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                size: 19,
                color: AppColors.chip(tint).$2,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dark mode',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    theme.isDark ? 'On' : 'Off',
                    style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Switch(
              value: theme.isDark,
              onChanged: (_) => theme.toggle(),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.label,
    required this.caption,
    required this.onTap,
    this.colour,
    this.showChevron = true,
  });

  final IconData icon;
  final String label;
  final String caption;
  final VoidCallback onTap;
  final Color? colour;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final tint = colour ?? AppColors.accent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.chip(tint).$1,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 19, color: AppColors.chip(tint).$2),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colour ?? AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (showChevron)
                Icon(
                  Icons.chevron_right,
                  size: 22,
                  color: AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
