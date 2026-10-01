import '../layouts/master_navigation.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/monthly_hour_report_provider.dart';
import '../providers/monthly_reports_provider.dart';
import '../utils/api_client_exception.dart';
import '../utils/app_roles.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import 'monthly_reports_screen.dart' show InProgressChip;
import 'package:material_ui/material_ui.dart';
import 'reports_screen.dart';
import 'widgets/panel.dart';
import 'widgets/summary_card.dart';

/// One month opened from the Monthly Reports list: its totals, every worker's
/// hours and the hours per operation.
class MonthlyReportDetailsScreen extends StatefulWidget {
  const MonthlyReportDetailsScreen({
    super.key,
    required this.api,
    required this.report,
    this.role,
  });

  final MonthlyHourReportProvider api;
  final MonthlyHourReport report;

  /// Defaults to the signed-in account's.
  final String? role;

  @override
  State<MonthlyReportDetailsScreen> createState() => _MonthlyReportDetailsScreenState();
}

class _MonthlyReportDetailsScreenState extends State<MonthlyReportDetailsScreen> {
  late Future<MonthlyHourReportOverview> _overview;

  MonthlyHourReport get _report => widget.report;

  String get _title => formatMonth(_report.year, _report.month);

  /// The monthly PDF is not a project manager's - see [AppRoles.canRunReport].
  bool get _canOpenPdf => AppRoles.canRunReport(
        widget.role ?? AuthProvider.role,
        ReportType.monthlyWorkHours,
      );

  @override
  void initState() {
    super.initState();
    _overview = widget.api.overview(_report.id);
  }

  /// Over to Reports with the form set to this month. Outside the shell
  /// (a widget test) the Reports screen is pushed instead.
  void _openPdf() {
    final period = DateTime(_report.year, _report.month);
    final shell = MasterNavigation.maybeOf(context);
    if (shell != null) {
      shell.openMonthlyReport(period);
      return;
    }

    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(body: ReportsScreen(monthlyPeriod: period)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: AppSpacing.gap),
            Expanded(
              child: FutureBuilder<MonthlyHourReportOverview>(
                future: _overview,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    final error = snapshot.error;
                    return Center(
                      child: Text(
                        error is ApiClientException
                            ? error.message
                            : 'This month could not be loaded: $error',
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return _body(snapshot.data!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(_title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                  if (MonthlyReportsProvider.isInProgress(_report)) ...[
                    const SizedBox(width: 12),
                    InProgressChip(),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Monthly Reports  ›  $_title',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        if (_canOpenPdf)
          OutlinedButton.icon(
            onPressed: _openPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text('Open PDF Report'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: BorderSide(color: AppColors.accent),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            ),
          ),
      ],
    );
  }

  Widget _body(MonthlyHourReportOverview overview) {
    final month = overview.month;
    final metrics = <SummaryMetric>[
      SummaryMetric(
        icon: Icons.schedule_outlined,
        label: 'Total Hours',
        value: formatHours(month.totalHours),
        caption: 'booked this month',
      ),
      SummaryMetric(
        icon: Icons.check_circle_outline,
        label: 'Regular Hours',
        value: formatHours(month.regularHours),
        caption: 'first 8 h of a day',
      ),
      SummaryMetric(
        icon: Icons.more_time_outlined,
        label: 'Overtime Hours',
        value: formatHours(month.overtimeHours),
        caption: 'beyond 8 h of a day',
      ),
      SummaryMetric(
        icon: Icons.groups_outlined,
        label: 'Workers',
        value: formatCount(month.workerCount),
        caption: 'with booked hours',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final metric in metrics) ...[
              Expanded(child: SummaryCard(metric: metric)),
              if (metric != metrics.last) const SizedBox(width: AppSpacing.gap),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.gap),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: _WorkersPanel(workers: overview.workers)),
              const SizedBox(width: AppSpacing.gap),
              Expanded(flex: 2, child: _OperationsPanel(operations: overview.operations)),
            ],
          ),
        ),
      ],
    );
  }
}

enum _WorkerSort { name, days, regular, overtime, total }

class _WorkersPanel extends StatefulWidget {
  const _WorkersPanel({required this.workers});

