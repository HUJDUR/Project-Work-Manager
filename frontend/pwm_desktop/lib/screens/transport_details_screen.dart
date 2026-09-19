import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../models/models.dart';
import '../providers/transports_provider.dart';
import '../utils/api_client_exception.dart';
import '../utils/app_theme.dart';
import '../utils/dialogs.dart';
import '../utils/formatters.dart';
import 'widgets/details_scaffold.dart';
import 'widgets/form_fields.dart';

/// One truck load, new or existing, with the projects on it underneath. Pops
/// `'reload'` once it has written, which is the list screen's cue to refetch.
class TransportDetailsScreen extends StatefulWidget {
  const TransportDetailsScreen({super.key, required this.provider, this.row});

  /// Owns the write calls, and already holds the carriers, statuses and
  /// projects the dropdowns offer.
  final TransportsProvider provider;

  /// Null when booking a new load.
  final TransportRow? row;

  @override
  State<TransportDetailsScreen> createState() => _TransportDetailsScreenState();
}

class _TransportDetailsScreenState extends State<TransportDetailsScreen> {
  final _formKey = GlobalKey<FormBuilderState>();

  late final Map<String, dynamic> _initialValue;

  /// What was on the truck when the screen opened, so saving can diff against
  /// it; empty for a new load.
  List<TransportLine> _originalLines = const [];

  /// What is on the truck now, as the form has it.
  List<TransportLine> _lines = const [];

  bool _loadingLines = false;
  bool _saving = false;
  String? _error;

  bool get _isNew => widget.row == null;

  @override
  void initState() {
    super.initState();

    final row = widget.row;

    _initialValue = {
      'transportCompanyId': row?.carrierId,
      // A load starts life as Ordered unless the seeded statuses say otherwise.
      'truckLoadStatusId': row?.statusId ?? _statusIdOf('ordered'),
      'loadDate': row?.loadDate ?? DateUtils.dateOnly(DateTime.now()),
      'driverName': row?.driverName,
      'driverSurname': row?.driverSurname,
      'vehicleRegistration': row?.vehicleRegistration,
      'emptyWeight': row?.emptyWeight.toString(),
      'fullWeight': row?.fullWeight.toString(),
      'note': row?.note,
    };

    if (row != null) _loadLines(row.id);
  }

  Future<void> _loadLines(int truckLoadId) async {
    setState(() => _loadingLines = true);

    try {
      final lines = await widget.provider.linesOf(truckLoadId);
      if (!mounted) return;
      setState(() {
        _originalLines = lines;
        _lines = lines;
        _loadingLines = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _messageFor(error, 'The cargo could not be loaded');
        _loadingLines = false;
      });
    }
  }

  int? _statusIdOf(String name) => widget.provider.statusTypes
      .where((status) => status.name.toLowerCase() == name)
      .map((status) => status.id)
      .firstOrNull;

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;

