import '../models/models.dart';
import '../providers/work_hours_provider.dart';
import '../utils/api_client_exception.dart';
import '../utils/app_theme.dart';
import '../utils/dialogs.dart';
import '../utils/formatters.dart';
import '../utils/sarajevo_time.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'widgets/details_scaffold.dart';
import 'widgets/form_fields.dart';


/// One booked block of work, new or existing. Pops `'reload'` once it has
/// written. The office always books a finished block - only a clock-in on the
/// phone leaves one running.
class WorkHoursDetailsScreen extends StatefulWidget {
  const WorkHoursDetailsScreen({super.key, required this.provider, this.entry});

  final WorkHoursProvider provider;

  /// Null when booking new hours.
  final WorkHoursEntry? entry;

  @override
  State<WorkHoursDetailsScreen> createState() => _WorkHoursDetailsScreenState();
}

class _WorkHoursDetailsScreenState extends State<WorkHoursDetailsScreen> {
  final _formKey = GlobalKey<FormBuilderState>();

  late final Map<String, dynamic> _initialValue;

  bool _saving = false;
  String? _error;

  /// The corrections behind an existing entry; null for a new one.
  Future<List<WorkHoursChange>>? _history;

  bool get _isNew => widget.entry == null;

  @override
  void initState() {
    super.initState();

    final entry = widget.entry;
    if (entry != null) _history = widget.provider.history(entry);
    final start = entry?.startedAt ?? _defaultStart();

    _initialValue = {
      'userId': entry?.userId,
      'projectId': entry?.projectId,
      'operationTypeId': entry?.operationTypeId,
      'date': DateUtils.dateOnly(start),
      'startedAt': TimeOfDay.fromDateTime(start),
      'finishedAt': TimeOfDay.fromDateTime(
        entry?.finishedAt ?? start.add(const Duration(hours: 8)),
      ),
      'note': entry?.note,
    };
  }

