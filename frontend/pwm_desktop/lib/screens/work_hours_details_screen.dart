import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../models/models.dart';
import '../providers/work_hours_provider.dart';
import '../utils/api_client_exception.dart';
import '../utils/app_theme.dart';
import '../utils/dialogs.dart';
import '../utils/formatters.dart';
import 'widgets/details_scaffold.dart';
import 'widgets/form_fields.dart';

/// One booked block of work, new or existing. Pops `'reload'` once it has
/// written. Both timestamps are `NOT NULL` in the schema, so the form always
/// records a finished block — an open shift still cannot be stored.
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

  bool get _isNew => widget.entry == null;

  @override
  void initState() {
    super.initState();

    final entry = widget.entry;
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
    };
  }

  /// A shift that has not been booked yet starts at seven this morning.
  static DateTime _defaultStart() {
    final today = DateUtils.dateOnly(DateTime.now());
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
            FormBuilderDropdown<int>(
              name: 'userId',
              isExpanded: true,
              decoration: appInputDecoration('Worker'),
              validator: FormBuilderValidators.required(
                errorText: 'Pick who worked these hours.',
              ),
              items: [
                for (final User worker in provider.workers)
                  DropdownMenuItem(
                    value: worker.id,
                    child: Text(worker.fullName, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
            const SizedBox(height: formFieldGap),
            Row(
              children: [
                Expanded(
                  child: FormBuilderDropdown<int>(
                    name: 'projectId',
                    isExpanded: true,
                    decoration: appInputDecoration('Project'),
                    validator: FormBuilderValidators.required(
                      errorText: 'Pick the project worked on.',
                    ),
                    items: [
                      for (final Project project in provider.projects)
                        DropdownMenuItem(
                          value: project.id,
                          child: Text(project.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: formFieldGap),
                Expanded(
                  child: FormBuilderDropdown<int>(
                    name: 'operationTypeId',
                    isExpanded: true,
                    decoration: appInputDecoration('Operation'),
                    validator: FormBuilderValidators.required(
                      errorText: 'Pick the operation.',
                    ),
                    items: [
                      for (final OperationType operation in provider.operationTypes)
                        DropdownMenuItem(
                          value: operation.id,
                          child: Text(operation.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: formFieldGap),
            Row(
              children: [
                Expanded(
                  child: FormBuilderDateTimePicker(
                    name: 'date',
                    inputType: InputType.date,
                    format: formFieldDateFormat,
                    firstDate: DateTime(DateTime.now().year - 2),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
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
                const SizedBox(width: formFieldGap),
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
            const SizedBox(height: formFieldGap),
            Text(
              'Regular and overtime are worked out from the whole day: the first '
              'eight hours a worker books on a date are regular, the rest overtime.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
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
        workLogId: widget.entry?.workLogId,
        userId: values['userId'] as int,
        projectId: values['projectId'] as int,
        operationTypeId: values['operationTypeId'] as int,
        startedAt: startedAt,
        finishedAt: finishedAt,
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