    return DetailsScaffold(
      title: _isNew ? 'New Transport' : widget.row!.transportNo,
      subtitle: _isNew
          ? 'Book a truck for a delivery'
          : '${widget.row!.carrierName} · ${widget.row!.driverFullName}',
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
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: FormBuilderDropdown<int>(
                    name: 'transportCompanyId',
                    isExpanded: true,
                    decoration: appInputDecoration('Carrier'),
                    validator: FormBuilderValidators.required(
                      errorText: 'Pick the carrier taking the load out.',
                    ),
                    items: [
                      for (final Company carrier in provider.carriers)
                        DropdownMenuItem(
                          value: carrier.id,
                          child: Text(carrier.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: formFieldGap),
                Expanded(
                  child: FormBuilderDropdown<int>(
                    name: 'truckLoadStatusId',
                    isExpanded: true,
                    decoration: appInputDecoration('Status'),
                    validator: FormBuilderValidators.required(
                      errorText: 'Pick a status.',
                    ),
                    items: [
                      for (final TruckLoadStatusType status in provider.statusTypes)
                        DropdownMenuItem(
                          value: status.id,
                          child: Text(status.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: formFieldGap),
                Expanded(
                  child: FormBuilderDateTimePicker(
                    name: 'loadDate',
                    inputType: InputType.date,
                    format: formFieldDateFormat,
                    firstDate: DateTime(DateTime.now().year - 2),
                    lastDate: DateTime(DateTime.now().year + 1, 12, 31),
                    decoration: appInputDecoration('Load date'),
                    validator: FormBuilderValidators.required(
                      errorText: 'A load needs a date.',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: formFieldGap),
            Row(
              children: [
                Expanded(
                  child: FormBuilderTextField(
                    name: 'emptyWeight',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: appInputDecoration('Empty weight', suffixText: 'kg'),
                    valueTransformer: (value) => value?.replaceAll(',', '.'),
                    onChanged: (_) => setState(() {}),
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.required(
                        errorText: 'Empty weight is required.',
                      ),
                      FormBuilderValidators.numeric(
                        errorText: 'Empty weight must be a number.',
                      ),
                      FormBuilderValidators.min(
                        0,
                        errorText: 'Empty weight cannot be negative.',
                      ),
                    ]),
                  ),
                ),
                const SizedBox(width: formFieldGap),
                Expanded(
                  child: FormBuilderTextField(
                    name: 'fullWeight',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: appInputDecoration('Full weight', suffixText: 'kg'),
                    valueTransformer: (value) => value?.replaceAll(',', '.'),
                    onChanged: (_) => setState(() {}),
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.required(
                        errorText: 'Full weight is required.',
                      ),
                      FormBuilderValidators.numeric(
                        errorText: 'Full weight must be a number.',
                      ),
                      (value) => _weighsMoreThanEmpty(value)
                          ? null
                          : 'Full weight cannot be below the empty weight.',
                    ]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: formFieldGap),
            InputDecorator(
              decoration: appInputDecoration(
                'Bruto project weight',
                suffixText: 'kg',
              ).copyWith(
                enabled: false,
                helperText: 'Full weight less the empty truck',
                helperStyle: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              child: Text(
                _netWeight.toStringAsFixed(2),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: formFieldGap),
            Row(
              children: [
                Expanded(
                  child: FormBuilderTextField(
                    name: 'driverName',
                    autofocus: _isNew,
                    decoration: appInputDecoration('Driver name'),
                    validator: FormBuilderValidators.required(
                      errorText: 'The driver needs a name.',
                    ),
                  ),
                ),
                const SizedBox(width: formFieldGap),
                Expanded(
                  child: FormBuilderTextField(
                    name: 'driverSurname',
                    decoration: appInputDecoration('Driver surname'),
                    validator: FormBuilderValidators.required(
                      errorText: 'The driver needs a surname.',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: formFieldGap),
            Row(
              children: [
                Expanded(
                  child: FormBuilderTextField(
                    name: 'vehicleRegistration',
                    decoration: appInputDecoration(
                      'Registration',
                      hintText: 'A12-K-345',
                    ),
                    validator: FormBuilderValidators.required(
                      errorText: 'Every load has a vehicle registration.',
                    ),
                  ),
                ),

              ],
            ),
            const SizedBox(height: formFieldGap),
            const SizedBox(height: formFieldGap),
            FormBuilderTextField(
              name: 'note',
              minLines: 2,
              maxLines: 4,
              decoration: appInputDecoration(
                'Note',
                hintText: 'Anything the driver or the yard should know',
              ),
            ),
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 20),
            _CargoSection(
              lines: _lines,
              loading: _loadingLines,
              projects: provider.projects,
              onAdd: _addLine,
              onEdit: _editLine,
              onRemove: _removeLine,
            ),
          ],
        ),
      ),
    );
  }

  /// What is actually on the truck, read live off the two weight fields so the
  /// figure follows what is being typed.
  double get _netWeight {
    final empty = double.tryParse(_currentWeight('emptyWeight')) ?? 0;
    final full = double.tryParse(_currentWeight('fullWeight')) ?? 0;
    return (full - empty).clamp(0, double.infinity);
  }

  String _currentWeight(String field) =>
      (_formKey.currentState?.fields[field]?.value as String? ??
              _initialValue[field] as String? ??
              '')
          .replaceAll(',', '.');

  bool _weighsMoreThanEmpty(String? fullWeight) {
    final full = double.tryParse((fullWeight ?? '').replaceAll(',', '.'));
    final empty = double.tryParse(_currentWeight('emptyWeight'));
    if (full == null || empty == null) return true;
    return full >= empty;
  }

  Future<void> _addLine() async {
    final line = await _editLineDialog();
    if (line == null) return;

    setState(() => _lines = [..._lines, line]);
  }

  Future<void> _editLine(int index) async {
    final line = await _editLineDialog(existing: _lines[index]);
    if (line == null) return;

    setState(() => _lines = [..._lines]..[index] = line);
  }

  void _removeLine(int index) {
    setState(() => _lines = [..._lines]..removeAt(index));
  }

  /// A new line is [TransportLine.isNew] — it has no row behind it yet, which
  /// is what tells saving to insert rather than update.
  Future<TransportLine?> _editLineDialog({TransportLine? existing}) {
    return showDialog<TransportLine>(
      context: context,
      builder: (context) => _CargoLineDialog(
        projects: widget.provider.projects,
        line: existing,
        nextPriority: _lines.length + 1,
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;

    final values = _formKey.currentState!.value;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.provider.saveTransport(
        id: widget.row?.id,
        transportCompanyId: values['transportCompanyId'] as int,
        truckLoadStatusId: values['truckLoadStatusId'] as int,
        loadDate: values['loadDate'] as DateTime,
        driverName: (values['driverName'] as String).trim(),
        driverSurname: (values['driverSurname'] as String).trim(),
        vehicleRegistration: (values['vehicleRegistration'] as String).trim(),
        emptyWeight: double.parse(values['emptyWeight'] as String),
        fullWeight: double.parse(values['fullWeight'] as String),
        note: _trimToNull(values['note']),
        lines: _lines,
        originalLines: _originalLines,
      );

      if (!mounted) return;
      showSavedSnackBar(context, _isNew ? 'Transport created' : 'Transport saved');
      Navigator.of(context).pop('reload');
    } catch (error) {
      setState(() {
        _error = _messageFor(error, 'The transport could not be saved');
        _saving = false;
      });
    }
  }

  Future<void> _delete() async {
    final row = widget.row!;

    final confirmed = await confirmDialog(
      context,
      title: 'Delete transport',
      message: 'Delete ${row.transportNo}? What was loaded onto it goes with it.',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.provider.deleteTransport(row.id);

      if (!mounted) return;
      showSavedSnackBar(context, 'Transport deleted');
      Navigator.of(context).pop('reload');
    } catch (error) {
      setState(() {
        _error = _messageFor(error, 'The transport could not be deleted');
        _saving = false;
      });
    }
  }

  static String? _trimToNull(Object? value) {
    final text = (value as String?)?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  String _messageFor(Object error, String fallback) =>
      error is ApiClientException ? error.message : '$fallback: $error';
}

/// The projects on the truck, in the order they come off it. They are rows in
/// `TruckLoadDetails`, so they are edited here and diffed when the form saves.
class _CargoSection extends StatelessWidget {
  const _CargoSection({
    required this.lines,
    required this.loading,
    required this.projects,
    required this.onAdd,
    required this.onEdit,
    required this.onRemove,
  });

  final List<TransportLine> lines;
  final bool loading;
  final List<Project> projects;
  final VoidCallback onAdd;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onRemove;

  double get _totalNeto =>
      lines.fold(0, (total, line) => total + line.netoWeight);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cargo',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Which projects are on the truck, and in what order they come off',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Tooltip(
              message: projects.isEmpty
                  ? 'There are no projects to load onto this truck yet.'
                  : 'Add cargo',
              child: OutlinedButton.icon(
                onPressed: projects.isEmpty ? null : onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add cargo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: BorderSide(color: AppColors.accent),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: formFieldGap),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (lines.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'Nothing loaded yet.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          )
        else ...[
          for (final (index, line) in lines.indexed) ...[
            _CargoLineTile(
              line: line,
              onEdit: () => onEdit(index),
              onRemove: () => onRemove(index),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${lines.length} ${lines.length == 1 ? 'project' : 'projects'} · '
              '${formatTonnes(_totalNeto)} net',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CargoLineTile extends StatelessWidget {
  const _CargoLineTile({
    required this.line,
    required this.onEdit,
    required this.onRemove,
  });

  final TransportLine line;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _UnloadBadge(
                priority: line.unloadPriority,
                colorName: line.unloadColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      line.projectName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Bruto ${formatCount(line.brutoWeight)} kg · '
                      'Neto ${formatCount(line.netoWeight)} kg'
                      '${line.unloadColor.isEmpty ? '' : ' · ${line.unloadColor}'}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                tooltip: 'Take off the truck',
                icon: Icon(Icons.close, size: 18, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The unload order, in the colour the crew marks the cargo with.
class _UnloadBadge extends StatelessWidget {
  const _UnloadBadge({required this.priority, required this.colorName});

  final int priority;
  final String colorName;

  @override
  Widget build(BuildContext context) {
    final color = unloadColors[colorName] ?? AppColors.textMuted;

    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        '$priority',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

/// The colours the yard marks cargo with. `UnloadColor` is a free-text column,
/// so this is the set the form offers rather than one the database enforces.
const Map<String, Color> unloadColors = {
  'Red': Color(0xFFDC2626),
  'Blue': Color(0xFF2563EB),
  'Green': Color(0xFF16A34A),
  'Yellow': Color(0xFFCA8A04),
  'Orange': Color(0xFFEA580C),
  'Purple': Color(0xFF7C3AED),
  'White': Color(0xFF6B7280),
};

/// One cargo line, added or edited. It writes nothing — it hands the line back
/// to the details screen, which saves the whole load in one go.
class _CargoLineDialog extends StatefulWidget {
  const _CargoLineDialog({
    required this.projects,
    required this.nextPriority,
    this.line,
  });

  final List<Project> projects;
  final int nextPriority;
  final TransportLine? line;

  @override
  State<_CargoLineDialog> createState() => _CargoLineDialogState();
}

class _CargoLineDialogState extends State<_CargoLineDialog> {
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context) {
    final line = widget.line;

    return AlertDialog(
      title: Text(line == null ? 'Add cargo' : 'Edit cargo'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: FormBuilder(
            key: _formKey,
            initialValue: {
              'projectId': line?.projectId,
              'brutoWeight': line?.brutoWeight.toString(),
              'netoWeight': line?.netoWeight.toString(),
              'unloadPriority': (line?.unloadPriority ?? widget.nextPriority).toString(),
              'unloadColor': unloadColors.containsKey(line?.unloadColor)
                  ? line!.unloadColor
                  : unloadColors.keys.first,
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FormBuilderDropdown<int>(
                  name: 'projectId',
                  isExpanded: true,
                  decoration: appInputDecoration('Project'),
                  validator: FormBuilderValidators.required(
                    errorText: 'Pick what is being loaded.',
                  ),
                  items: [
                    for (final project in widget.projects)
                      DropdownMenuItem(
                        value: project.id,
                        child: Text(project.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                ),
                const SizedBox(height: formFieldGap),
                Row(
                  children: [
                    Expanded(
                      child: FormBuilderTextField(
                        name: 'brutoWeight',
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration:
                            appInputDecoration('Bruto weight', suffixText: 'kg'),
                        valueTransformer: (value) => value?.replaceAll(',', '.'),
                        validator: _weightValidator('Bruto weight'),
                      ),
                    ),
                    const SizedBox(width: formFieldGap),
                    Expanded(
                      child: FormBuilderTextField(
                        name: 'netoWeight',
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration:
                            appInputDecoration('Neto weight', suffixText: 'kg'),
                        valueTransformer: (value) => value?.replaceAll(',', '.'),
                        validator: _weightValidator('Neto weight'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: formFieldGap),
                Row(
                  children: [
                    Expanded(
                      child: FormBuilderTextField(
                        name: 'unloadPriority',
                        keyboardType: TextInputType.number,
                        decoration: appInputDecoration('Unload order'),
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(
                            errorText: 'The crew needs an unload order.',
                          ),
                          FormBuilderValidators.integer(
                            errorText: 'The unload order is a whole number.',
                          ),
                          FormBuilderValidators.min(
                            1,
                            errorText: 'The unload order starts at 1.',
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(width: formFieldGap),
                    Expanded(
                      child: FormBuilderDropdown<String>(
                        name: 'unloadColor',
                        isExpanded: true,
                        decoration: appInputDecoration('Marking colour'),
                        items: [
                          for (final entry in unloadColors.entries)
                            DropdownMenuItem(
                              value: entry.key,
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: entry.value,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(entry.key),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _accept, child: const Text('Done')),
      ],
    );
  }

  static FormFieldValidator<String> _weightValidator(String label) =>
      FormBuilderValidators.compose([
        FormBuilderValidators.required(errorText: '$label is required.'),
        FormBuilderValidators.numeric(errorText: '$label must be a number.'),
        FormBuilderValidators.min(0, errorText: '$label cannot be negative.'),
      ]);

  void _accept() {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;

    final values = _formKey.currentState!.value;
    final projectId = values['projectId'] as int;

    Navigator.of(context).pop(
      TransportLine(
        // Zero keeps an added line unwritten until the form saves.
        id: widget.line?.id ?? 0,
        projectId: projectId,
        projectName: widget.projects
                .where((project) => project.id == projectId)
                .map((project) => project.name)
                .firstOrNull ??
            'Unknown project',
        brutoWeight: double.parse(values['brutoWeight'] as String),
        netoWeight: double.parse(values['netoWeight'] as String),
        unloadPriority: int.parse(values['unloadPriority'] as String),
        unloadColor: values['unloadColor'] as String,
      ),
    );
  }
}
