import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/project_overview_provider.dart';
import '../providers/projects_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import 'project_details_screen.dart';
import 'transport_screen.dart';
import 'widgets/panel.dart';
import 'widgets/projects_table.dart' show ProjectPriorityChip, ProjectStatusChip;
import 'widgets/transports_table.dart' show TruckLoadStatusChip;
import 'work_hours_screen.dart';

/// The height each row of two panels shares - long enough for the table
/// header, a handful of rows and the button underneath.
const double _panelRowHeight = 320;

/// The read-only overview from `docs/mockups/desktop/Project details.png` -
/// opened from a row in the projects table. Its "Edit Project" button is the
/// only way into [ProjectDetailsScreen], which this leaves untouched.
class ProjectOverviewScreen extends StatefulWidget {
  const ProjectOverviewScreen({
    super.key,
    required this.provider,
    required this.row,
    this.overviewProviderFactory,
  });

  /// Owns the write calls the edit form needs and the lookups it prefills
  /// its dropdowns from.
  final ProjectsProvider provider;

  final ProjectRow row;

  /// Lets a test swap in a provider backed by fake data.
  final ProjectOverviewProvider Function(int projectId)? overviewProviderFactory;

  @override
  State<ProjectOverviewScreen> createState() => _ProjectOverviewScreenState();
}

class _ProjectOverviewScreenState extends State<ProjectOverviewScreen> {
  /// Kept in state rather than read straight off [widget.row]: editing can
  /// change it, and there is no reason to leave the page to see that.
  late ProjectRow _row;

  @override
  void initState() {
    super.initState();
    _row = widget.row;
  }

  Future<void> _editProject() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ProjectDetailsScreen(provider: widget.provider, row: _row),
      ),
    );
    if (result != 'reload' || !mounted) return;

    await widget.provider.refresh();
    if (!mounted) return;

    final fresh = await widget.provider.fetchRow(_row.id);
    if (!mounted) return;
    setState(() => _row = fresh);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => (widget.overviewProviderFactory?.call(_row.id) ??
          ProjectOverviewProvider(projectId: _row.id))
        ..load(),
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(onEdit: _editProject),
              const SizedBox(height: AppSpacing.gap),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _InfoCard(row: _row),
                      const SizedBox(height: AppSpacing.gap),
                      SizedBox(
                        height: _panelRowHeight,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _WorkOnProjectPanel(projectId: _row.id)),
                            const SizedBox(width: AppSpacing.gap),
                            Expanded(child: _OperationsSummaryPanel()),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.gap),
                      SizedBox(
                        height: _panelRowHeight,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _TransportPanel()),
                            const SizedBox(width: AppSpacing.gap),
                            Expanded(child: _BasicInfoPanel(row: _row)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
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
              Text('Project Details',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                'Projects  ›  Project Details',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit Project'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accent,
            side: BorderSide(color: AppColors.accent),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.row});

  final ProjectRow row;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _FieldGroup(children: [
                _Field(label: 'Project Name', text: row.name),
                _Field(label: 'Project Code', text: row.code),
                _Field(label: 'Customer', text: row.customerName),
              ]),
            ),
            _columnDivider(),
            Expanded(
              child: _FieldGroup(children: [
                _Field(label: 'Category', text: row.categoryName),
                _Field(label: 'Status', child: ProjectStatusChip(status: row.statusName)),
                _Field(label: 'Description', text: row.description ?? 'No description'),
              ]),
            ),
            _columnDivider(),
            Expanded(
              child: _FieldGroup(children: [
                _Field(
                  label: 'Planned Start',
                  text: row.startDate == null ? '—' : formatFullDate(row.startDate!),
                ),
                _Field(
                  label: 'Planned End',
                  text: row.endDate == null ? 'Not set' : formatFullDate(row.endDate!),
                ),
              ]),
            ),
            _columnDivider(),
            Expanded(
              child: _FieldGroup(children: [
                _Field(label: 'Created On', text: formatFullDate(row.createdAt)),
                _Field(label: 'Created By', text: row.createdByName),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _columnDivider() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: VerticalDivider(width: 1, color: AppColors.border),
      );
}

class _FieldGroup extends StatelessWidget {
  const _FieldGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final child in children) ...[
          child,
          if (child != children.last) const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, this.text, this.child})
      : assert(text != null || child != null, 'Give a Field either text or a child.');

  final String label;
  final String? text;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        // The status/priority chips centre themselves across whatever width
        // they are given (fine in the table's narrow column, not here) -
        // shrink-wrapping first is what actually pins one to the left.
        if (child case final child?)
          IntrinsicWidth(child: child)
        else
          Text(
            text!,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
      ],
    );
  }
}