  /// A shift that has not been booked yet starts at seven this morning.
  static DateTime _defaultStart() {
    final today = DateUtils.dateOnly(SarajevoTime.now());
    return today.add(const Duration(hours: 7));
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;

    return DetailsScaffold(
      title: _isNew ? 'Add Work Hours' : widget.entry!.workerName,
      subtitle: _isNew
          ? 'Book a block of work against a project'
          : '${widget.entry!.projectName} · ${formatFullDate(widget.entry!.date)}',
      saving: _saving,
      errorMessage: _error,
      onSave: _save,
      onDelete: _isNew ? null : _delete,
      child: FormBuilder(
        key: _formKey,
        initialValue: _initialValue,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Booked hours stay with their worker; the API refuses a change too.
            SearchableDropdownField<int>(
              name: 'userId',
              label: 'Worker',
              enabled: _isNew,
              validator: FormBuilderValidators.required(
                errorText: 'Pick who worked these hours.',
              ),
              entries: [
                for (final User worker in provider.workers)
                  DropdownMenuEntry(value: worker.id, label: worker.fullName),
              ],
            ),
            const SizedBox(height: formFieldGap),
            Row(
              children: [
                Expanded(
                  child: SearchableDropdownField<int>(
                    name: 'projectId',
                    label: 'Project',
                    validator: FormBuilderValidators.required(
                      errorText: 'Pick the project worked on.',
                    ),
                    // The project's code as well as its name, so "26-028"
                    // finds it as fast as "Silo".
                    entries: [
                      for (final Project project in provider.projects)
                        DropdownMenuEntry(
                          value: project.id,
                          label: project.label,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: formFieldGap),
                Expanded(
                  child: SearchableDropdownField<int>(
                    name: 'operationTypeId',
                    label: 'Operation',
                    validator: FormBuilderValidators.required(
                      errorText: 'Pick the operation.',
                    ),
                    entries: [
                      for (final OperationType operation in provider.operationTypes)
                        DropdownMenuEntry(value: operation.id, label: operation.name),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: formSectionGap),
            Row(
              children: [
                Expanded(
                  child: FormBuilderDateTimePicker(
                    name: 'date',
                    inputType: InputType.date,
                    format: formFieldDateFormat,
                    firstDate: DateTime(SarajevoTime.now().year - 2),
                    lastDate: SarajevoTime.now().add(const Duration(days: 1)),
                    decoration: appInputDecoration('Date'),
                    validator: FormBuilderValidators.required(
                      errorText: 'Pick the day worked.',
                    ),
                  ),
                ),
                const SizedBox(width: formFieldGap),
                Expanded(
                  child: FormBuilderField<TimeOfDay>(
                    name: 'startedAt',
                    validator: (value) =>
                        value == null ? 'Pick a start time.' : null,
                    builder: (field) => _TimeField(field: field, label: 'Started at'),
                  ),
                ),
                FieldSeparator(),
                Expanded(
                  child: FormBuilderField<TimeOfDay>(
                    name: 'finishedAt',
                    validator: (value) =>
                        value == null ? 'Pick a finish time.' : null,
                    builder: (field) => _TimeField(field: field, label: 'Finished at'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: formSectionGap),
            FormBuilderTextField(
              name: 'note',
              maxLines: 2,
              maxLength: workNoteMaxLength,
              decoration: appInputDecoration('Note', hintText: 'Optional'),
              validator: FormBuilderValidators.maxLength(
                workNoteMaxLength,
                errorText: 'Keep the note to $workNoteMaxLength characters or fewer.',
              ),
            ),
            if (_history case final history?) ...[
              const SizedBox(height: formSectionGap),
              _ChangeHistory(history: history),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;

    final values = _formKey.currentState!.value;
    final day = DateUtils.dateOnly(values['date'] as DateTime);
    final startedAt = _at(day, values['startedAt'] as TimeOfDay);
    final finishedAt = _at(day, values['finishedAt'] as TimeOfDay);

    if (!finishedAt.isAfter(startedAt)) {
      setState(() => _error = 'The finish time has to come after the start time.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.provider.saveWorkHours(
        id: widget.entry?.id,
        userId: values['userId'] as int,
        projectId: values['projectId'] as int,
        operationTypeId: values['operationTypeId'] as int,
        startedAt: startedAt,
        finishedAt: finishedAt,
        note: values['note'] as String?,
      );

      if (!mounted) return;
      showSavedSnackBar(context, _isNew ? 'Work hours booked' : 'Work hours saved');
      Navigator.of(context).pop('reload');
    } catch (error) {
      setState(() {
        _error = _messageFor(error, 'The work hours could not be saved');
        _saving = false;
      });
    }
  }

  Future<void> _delete() async {
    final entry = widget.entry!;

    final confirmed = await confirmDialog(
      context,
      title: 'Delete work hours',
      message: 'Delete ${formatHours(entry.totalHours)} booked by '
          '${entry.workerName} on ${formatFullDate(entry.date)}?',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.provider.deleteWorkHours(entry);

      if (!mounted) return;
      showSavedSnackBar(context, 'Work hours deleted');
      Navigator.of(context).pop('reload');
    } catch (error) {
      setState(() {
        _error = _messageFor(error, 'The work hours could not be deleted');
        _saving = false;
      });
    }
  }

  static DateTime _at(DateTime day, TimeOfDay time) =>
      DateTime(day.year, day.month, day.day, time.hour, time.minute);

  String _messageFor(Object error, String fallback) =>
      error is ApiClientException ? error.message : '$fallback: $error';
}

/// Who corrected these hours and when - the trail the office leaves behind it.
/// A worker's own clock-in and clock-out are not corrections and are not listed.
class _ChangeHistory extends StatelessWidget {
  const _ChangeHistory({required this.history});

  final Future<List<WorkHoursChange>> history;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('History', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        FutureBuilder<List<WorkHoursChange>>(
          future: history,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }

            if (snapshot.hasError) {
              return _HistoryNote(
                snapshot.error is ApiClientException
                    ? (snapshot.error as ApiClientException).message
                    : 'The history could not be loaded.',
              );
            }

            final changes = snapshot.data ?? const <WorkHoursChange>[];
            if (changes.isEmpty) {
              return _HistoryNote('No corrections - these hours are as they were booked.');
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final change in changes) _ChangeRow(change: change)],
            );
          },
        ),
      ],
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.change});

  final WorkHoursChange change;

  @override
  Widget build(BuildContext context) {
    final before = change.before;
    final after = change.after;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${change.action} by ${change.changedByName}',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
                ),
              ),
              Text(
                '${formatFullDate(change.changedAt)} ${formatTime(change.changedAt)}',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
          if (before != null) _HistoryNote('Before: $before'),
          if (after != null) _HistoryNote(before == null ? after : 'After: $after'),
        ],
      ),
    );
  }
}

class _HistoryNote extends StatelessWidget {
  const _HistoryNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(text, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    );
  }
}

/// FormBuilder has no clock picker, so this wraps the Material one as a field.
class _TimeField extends StatelessWidget {
  const _TimeField({required this.field, required this.label});

  final FormFieldState<TimeOfDay> field;
  final String label;

  @override
  Widget build(BuildContext context) {
    final value = field.value;

    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: value ?? const TimeOfDay(hour: 7, minute: 0),
        );
        if (picked != null) field.didChange(picked);
      },
      child: InputDecorator(
        decoration: appInputDecoration(label).copyWith(
          errorText: field.errorText,
          suffixIcon: const Icon(Icons.schedule, size: 18),
        ),
        child: Text(
          value == null ? 'Not set' : value.format(context),
          style: TextStyle(
            fontSize: 14,
            color: value == null ? AppColors.textMuted : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
