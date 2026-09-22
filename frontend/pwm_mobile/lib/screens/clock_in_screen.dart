import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/active_session.dart';
import '../models/operation_type.dart';
import '../models/project.dart';
import '../providers/clock_in_provider.dart';
import '../utils/api_client_exception.dart';
import '../utils/app_theme.dart';
import '../utils/dialogs.dart';
import '../utils/formatters.dart';

/// Clock In / Clock Out, laid out as in `docs/mockups/mobile/Clockin clockout.png`:
/// the session that is running on top, the form to start one underneath.
///
/// **The mockup's Note field is not built.** Neither `WorkLogs` nor
/// `WorkLogDetails` has a column to put it in, and a field whose text is thrown
/// away the moment it is typed is worse than no field — the same call the
/// Notifications screen makes about its "Notification type" dropdown. Adding it
/// is a migration, which is a schema change rather than a screen change.
class ClockInScreen extends StatelessWidget {
  const ClockInScreen({super.key, this.providerFactory});

  /// Lets a test swap in a provider backed by fake data.
  final ClockInProvider Function()? providerFactory;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => (providerFactory?.call() ?? ClockInProvider())..load(),
      child: Consumer<ClockInProvider>(
        builder: (context, provider, _) {
          if (provider.status == ClockInStatus.failed) {
            return _Failed(
              message: provider.errorMessage ?? 'Clock In could not be loaded.',
              onRetry: provider.load,
            );
          }

          if (provider.status != ClockInStatus.ready) {
            return const Center(child: CircularProgressIndicator());
          }

          return _Body(provider: provider);
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.provider});

  final ClockInProvider provider;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: provider.load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          const SizedBox(height: 4),
          _Heading('Active Session'),
          const SizedBox(height: 10),
          _ActiveSessionCard(provider: provider),
          const SizedBox(height: 24),
          _Heading('Start New Session'),
          const SizedBox(height: 10),
          _NewSessionCard(provider: provider),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

/// The running session, or what stands in for it when there is none.
class _ActiveSessionCard extends StatefulWidget {
  const _ActiveSessionCard({required this.provider});

  final ClockInProvider provider;

  @override
  State<_ActiveSessionCard> createState() => _ActiveSessionCardState();
}

class _ActiveSessionCardState extends State<_ActiveSessionCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // The elapsed time is the only thing that changes on its own, so the tick
    // lives here rather than in the provider — a provider notifying once a
    // second would rebuild the dropdowns and the rest of the screen with it.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.provider.hasActiveSession) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _clockOut() async {
    try {
      await widget.provider.clockOut();

      if (!mounted) return;
      showSavedSnackBar(context, 'Clocked out.');
    } on ApiClientException catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error.message);
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, 'The server could not be reached.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.provider.active;

    if (session == null) {
      return AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
        child: Column(
          children: [
            Icon(Icons.timer_off_outlined, size: 30, color: AppColors.textMuted),
            const SizedBox(height: 10),
            Text(
              'Nothing running',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Start a session below to begin booking time.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final elapsed = session.elapsedAt(DateTime.now());

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SessionHeader(session: session, elapsed: elapsed),
          const SizedBox(height: 14),
          Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),
          _DetailRow(
            icon: Icons.folder_outlined,
            label: 'Project',
            value: session.projectLabel,
          ),
          _DetailRow(
            icon: Icons.settings_outlined,
            label: 'Operation',
            value: session.operationName,
          ),
          _DetailRow(
            icon: Icons.schedule_outlined,
            label: 'Start Time',
            value: formatTime(session.startedAt),
          ),
          _DetailRow(
            icon: Icons.timer_outlined,
            label: 'Elapsed Time',
            value: formatElapsed(elapsed),
            emphasised: true,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: widget.provider.isSubmitting ? null : _clockOut,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: BorderSide(color: AppColors.accent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: widget.provider.isSubmitting
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    )
                  : const Text(
                      'Clock Out',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.session, required this.elapsed});

  final ActiveSession session;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.schedule, size: 23, color: AppColors.accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // The mockup's live dot.
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      session.projectLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Running for ${formatElapsed(elapsed)}',
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasised = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: emphasised ? 15 : 13.5,
                fontWeight: emphasised ? FontWeight.w700 : FontWeight.w600,
                color: emphasised ? AppColors.accent : AppColors.textPrimary,
                // A ticking number that re-measures every second makes the row
                // twitch; fixed-width figures hold it still.
                fontFeatures: emphasised
                    ? const [FontFeature.tabularFigures()]
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewSessionCard extends StatefulWidget {
  const _NewSessionCard({required this.provider});

  final ClockInProvider provider;

  @override
  State<_NewSessionCard> createState() => _NewSessionCardState();
}

class _NewSessionCardState extends State<_NewSessionCard> {
  Future<void> _clockIn() async {
    try {
      await widget.provider.clockIn();

      if (!mounted) return;
      showSavedSnackBar(context, 'Clocked in.');
    } on ApiClientException catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error.message);
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, 'The server could not be reached.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final blocked = provider.clockInBlockedReason;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PickerRow(
            icon: Icons.folder_outlined,
            label: 'Project',
            child: DropdownButtonFormField<int>(
              initialValue: provider.selectedProjectId,
              isExpanded: true,
              hint: const Text('Pick a project'),
              icon: Icon(Icons.keyboard_arrow_down,
                  color: AppColors.textSecondary),
              onChanged: provider.hasActiveSession ? null : provider.selectProject,
              items: [
                for (final Project project in provider.projectOptions)
                  DropdownMenuItem(
                    value: project.id,
                    child: Text(
                      project.code.isEmpty
                          ? project.name
                          : '${project.code} - ${project.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _PickerRow(
            icon: Icons.settings_outlined,
            label: 'Operation',
            child: DropdownButtonFormField<int>(
              initialValue: provider.selectedOperationId,
              isExpanded: true,
              hint: const Text('Pick an operation'),
              icon: Icon(Icons.keyboard_arrow_down,
                  color: AppColors.textSecondary),
              onChanged:
                  provider.hasActiveSession ? null : provider.selectOperation,
              items: [
                for (final OperationType operation in provider.operationOptions)
                  DropdownMenuItem(
                    value: operation.id,
                    child: Text(
                      operation.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: FilledButton(
              onPressed: provider.canClockIn ? _clockIn : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                disabledBackgroundColor:
                    AppColors.accent.withValues(alpha: 0.35),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: provider.isSubmitting && !provider.hasActiveSession
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Clock In',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          if (blocked != null) ...[
            const SizedBox(height: 10),
            Text(
              blocked,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// The mockup's form row: an icon and a label on the left, the control filling
/// what is left.
class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.icon,
    required this.label,
    required this.child,
  });

  static const double _labelWidth = 104;

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: _labelWidth,
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textMuted),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 36, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text(
              'Clock In could not be loaded',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