/// The muted, small-caps-ish header a mini table inside a panel opens with -
/// there is no sorting or filtering here, just the column names.
class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.columns});

  final List<String> columns;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          for (final label in columns) ...[
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            if (label != columns.last) const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}

class _WorkOnProjectPanel extends StatelessWidget {
  const _WorkOnProjectPanel({required this.projectId});

  final int projectId;

  @override
  Widget build(BuildContext context) {
    final overview = context.watch<ProjectOverviewProvider>();
    final entries = overview.workEntries;

    return Panel(
      title: 'Work on Project',
      subtitle: 'Hours booked against this project',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TableHeader(columns: const ['Worker', 'Operation', 'Date', 'Hours']),
          const Divider(height: 1),
          Expanded(
            child: overview.isLoading && entries.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : entries.isEmpty
                    ? EmptyPanelMessage(
                        message: 'No work has been booked against this project yet.')
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) => _WorkRow(entry: entries[index]),
                      ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => WorkHoursScreen(initialProjectId: projectId),
              )),
              child: const Text('View all work hours'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkRow extends StatelessWidget {
  const _WorkRow({required this.entry});

  final ProjectWorkEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(child: _Cell(entry.workerName)),
          const SizedBox(width: 12),
          Expanded(child: _Cell(entry.operationName)),
          const SizedBox(width: 12),
          Expanded(child: _Cell(formatDate(entry.date))),
          const SizedBox(width: 12),
          Expanded(child: _Cell(formatHours(entry.hours))),
        ],
      ),
    );
  }
}

class _OperationsSummaryPanel extends StatelessWidget {
  const _OperationsSummaryPanel();

  @override
  Widget build(BuildContext context) {
    final overview = context.watch<ProjectOverviewProvider>();
    final summary = overview.operationSummary;

    return Panel(
      title: 'Operations Summary',
      subtitle: 'Total hours per operation',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TableHeader(columns: const ['Operation', 'Total Hours']),
          const Divider(height: 1),
          Expanded(
            child: overview.isLoading && summary.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : summary.isEmpty
                    ? EmptyPanelMessage(message: 'Nothing to add up yet.')
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: summary.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final row = summary[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            child: Row(
                              children: [
                                Expanded(child: _Cell(row.operationName)),
                                const SizedBox(width: 12),
                                Expanded(child: _Cell(formatHours(row.totalHours))),
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

class _TransportPanel extends StatelessWidget {
  const _TransportPanel();

  @override
  Widget build(BuildContext context) {
    final overview = context.watch<ProjectOverviewProvider>();
    final entries = overview.transportEntries;

    return Panel(
      title: 'Transport / Loads',
      subtitle: 'Truck loads carrying this project',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TableHeader(
              columns: const ['Load No.', 'Load Date', 'Carrier', 'Weight (kg)', 'Status']),
          const Divider(height: 1),
          Expanded(
            child: overview.isLoading && entries.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : entries.isEmpty
                    ? EmptyPanelMessage(message: 'Not loaded onto a truck yet.')
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) => _TransportRow(entry: entries[index]),
                      ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => TransportScreen())),
              child: const Text('View all transports'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransportRow extends StatelessWidget {
  const _TransportRow({required this.entry});

  final ProjectTransportEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(child: _Cell(entry.loadNo)),
          const SizedBox(width: 12),
          Expanded(child: _Cell(formatFullDate(entry.loadDate))),
          const SizedBox(width: 12),
          Expanded(child: _Cell(entry.carrierName)),
          const SizedBox(width: 12),
          Expanded(child: _Cell(formatCount(entry.weight))),
          const SizedBox(width: 12),
          Expanded(child: TruckLoadStatusChip(status: entry.statusName)),
        ],
      ),
    );
  }
}

class _BasicInfoPanel extends StatelessWidget {
  const _BasicInfoPanel({required this.row});

  final ProjectRow row;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Basic Information',
      child: SingleChildScrollView(
        child: _FieldGroup(children: [
          _Field(label: 'Weight', text: formatTonnes(row.weight)),
          _Field(label: 'Location', text: row.location ?? 'Not assigned'),
          _Field(label: 'Priority', child: ProjectPriorityChip(priority: row.priority)),
          _Field(label: 'Notes', text: row.notes ?? 'No notes'),
        ]),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
    );
  }
}
