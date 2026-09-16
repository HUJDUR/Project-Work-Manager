import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../providers/base_provider.dart';
import '../utils/api_client_exception.dart';
import '../utils/app_theme.dart';
import '../utils/dialogs.dart';
import 'widgets/details_scaffold.dart';
import 'widgets/form_fields.dart';
import 'widgets/lookup_table_config.dart';

/// One reference table behind the Administration screen, generic over its row
/// type so the eleven tables there share one implementation rather than
/// eleven near-identical list/details pairs. `LookupTableConfig<T>` is the
/// seam: everything specific to a table - its provider, its columns, its
/// form's fields - is data, not code.
///
/// These are read whole with `getAll()` rather than paged and searched like
/// Projects or Workers: at seed scale a lookup table is a handful of rows,
/// and building a search object for eleven of them is a lot of API surface
/// for data this small. `WorkHoursProvider` strikes the same bargain.
class LookupTableScreen<T> extends StatefulWidget {
  const LookupTableScreen({super.key, required this.config});

  final LookupTableConfig<T> config;

  @override
  State<LookupTableScreen<T>> createState() => _LookupTableScreenState<T>();
}

enum _LoadStatus { loading, ready, failed }

class _LookupTableScreenState<T> extends State<LookupTableScreen<T>> {
  late final BaseProvider<T> _provider = widget.config.createProvider();

  _LoadStatus _status = _LoadStatus.loading;
  String? _error;
  List<T> _rows = [];

  /// Every dropdown field's options, keyed by `LookupField.key` - loaded once
  /// per screen and handed to both the list (to resolve a foreign key to its
  /// name) and the form (to populate the dropdown itself).
  Map<String, List<DropdownOption>> _dropdownOptions = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = _LoadStatus.loading);

    try {
      final dropdownFields = widget.config.fields.where((f) => f.isDropdown);
      final options = await Future.wait(
        dropdownFields.map((f) async => MapEntry(f.key, await f.loadOptions!())),
      );

      final rows = await _provider.getAll();

      setState(() {
        _dropdownOptions = Map.fromEntries(options);
        _rows = rows;
        _status = _LoadStatus.ready;
      });
    } on ApiClientException catch (error) {
      setState(() {
        _error = error.message;
        _status = _LoadStatus.failed;
      });
    } catch (error) {
      setState(() {
        _error = 'Something went wrong while loading ${widget.config.title}: $error';
        _status = _LoadStatus.failed;
      });
    }
  }

  Map<String, Map<int, String>> get _ctx => _dropdownOptions.map(
        (key, options) => MapEntry(key, {for (final o in options) o.id: o.label}),
      );

  Future<void> _openForm([T? row]) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _LookupFormScreen<T>(
          config: widget.config,
          provider: _provider,
          row: row,
          dropdownOptions: _dropdownOptions,
        ),
      ),
    );

    if (result == 'reload') await _load();
  }

  Future<void> _delete(T row) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Delete this row?',
      message: 'This cannot be undone, and anything elsewhere in the app that '
          'points at it may stop working correctly.',
    );
    if (!confirmed) return;

    try {
      await _provider.remove(widget.config.idOf(row));
      await _load();
      if (mounted) showSavedSnackBar(context, 'Deleted.');
    } on ApiClientException catch (error) {
      if (mounted) showErrorDialog(context, 'Could not delete this row', error.message);
    }
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
            Row(
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
                      Text(widget.config.title,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(widget.config.description,
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _status == _LoadStatus.ready ? () => _openForm() : null,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.gap),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    return switch (_status) {
      _LoadStatus.loading => const Center(child: CircularProgressIndicator()),
      _LoadStatus.failed => _ErrorState(message: _error!, onRetry: _load),
      _LoadStatus.ready => _Table<T>(
          config: widget.config,
          rows: _rows,
          ctx: _ctx,
          onTap: _openForm,
          onDelete: _delete,
        ),
    };
  }
}

class _Table<T> extends StatelessWidget {
  const _Table({
    required this.config,
    required this.rows,
    required this.ctx,
    required this.onTap,
    required this.onDelete,
  });