  final List<MonthlyHourReportWorker> workers;

  @override
  State<_WorkersPanel> createState() => _WorkersPanelState();
}

class _WorkersPanelState extends State<_WorkersPanel> {
  _WorkerSort _sort = _WorkerSort.name;
  bool _ascending = true;

  static const _flex = [4, 2, 2, 2, 2];

  void _sortBy(_WorkerSort sort) {
    setState(() {
      if (_sort == sort) {
        _ascending = !_ascending;
      } else {
        _sort = sort;
        // Figures read best biggest first; names A to Z.
        _ascending = sort == _WorkerSort.name;
      }
    });
  }

  List<MonthlyHourReportWorker> get _sorted {
    int compare(MonthlyHourReportWorker a, MonthlyHourReportWorker b) => switch (_sort) {
          _WorkerSort.name => a.workerName.toLowerCase().compareTo(b.workerName.toLowerCase()),
          _WorkerSort.days => a.daysWorked.compareTo(b.daysWorked),
          _WorkerSort.regular => a.regularHours.compareTo(b.regularHours),
          _WorkerSort.overtime => a.overtimeHours.compareTo(b.overtimeHours),
          _WorkerSort.total => a.totalHours.compareTo(b.totalHours),
        };

    return [...widget.workers]..sort((a, b) => _ascending ? compare(a, b) : compare(b, a));
  }

  @override
  Widget build(BuildContext context) {
    const labels = ['Worker', 'Days', 'Regular', 'Overtime', 'Total'];
    final sorted = _sorted;

    return Panel(
      title: 'Workers',
      subtitle: 'Click a column to sort',
      child: widget.workers.isEmpty
          ? EmptyPanelMessage(message: 'Nobody booked hours this month.')
          : Column(
              children: [
                Row(
                  children: [
                    for (var i = 0; i < labels.length; i++)
                      Expanded(
                        flex: _flex[i],
                        child: _SortHeader(
                          label: labels[i],
                          alignEnd: i > 0,
                          active: _sort == _WorkerSort.values[i],
                          ascending: _ascending,
                          onTap: () => _sortBy(_WorkerSort.values[i]),
                        ),
                      ),
                  ],
                ),
                Divider(height: 16, color: AppColors.border),
                Expanded(
                  child: ListView.separated(
                    itemCount: widget.workers.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final worker = sorted[index];
                      final cells = [
                        worker.workerName,
                        formatCount(worker.daysWorked),
                        formatHours(worker.regularHours),
                        formatHours(worker.overtimeHours),
                        formatHours(worker.totalHours),
                      ];

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            for (var i = 0; i < cells.length; i++)
                              Expanded(
                                flex: _flex[i],
                                child: Text(
                                  cells[i],
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: i == 0 ? TextAlign.start : TextAlign.end,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: i == 0 || i == cells.length - 1
                                        ? FontWeight.w600
                                        : null,
                                    color: i == 3 && worker.overtimeHours > 0
                                        ? AppColors.warning
                                        : null,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _SortHeader extends StatelessWidget {
  const _SortHeader({
    required this.label,
    required this.alignEnd,
    required this.active,
    required this.ascending,
    required this.onTap,
  });

  final String label;
  final bool alignEnd;
  final bool active;
  final bool ascending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accent : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color),
            ),
            if (active)
              Icon(
                ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: color,
              ),
          ],
        ),
      ),
    );
  }
}

class _OperationsPanel extends StatelessWidget {
  const _OperationsPanel({required this.operations});

  final List<MonthlyHourReportOperation> operations;

  @override
  Widget build(BuildContext context) {
    final busiest = operations.isEmpty ? 0.0 : operations.first.hours;

    return Panel(
      title: 'Hours by operation',
      subtitle: 'Every worker added together',
      child: operations.isEmpty
          ? EmptyPanelMessage(message: 'No work has been booked this month.')
          : ListView.separated(
              itemCount: operations.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final operation = operations[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            operation.operationName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(
                          formatHours(operation.hours),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: busiest == 0 ? 0 : operation.hours / busiest,
                        minHeight: 6,
                        color: AppColors.seriesAt(index),
                        backgroundColor: AppColors.border,
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
