import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../models/dashboard_data.dart';
import 'panel.dart';

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.valueCaption,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final String value;
  final String valueCaption;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                valueCaption,
                style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SquareBadge extends StatelessWidget {
  const _SquareBadge({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class LatestWorkPanel extends StatelessWidget {
  const LatestWorkPanel({super.key, required this.entries});

  final List<WorkEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Latest work',
      subtitle: 'Newest booked operations',
      child: entries.isEmpty
          ? const EmptyPanelMessage(message: 'No work has been booked yet.')
          : ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];

                return _ListRow(
                  leading: _SquareBadge(
                    child: Text(
                      entry.workerInitials,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  title: entry.workerName,
                  subtitle: '${entry.operationName} · ${entry.projectName}',
                  value: formatHours(entry.hours),
                  valueCaption: formatDate(entry.startedAt),
                );
              },
            ),
    );
  }
}

class TransportPanel extends StatelessWidget {
  const TransportPanel({super.key, required this.entries});

  final List<TransportEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Transport',
      subtitle: 'Latest truck loads',
      child: entries.isEmpty
          ? const EmptyPanelMessage(message: 'No truck loads recorded yet.')
          : ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];

                return _ListRow(
                  leading: const _SquareBadge(
                    child: Icon(Icons.local_shipping_outlined,
                        size: 18, color: AppColors.accent),
                  ),
                  title: entry.driverName,
                  subtitle: '${entry.vehicleRegistration} · ${entry.carrierName}',
                  value: formatTonnes(entry.netWeight),
                  valueCaption: formatDate(entry.loadDate),
                );
              },
            ),
    );
  }
}

class ActivityPanel extends StatelessWidget {
  const ActivityPanel({super.key, required this.entries});

  final List<ActivityEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Activity',
      subtitle: 'What happened recently',
      child: entries.isEmpty
          ? const EmptyPanelMessage(message: 'No activity recorded yet.')
          : ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: entries.length,
              itemBuilder: (context, index) => _ActivityRow(
                entry: entries[index],
                isFirst: index == 0,
                isLast: index == entries.length - 1,
              ),
            ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.entry,
    required this.isFirst,
    required this.isLast,
  });

  final ActivityEntry entry;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 18,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 1,
                    color: isFirst ? Colors.transparent : AppColors.border,
                  ),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 1,
                    color: isLast ? Colors.transparent : AppColors.border,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.actorName} · ${formatRelative(entry.date)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
