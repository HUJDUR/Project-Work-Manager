import 'package:flutter/material.dart';

import '../models/project_row.dart';
import '../models/project_work.dart';
import '../providers/projects_provider.dart';
import '../utils/api_client_exception.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import 'widgets/project_status_chip.dart';

/// One project, opened from the list.
///
/// The project itself is handed over with the row, so the facts paint
/// immediately; the only thing fetched here is **this worker's own hours on
/// it**, which the list neither shows nor pays for.
///
/// Handed its provider rather than reaching for one: it is pushed as a route
/// and so sits outside the list's `ChangeNotifierProvider`, the same reason the
/// desktop's details screens take theirs as an argument.
class ProjectDetailsScreen extends StatefulWidget {
  const ProjectDetailsScreen({
    super.key,
    required this.row,
    required this.provider,
  });

  final ProjectRow row;
  final ProjectsProvider provider;

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> {
  late Future<ProjectWork> _work;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _work = widget.provider.workOn(widget.row.id);
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final project = row.project;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: AppColors.border)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              project.code.isEmpty ? project.name : project.code,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (project.code.isNotEmpty)
              Text(
                project.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          children: [
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  StatusPill.status(row.statusName),
                  const SizedBox(width: 10),
                  StatusPill.priority(row.priority),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.gap),
            _DetailsCard(
              row: row,
              delivery: widget.provider.deliveryOf(row),
            ),
            const SizedBox(height: AppSpacing.gap),
            _WorkCard(work: _work, onRetry: () => setState(_load)),
            if ((project.description ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.gap),
              _NotesCard(title: 'Description', body: project.description!),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.row, this.delivery});

  final ProjectRow row;

  /// Where the job goes. Not who ordered it — see
  /// `ProjectsProvider.deliveryOf`.
  final DeliveryPlace? delivery;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle('Details'),
          const SizedBox(height: 4),
          _Row(
            icon: Icons.folder_outlined,
            label: 'Category',
            value: row.categoryName,
          ),
          _Row(
            icon: Icons.local_shipping_outlined,
            label: 'Deliver to',
            value: delivery?.name ?? 'Not set',
          ),
          if ((delivery?.address ?? '').isNotEmpty)
            _Row(
              icon: Icons.location_on_outlined,
              label: 'Address',
              value: delivery!.address,
            ),
          _Row(
            icon: Icons.play_circle_outline,
            label: 'Production start',
            value: _date(row.productionStartDate),
          ),
          _Row(
            icon: Icons.calendar_today_outlined,
            label: 'Delivery date',
            value: _date(row.deliveryDate),
          ),
          _Row(
            icon: Icons.scale_outlined,
            label: 'Weight',
            value: formatTonnes(row.weight),
          ),
        ],
      ),
    );
  }

  static String _date(DateTime? date) =>
      date == null ? 'Not set' : formatFullDate(date);
}

/// "Your work on this project" — the one thing on this screen that costs a
/// request, so it loads on its own and says so if it fails.
class _WorkCard extends StatelessWidget {
  const _WorkCard({required this.work, required this.onRetry});

  final Future<ProjectWork> work;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.schedule, size: 22, color: AppColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(child: _CardTitle('Your work on this project')),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),
          FutureBuilder<ProjectWork>(
            future: work,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return _Failed(
                  message: snapshot.error is ApiClientException
                      ? (snapshot.error as ApiClientException).message
                      : 'Your hours could not be loaded.',
                  onRetry: onRetry,
                );
              }

              final result = snapshot.data ?? ProjectWork.none;

              if (result.isEmpty) {
                return Text(
                  'You have not booked any time against this project.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                );
              }

              return Column(
                children: [
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _Figure(
                            value: formatClockHours(result.hours),
                            label: 'Hours booked',
                          ),
                        ),
                        VerticalDivider(width: 1, color: AppColors.border),
                        Expanded(
                          child: _Figure(
                            value: formatCount(result.days),
                            label: result.days == 1 ? 'Day worked' : 'Days worked',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (result.lastWorked != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Last worked ${formatDayLabel(result.lastWorked!)}',
                      style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(title),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.textMuted),
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
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
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
    return Column(
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Try again'),
        ),
      ],
    );
  }
}
