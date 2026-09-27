import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../layouts/window_chrome.dart';
import '../models/models.dart';
import '../providers/reports_provider.dart';
import '../utils/app_theme.dart';
import '../utils/dialogs.dart';
import '../utils/formatters.dart';

/// Generates the two PDFs and lists what has been run before, laid out as in
/// `docs/mockups/desktop/Reports.png`.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key, this.providerFactory});

  /// Lets a test swap in a provider backed by fake data.
  final ReportsProvider Function()? providerFactory;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => (providerFactory?.call() ?? ReportsProvider())..load(),
      child: Consumer<ReportsProvider>(
        builder: (context, provider, _) {
          return switch (provider.status) {
            ReportsStatusState.failed => _ErrorState(
                message: provider.errorMessage ?? 'Reports could not be loaded.',
                onRetry: provider.load,
              ),
            ReportsStatusState.ready => _Body(provider: provider),
            _ => const Center(child: CircularProgressIndicator()),
          };
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.provider});

  final ReportsProvider provider;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(),
          const SizedBox(height: AppSpacing.gap),
          _TypeCards(provider: provider),
          const SizedBox(height: AppSpacing.gap),
          _ParameterBar(provider: provider),
          if (provider.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.gap),
            _ErrorBanner(message: provider.errorMessage!),
          ],
          const SizedBox(height: AppSpacing.gap),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: _PreviewPanel(provider: provider)),
                const SizedBox(width: AppSpacing.gap),
                Expanded(flex: 2, child: _RecentPanel(provider: provider)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reports', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        SizedBox(height: 2),
        Text(
          'Generate and download PDF reports',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// The two reports the API can build, picked like radio buttons.
class _TypeCards extends StatelessWidget {
  const _TypeCards({required this.provider});

  static const _blurbs = <ReportType, (IconData, String)>{
    ReportType.monthlyWorkHours: (
      Icons.calendar_month_outlined,
      'Per worker hours for a selected month, with regular and overtime split, '
          'plus total hours by operation type across every worker.',
    ),
    ReportType.transportLoads: (
      Icons.local_shipping_outlined,
      'Truck loads and transport records for a selected project, with driver, '
          'vehicle and weight details.',
    ),
  };

  final ReportsProvider provider;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final type in provider.availableTypes) ...[
          Expanded(
            child: _TypeCard(
              type: type,
              icon: _blurbs[type]!.$1,
              blurb: _blurbs[type]!.$2,
              selected: provider.type == type,
              onTap: () => provider.setType(type),
            ),
          ),
          if (type != provider.availableTypes.last)
            const SizedBox(width: AppSpacing.gap),
        ],
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.type,
    required this.icon,
    required this.blurb,
    required this.selected,
    required this.onTap,
  });

  final ReportType type;
  final IconData icon;
  final String blurb;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 21, color: AppColors.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.label,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      blurb,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _SelectedDot(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

/// The mockup's radio, drawn rather than borrowed: Material's `Radio` wants a
/// `RadioGroup` ancestor, and the card itself is what takes the tap.
class _SelectedDot extends StatelessWidget {
  const _SelectedDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.border,
          width: 1.5,
        ),
      ),
      child: selected
          ? Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent,
              ),
            )
          : null,
    );
  }
}

/// The parameters the selected report takes, and the button that runs it. The
/// two reports do not take the same ones, so the row is built per type.
class _ParameterBar extends StatelessWidget {
  const _ParameterBar({required this.provider});

  final ReportsProvider provider;

