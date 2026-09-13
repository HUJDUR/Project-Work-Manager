import 'package:flutter/material.dart';

import '../models/work_day.dart';
import '../providers/my_hours_provider.dart';
import '../utils/api_client_exception.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';

/// What "View entries" opens: the individual blocks of work booked on one day.
///
/// It is handed the provider rather than reaching for one, because it is pushed
/// as a route and so sits outside the list's `ChangeNotifierProvider` — the same
/// reason the desktop's details screens take theirs as an argument.
///
/// Project and operation names are resolved here, not by the list: this is the
/// only screen that shows them, and a period of twenty days would otherwise pay
/// for twenty days of lookups to draw rows that never name anything.
class WorkDayScreen extends StatefulWidget {
  const WorkDayScreen({super.key, required this.day, required this.provider});

  final WorkDay day;
  final MyHoursProvider provider;

  @override
  State<WorkDayScreen> createState() => _WorkDayScreenState();
}

class _WorkDayScreenState extends State<WorkDayScreen> {
  late Future<List<WorkEntry>> _entries;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _entries = widget.provider.entriesFor(widget.day);
  }

  @override
  Widget build(BuildContext context) {
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
              formatDayLabel(widget.day.date),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${formatClockHours(widget.day.hours)} · '
              '${widget.day.blocks.length} '
              '${widget.day.blocks.length == 1 ? 'entry' : 'entries'}',
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
        child: FutureBuilder<List<WorkEntry>>(
          future: _entries,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _Failed(
                message: snapshot.error is ApiClientException
                    ? (snapshot.error as ApiClientException).message
                    : 'This day could not be loaded.',
                onRetry: () => setState(_load),
              );
            }

            final entries = snapshot.data ?? const <WorkEntry>[];

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.pagePadding),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _EntryCard(entry: entries[index]),
            );
          },
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final WorkEntry entry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  entry.projectLabel,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatClockHours(entry.hours),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.build_outlined, size: 15, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  entry.operationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.schedule_outlined, size: 15, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                formatTimeRange(entry.startedAt, entry.finishedAt),
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              if (entry.isOpen) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'In progress',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
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
            Icon(Icons.cloud_off_outlined, size: 34, color: AppColors.textMuted),
            const SizedBox(height: 12),
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