  final LookupTableConfig<T> config;
  final List<T> rows;
  final Map<String, Map<int, String>> ctx;
  final ValueChanged<T> onTap;
  final ValueChanged<T> onDelete;

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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                for (final column in config.columns)
                  Expanded(
                    child: Text(
                      column.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                const SizedBox(width: 40),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text(
                      'Nothing here yet.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final row = rows[index];

                      return InkWell(
                        onTap: () => onTap(row),
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Row(
                            children: [
                              for (final column in config.columns)
                                Expanded(
                                  child: Text(
                                    column.valueOf(row, ctx),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13.5),
                                  ),
                                ),
                              SizedBox(
                                width: 40,
                                child: IconButton(
                                  onPressed: () => onDelete(row),
                                  tooltip: 'Delete',
                                  icon: Icon(Icons.delete_outline,
                                      size: 18, color: AppColors.danger),
                                ),
                              ),
                            ],
                          ),
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
            const Text('Could not load this table',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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

/// The add/edit form for one row. `row == null` means New, the same tell every
/// other details screen in the app uses.
class _LookupFormScreen<T> extends StatefulWidget {
  const _LookupFormScreen({
    required this.config,
    required this.provider,
    required this.row,
    required this.dropdownOptions,
  });

  final LookupTableConfig<T> config;
  final BaseProvider<T> provider;
  final T? row;
  final Map<String, List<DropdownOption>> dropdownOptions;

  @override
  State<_LookupFormScreen<T>> createState() => _LookupFormScreenState<T>();
}

class _LookupFormScreenState<T> extends State<_LookupFormScreen<T>> {
  final _formKey = GlobalKey<FormBuilderState>();

  bool _saving = false;
  String? _error;

  bool get _isNew => widget.row == null;

  List<LookupField> get _fields => widget.config.fieldsFor(isNew: _isNew);

  Map<String, dynamic> get _initialValue {
    final row = widget.row;
    return row == null ? {} : widget.config.valuesOf(row);
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.saveAndValidate()) return;

    final body = <String, dynamic>{};
    for (final field in _fields) {
      final value = form.value[field.key];

      if (field.numeric || field.isDropdown) {
        body[field.key] = int.tryParse(value.toString());
      } else {
        // An optional field left blank is null, not "" - Company.vat/eori are
        // the two columns that matter here.
        final text = value as String?;
        body[field.key] = (text == null || text.isEmpty) && !field.required ? null : text;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final row = widget.row;
      if (row == null) {
        await widget.provider.insert(body);
      } else {
        await widget.provider.update(widget.config.idOf(row), body);
      }

      if (mounted) Navigator.of(context).pop('reload');
    } on ApiClientException catch (error) {
      setState(() {
        _saving = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DetailsScaffold(
      title: _isNew ? 'New row' : 'Edit row',
      subtitle: widget.config.title,
      saving: _saving,
      errorMessage: _error,
      onSave: _save,
      formWidth: 520,
      child: FormBuilder(
        key: _formKey,
        initialValue: _initialValue,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, field) in _fields.indexed) ...[
              if (index > 0) const SizedBox(height: formFieldGap),
              _fieldWidget(field),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fieldWidget(LookupField field) {
    if (field.isDropdown) {
      final options = widget.dropdownOptions[field.key] ?? const [];

      return FormBuilderDropdown<int>(
        name: field.key,
        isExpanded: true,
        decoration: appInputDecoration(field.label),
        validator: FormBuilderValidators.required(
          errorText: 'Pick a ${field.label.toLowerCase()}.',
        ),
        items: [
          for (final option in options)
            DropdownMenuItem(value: option.id, child: Text(option.label)),
        ],
      );
    }

    return FormBuilderTextField(
      name: field.key,
      autofocus: _isNew && _fields.first.key == field.key,
      keyboardType: field.numeric ? TextInputType.number : TextInputType.text,
      decoration: appInputDecoration(field.label),
      validator: FormBuilderValidators.compose([
        if (field.required)
          FormBuilderValidators.required(errorText: '${field.label} is required.'),
        if (field.numeric) FormBuilderValidators.numeric(),
      ]),
    );
  }
}