  @override
  Widget build(BuildContext context) {
    final monthly = provider.type == ReportType.monthlyWorkHours;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (monthly) ...[
          Expanded(
            child: _Labelled(
              label: 'Period',
              child: DropdownButtonFormField<DateTime>(
                initialValue: provider.periods.firstWhere(
                  (month) => month == provider.period,
                  orElse: () => provider.periods.first,
                ),
                isExpanded: true,
                decoration: _fieldDecoration,
                items: [
                  for (final month in provider.periods)
                    DropdownMenuItem(
                      value: month,
                      child: Text(ReportsProvider.periodLabel(month)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) provider.setPeriod(value);
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Labelled(
              label: 'Worker',
              child: DropdownButtonFormField<int?>(
                initialValue: provider.userId,
                isExpanded: true,
                decoration: _fieldDecoration,
                items: [
                  const DropdownMenuItem(value: null, child: Text('All workers')),
                  for (final User worker in provider.workers)
                    DropdownMenuItem(
                      value: worker.id,
                      child: Text(worker.fullName, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: provider.setWorker,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: _Labelled(
            label: 'Project',
            child: DropdownButtonFormField<int?>(
              initialValue: provider.projectId,
              isExpanded: true,
              decoration: _fieldDecoration,
              items: [
                const DropdownMenuItem(value: null, child: Text('All projects')),
                for (final Project project in provider.projects)
                  DropdownMenuItem(
                    value: project.id,
                    child: Text(project.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: provider.setProject,
            ),
          ),
        ),
        if (!monthly) ...[
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _Labelled(
              label: 'Loaded between',
              child: _DateRangeField(provider: provider),
            ),
          ),
        ],
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: provider.generating ? null : provider.generate,
          icon: provider.generating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add, size: 18),
          label: const Text('Generate Report'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          ),
        ),
      ],
    );
  }

  static const _fieldDecoration = InputDecoration(
    border: OutlineInputBorder(),
    isDense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
  );
}

class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// The quick choices the picker's menu offers before falling back to a custom
/// range. Kept in one place with [_DateRangeField._rangeFor] so a preset's
/// label and the dates it means can never drift apart.
enum _DatePreset {
  thisWeek('This week'),
  lastWeek('Last week'),
  thisMonth('This month'),
  lastMonth('Last month'),
  thisYear('This year'),
  allDates('All dates'),
  custom('Custom range…');

  const _DatePreset(this.label);

  final String label;
}

class _DateRangeField extends StatelessWidget {
  const _DateRangeField({required this.provider});

  final ReportsProvider provider;

  @override
  Widget build(BuildContext context) {
    final range = provider.dateRange;
    final label = range == null
        ? 'All dates'
        : '${formatDate(range.start)} - ${formatFullDate(range.end)}';

    return Row(
      children: [
        Expanded(
          child: PopupMenuButton<_DatePreset>(
            tooltip: '',
            offset: const Offset(0, 8),
            itemBuilder: (context) => [
              for (final preset in _DatePreset.values) ...[
                if (preset == _DatePreset.allDates) const PopupMenuDivider(),
                PopupMenuItem(value: preset, child: Text(preset.label)),
              ],
            ],
            onSelected: (preset) => _apply(context, preset),
            child: InputDecorator(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: range == null ? AppColors.textMuted : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
        ),
        if (range != null)
          IconButton(
            tooltip: 'Clear date range',
            icon: const Icon(Icons.close, size: 16),
            onPressed: () => provider.setDateRange(null),
          ),
      ],
    );
  }

  Future<void> _apply(BuildContext context, _DatePreset preset) async {
    switch (preset) {
      case _DatePreset.allDates:
        provider.setDateRange(null);
      case _DatePreset.custom:
        await _pickCustom(context);
      default:
        provider.setDateRange(_rangeFor(preset));
    }
  }

  /// Every "this …" preset runs up to today, not to the end of its period -
  /// there is never data past today to report on. Every "last …" preset is a
  /// full, wholly-past period.
  static DateTimeRange _rangeFor(_DatePreset preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfThisWeek = today.subtract(Duration(days: today.weekday - 1));

    return switch (preset) {
      _DatePreset.thisWeek => DateTimeRange(start: startOfThisWeek, end: today),
      _DatePreset.lastWeek => DateTimeRange(
          start: startOfThisWeek.subtract(const Duration(days: 7)),
          end: startOfThisWeek.subtract(const Duration(days: 1)),
        ),
      _DatePreset.thisMonth =>
        DateTimeRange(start: DateTime(today.year, today.month, 1), end: today),
      _DatePreset.lastMonth => DateTimeRange(
          start: DateTime(today.year, today.month - 1, 1),
          end: DateTime(today.year, today.month, 1).subtract(const Duration(days: 1)),
        ),
      _DatePreset.thisYear => DateTimeRange(start: DateTime(today.year, 1, 1), end: today),
      _DatePreset.allDates || _DatePreset.custom =>
        throw ArgumentError('${preset.name} is handled separately, not as a fixed range.'),
    };
  }

  Future<void> _pickCustom(BuildContext context) async {
    final now = DateTime.now();
    final picked = await pickDateRange(
      context,
      initialDateRange: provider.dateRange,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) provider.setDateRange(picked);
  }
}

/// The generated document itself. `printing` renders the same bytes the API
/// answered, so what is on screen is what prints and what downloads.
class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({required this.provider});

  final ReportsProvider provider;

  @override
  Widget build(BuildContext context) {
    final pdf = provider.pdf;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                const Text(
                  'Report Preview',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Flexible(
                  child: Tooltip(
                    // The label is the first thing cut when the panel is narrow,
                    // so the whole of it is available on hover.
                    message: provider.pdfLabel ?? '',
                    child: Text(
                      provider.pdfLabel ?? 'Nothing generated yet',
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: pdf == null
                      ? null
                      : () => openFullScreenReport(
                            context,
                            pdf: pdf,
                            label: provider.pdfLabel ?? '',
                            fileName: provider.fileName,
                          ),
                  tooltip: 'Full screen',
                  icon: const Icon(Icons.open_in_full, size: 18),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: pdf == null
                ? _NoPreview()
                : PdfPreview(
                    build: (_) => pdf,
                    useActions: false,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                    padding: const EdgeInsets.all(12),
                    pdfFileName: provider.fileName,
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: pdf == null
                      ? null
                      : () => printReport(context, pdf, provider.fileName),
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: const Text('Print'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: pdf == null
                      ? null
                      : () => saveReport(context, pdf, provider.fileName),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Download PDF'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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

/// Hands the bytes to the OS print dialog. Shared by the panel and the
/// full-screen view, which show the same document.
Future<void> printReport(
    BuildContext context, Uint8List pdf, String fileName) async {
  try {
    await Printing.layoutPdf(onLayout: (_) async => pdf, name: fileName);
  } catch (error) {
    if (context.mounted) {
      showErrorDialog(context, 'Printing failed', '$error');
    }
  }
}

/// `Printing.sharePdf` has no save-location concept on Windows - it just drops
/// the file in temp and opens it - so the actual "where do you want this"
/// prompt comes from `file_selector`'s native Save As dialog instead.
Future<void> saveReport(
    BuildContext context, Uint8List pdf, String fileName) async {
  try {
    final location = await getSaveLocation(
      suggestedName: fileName,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'PDF', extensions: ['pdf']),
      ],
    );
    if (location == null) return;

    await File(location.path).writeAsBytes(pdf);
  } catch (error) {
    if (context.mounted) {
      showErrorDialog(context, 'The PDF could not be saved', '$error');
    }
  }
}

/// Opens the document over the whole window. It is pushed on the **root**
/// navigator, not the one `MasterScreen` gives each destination, so it covers
/// the sidebar and the top bar rather than only the content area - which is why
/// it has to carry the window's caption buttons itself.
Future<void> openFullScreenReport(
  BuildContext context, {
  required Uint8List pdf,
  required String label,
  required String fileName,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(
      builder: (_) => FullScreenReport(pdf: pdf, label: label, fileName: fileName),
    ),
  );
}

/// The generated report on its own, filling the window. Escape closes it.
class FullScreenReport extends StatelessWidget {
  const FullScreenReport({
    super.key,
    required this.pdf,
    required this.label,
    required this.fileName,
  });

  final Uint8List pdf;
  final String label;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape):
            Navigator.of(context).maybePop,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.canvas,
          body: Column(
            children: [
              AppWindowBar(
                title: 'Report Preview',
                subtitle: label,
                leading: IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: 'Close full screen (Esc)',
                  icon: const Icon(Icons.close_fullscreen, size: 18),
                  color: AppColors.textSecondary,
                ),
                actions: [
                  OutlinedButton.icon(
                    onPressed: () => printReport(context, pdf, fileName),
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: const Text('Print'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => saveReport(context, pdf, fileName),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Download PDF'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ],
              ),
              const Divider(height: 1),
              Expanded(
                child: PdfPreview(
                  build: (_) => pdf,
                  useActions: false,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                  padding: const EdgeInsets.all(20),
                  pdfFileName: fileName,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoPreview extends StatelessWidget {
  const _NoPreview();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.picture_as_pdf_outlined, size: 40, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text(
            'No report generated yet',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 4),
          Text(
            'Pick a report, set its parameters and press Generate Report.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// What has been run before. Nothing stores the PDF, so opening one re-runs it
/// against today's work logs.
class _RecentPanel extends StatelessWidget {
  const _RecentPanel({required this.provider});

  final ReportsProvider provider;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Text(
              'Recent Reports',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: provider.recent.isEmpty
                ? Center(
                    child: Text(
                      'No reports have been generated yet.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    itemCount: provider.recent.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) => _RecentTile(
                      report: provider.recent[index],
                      onOpen: () => provider.openRecent(provider.recent[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.report, required this.onOpen});

  final RecentReport report;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.description_outlined,
                  size: 18, color: AppColors.danger),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          report.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                      if (report.status != ReportRunStatus.completed) ...[
                        const SizedBox(width: 8),
                        Tooltip(
                          message: report.status == ReportRunStatus.failed
                              ? report.errorMessage ?? 'The report could not be generated.'
                              : 'pwm.Worker has not finished this one yet.',
                          child: _StatusPill(status: report.status),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    report.summary,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  Text(
                    report.generatedAt == null
                        ? report.generatedByName
                        : '${report.generatedByName} · '
                            '${formatRelative(apiTimeToLocal(report.generatedAt!))}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onOpen,
              tooltip: 'Run it again',
              icon: Icon(Icons.download_outlined,
                  size: 18, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row still queued, being rendered by `pwm.Worker`, or one it could not
/// finish - "Completed" rows show no badge at all, so this only ever appears
/// while there is something the office might want to know about.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final ReportRunStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, accent) = switch (status) {
      ReportRunStatus.pending => ('Queued', AppColors.textMuted),
      ReportRunStatus.processing => ('Generating', AppColors.accent),
      ReportRunStatus.failed => ('Failed', AppColors.danger),
      ReportRunStatus.completed => ('', AppColors.textMuted),
    };

    final (background, foreground) = AppColors.chip(accent);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: foreground),
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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        border: Border.all(color: AppColors.dangerBorder),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Row(
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text(
              'Reports could not be loaded',
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
              // Default icon-button padding is asymmetric; this centers it.
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
