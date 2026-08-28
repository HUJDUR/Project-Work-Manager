import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../providers/work_hours_provider.dart';
import '../../utils/api_client_exception.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';

class AddWorkHoursDialog extends StatefulWidget {
  const AddWorkHoursDialog({super.key, required this.provider});

  final WorkHoursProvider provider;

  static Future<bool?> show(BuildContext context, WorkHoursProvider provider) =>
      showDialog<bool>(
        context: context,
        builder: (_) => AddWorkHoursDialog(provider: provider),
      );

  @override
  State<AddWorkHoursDialog> createState() => _AddWorkHoursDialogState();
}

class _AddWorkHoursDialogState extends State<AddWorkHoursDialog> {
  int? _userId;
  int? _projectId;
  int? _operationTypeId;
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  TimeOfDay _start = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 15, minute: 0);

  bool _saving = false;
  String? _error;

  DateTime get _startedAt => _at(_start);
  DateTime get _finishedAt => _at(_end);

  DateTime _at(TimeOfDay time) =>
      DateTime(_date.year, _date.month, _date.day, time.hour, time.minute);

  double get _hours => _finishedAt.difference(_startedAt).inMinutes / 60;

  bool get _canSave =>
      !_saving &&
      _userId != null &&
      _projectId != null &&
      _operationTypeId != null &&
      _hours > 0;

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;

    return AlertDialog(
      title: const Text('Add Work Hours'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Dropdown<int>(
                label: 'Worker',
                value: _userId,
                items: {
                  for (final User worker in provider.workers)
                    worker.id: worker.fullName,
                },
                onChanged: (value) => setState(() => _userId = value),
              ),
              const SizedBox(height: 14),
              _Dropdown<int>(
                label: 'Project',
                value: _projectId,
                items: {
                  for (final Project project in provider.projects)
                    project.id: project.name,
                },
                onChanged: (value) => setState(() => _projectId = value),
              ),
              const SizedBox(height: 14),
              _Dropdown<int>(
                label: 'Operation',
                value: _operationTypeId,
                items: {
                  for (final OperationType operation in provider.operationTypes)
                    operation.id: operation.name,
                },
                onChanged: (value) => setState(() => _operationTypeId = value),
              ),
              const SizedBox(height: 14),
              _Field(
                label: 'Date',
                value: formatFullDate(_date),
                icon: Icons.calendar_today_outlined,
                onTap: _pickDate,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      label: 'Start',
                      value: formatTime(_startedAt),
                      icon: Icons.schedule_outlined,
                      onTap: () => _pickTime(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _Field(
                      label: 'End',
                      value: formatTime(_finishedAt),
                      icon: Icons.schedule_outlined,
                      onTap: () => _pickTime(isStart: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _hours > 0 ? 'Books ${formatHours(_hours)}' : 'End must be after start',
                style: TextStyle(
                  fontSize: 13,
                  color: _hours > 0 ? AppColors.textSecondary : Colors.red.shade700,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(fontSize: 13, color: Colors.red.shade700),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSave ? _save : null,
          child: _saving
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.provider.addWorkHours(
        userId: _userId!,
        projectId: _projectId!,
        operationTypeId: _operationTypeId!,
        startedAt: _startedAt,
        finishedAt: _finishedAt,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiClientException catch (error) {
      setState(() {
        _error = error.message;
        _saving = false;
      });
    } catch (error) {
      setState(() {
        _error = 'The work hours could not be saved: $error';
        _saving = false;
      });
    }
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        for (final entry in items.entries)
          DropdownMenuItem(
            value: entry.key,
            child: Text(entry.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: Icon(icon, size: 18),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        child: Text(value, style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}
