import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/app_theme.dart';
import '../account_settings_screen.dart';
import '../login_screen.dart';

/// Ends the session and goes back to sign-in, clearing the stack behind it so
/// the back gesture cannot return to a shell with no account.
///
/// `AuthProvider.signOut` drops the session locally even when telling the API
/// fails, so a dead server does not strand somebody signed in. This works
/// whatever `main.dart`'s `bypassLogin` is set to — that switch only decides
/// what the app opens on.
Future<void> signOutToLogin(BuildContext context) async {
  final navigator = Navigator.of(context, rootNavigator: true);

  await context.read<AuthProvider>().signOut();

  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => LoginScreen()),
    (route) => false,
  );
}

/// The avatar in the top bar, and the menu behind it: who is signed in, the way
/// into account settings, and the way out.
///
/// It is the desktop's `_AccountChip` cut down to what fits a phone's top bar —
/// the same two entries in the same order, but the name and role move *into*
/// the menu, because a 60px bar has no room for them beside the product's name.
class AccountMenuButton extends StatelessWidget {
  const AccountMenuButton({super.key, this.users});

  /// Passed through to [AccountSettingsScreen] so a test can inject a fake.
  final UserProvider? users;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return PopupMenuButton<String>(
      tooltip: 'Account',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      padding: EdgeInsets.zero,
      // Material's default caps a menu at 280, which left "Account settings"
      // 0.6px over its row once the icon and gap were counted.
      constraints: const BoxConstraints(minWidth: 210, maxWidth: 320),
      onSelected: (value) => value == 'settings'
          ? openAccountSettings(context, users: users)
          : signOutToLogin(context),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          // A heading, not a choice: it names the account the two entries below
          // it act on.
          enabled: false,
          height: 58,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                user?.fullName ?? 'Not signed in',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                auth.currentRole.isEmpty
                    ? (user?.email ?? '')
                    : auth.currentRole,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'settings',
          child: _MenuRow(
            icon: Icons.manage_accounts_outlined,
            label: 'Account settings',
          ),
        ),
        PopupMenuItem<String>(
          value: 'signOut',
          child: _MenuRow(
            icon: Icons.logout,
            label: 'Sign out',
            colour: AppColors.danger,
          ),
        ),
      ],
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.accentSoft,
          shape: BoxShape.circle,
        ),
        child: user == null
            ? Icon(Icons.person, size: 20, color: AppColors.textSecondary)
            : Text(
                user.initials,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.colour});

  final IconData icon;
  final String label;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final tint = colour ?? AppColors.textSecondary;

    return Row(
      children: [
        Icon(icon, size: 19, color: tint),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color: colour ?? AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
