import '../models/models.dart';
import '../providers/projects_provider.dart';
import '../utils/api_client_exception.dart';
import '../utils/app_theme.dart';
import '../utils/dialogs.dart';
import '../utils/formatters.dart';
import '../utils/project_status_rules.dart';
import '../utils/sarajevo_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'widgets/details_scaffold.dart';
import 'widgets/form_fields.dart';


/// One project, new or existing. Pops `'reload'` once it has written, which is
/// the list screen's cue to refetch.
class ProjectDetailsScreen extends StatefulWidget {
  const ProjectDetailsScreen({super.key, required this.provider, this.row});

  /// Owns the write calls, and already holds the customers, categories and
  /// statuses the dropdowns offer.
  final ProjectsProvider provider;

  /// Null when raising a new project.
  final ProjectRow? row;

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> {
  final _formKey = GlobalKey<FormBuilderState>();

  late final Map<String, dynamic> _initialValue;

  bool _saving = false;
  String? _error;

  bool get _isNew => widget.row == null;

  /// On hold, Delivered or Rejected: the API only ever saves Notes from here
  /// (see `ProjectService.UpdateAsync`), so every other field is disabled
  /// rather than left interactive but quietly ignored on save.
  bool get _locked =>
      !_isNew && ProjectStatusRules.isEditLocked(widget.row!.statusName);

  @override
  void initState() {
    super.initState();

    final row = widget.row;

    _initialValue = {
      'name': row?.name,
      // A new project opens on the next number in this year's run.
      'code': row?.code ?? widget.provider.nextCode,
      'description': row?.description,
      'notes': row?.notes,
      'customerId': row?.customerId,
      'projectCategoryId': row?.categoryId,
      'priority': row?.priority ?? ProjectPriority.medium,
      // Whoever is signed in raised it, unless it was raised before.
      'createdByUserId': row?.createdByUserId ?? widget.provider.signedInUserId,
      'weight': row?.weight.toString(),
      'deliveryCompanyId': row?.deliveryCompanyId,
      'deliveryDate': row?.endDate,
    };
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;

    return DetailsScaffold(
      title: _isNew ? 'New Project' : widget.row!.displayName,
      subtitle: _isNew
          ? 'Raise a project for a customer'
          : 'Created ${formatFullDate(widget.row!.createdAt)}',
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
            if (_locked) ...[
              _LockedStatusBanner(status: widget.row!.statusName),
              const SizedBox(height: AppSpacing.gap),
            ],
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: FormBuilderTextField(
                    name: 'name',
                    autofocus: _isNew,
                    enabled: !_locked,
                    decoration: appInputDecoration('Project name'),
                    validator: FormBuilderValidators.required(
                      errorText: 'A project needs a name.',
                    ),
                  ),
                ),
                const SizedBox(width: formFieldGap),
                Expanded(
                  child: FormBuilderTextField(
                    name: 'code',
                    enabled: !_locked,
                    decoration: appInputDecoration('Project code', hintText: '26-001'),
                    validator: FormBuilderValidators.required(
                      errorText: 'Every project has a code.',
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
                    name: 'weight',
                    enabled: !_locked,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: appInputDecoration('Weight', suffixText: 'kg'),
                    valueTransformer: (value) => value?.replaceAll(',', '.'),
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.required(errorText: 'Weight is required.'),
                      FormBuilderValidators.numeric(errorText: 'Weight must be a number.'),
                      FormBuilderValidators.min(0, errorText: 'Weight cannot be negative.'),
                    ]),
                  ),
                ),
                const SizedBox(width: formFieldGap),
                Expanded(
                  child: SearchableDropdownField<int>(
                    name: 'projectCategoryId',
                    label: 'Category',
                    enabled: !_locked,
                    validator: FormBuilderValidators.required(
                      errorText: 'Pick a category.',
                    ),
                    entries: [
                      for (final ProjectCategory category in provider.categories)
                        DropdownMenuEntry(value: category.id, label: category.name),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: formFieldGap),
            // Production start is no longer picked here - it is set the moment
            // a project actually moves into production, on the overview screen.
            FormBuilderDateTimePicker(
              name: 'deliveryDate',
              enabled: !_locked,
              inputType: InputType.date,
              format: formFieldDateFormat,
              firstDate: DateTime(SarajevoTime.now().year - 2),
              lastDate: DateTime(SarajevoTime.now().year + 3),
              // Left empty until the project is scheduled.
              decoration: appInputDecoration('Delivery date', hintText: 'Not set'),
            ),
            const SizedBox(height: formSectionGap),
            Row(
              children: [
                Expanded(
                  child: SearchableDropdownField<int>(
                    name: 'customerId',
                    label: 'Customer',
                    enabled: !_locked,
                    validator: FormBuilderValidators.required(
                      errorText: 'Pick the customer this is built for.',
                    ),
                    entries: [
                      for (final Company customer in provider.customers)
                        DropdownMenuEntry(value: customer.id, label: customer.name),
                    ],
                  ),
                ),
                const SizedBox(width: formFieldGap),
                Expanded(
                  child: SearchableDropdownField<int?>(
                    name: 'deliveryCompanyId',
                    label: 'Delivery company',
                    enabled: !_locked,
                    // The mockup's Location is this company's city and country.
                    hintText: 'Not assigned',
                    entries: [
                      const DropdownMenuEntry(value: null, label: 'Not assigned'),
                      for (final Company company in provider.deliveryCompanies)
                        DropdownMenuEntry(value: company.id, label: company.name),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.row?.location case final location?) ...[
              const SizedBox(height: 6),
              Text(
                'Delivering to $location',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: formFieldGap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _StatusReadout(
                    status: widget.row?.statusName ?? 'Potential',
                  ),
                ),
                const SizedBox(width: formFieldGap),
                Expanded(
                  child: SearchableDropdownField<ProjectPriority>(
                    name: 'priority',
                    label: 'Priority',
                    enabled: !_locked,
                    validator: FormBuilderValidators.required(
                      errorText: 'Pick a priority.',
                    ),
                    entries: [
                      for (final priority in ProjectPriority.values)
                        DropdownMenuEntry(value: priority, label: priority.label),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: formFieldGap),
            SearchableDropdownField<int>(
              name: 'createdByUserId',
              label: 'Created by',
              enabled: !_locked,
              validator: FormBuilderValidators.required(
                errorText: 'Every project has an author.',
              ),
              entries: [
                for (final User author in provider.authors)
                  DropdownMenuEntry(value: author.id, label: author.fullName),
              ],
            ),
            const SizedBox(height: formSectionGap),
            FormBuilderTextField(
              name: 'description',
              enabled: !_locked,
              minLines: 2,
              maxLines: 3,
              decoration: appInputDecoration(
                'Description',
                hintText: 'What is being built',
              ),
            ),
            const SizedBox(height: formFieldGap),
            FormBuilderTextField(
              name: 'notes',
              minLines: 2,
              maxLines: 4,
              decoration: appInputDecoration(
                'Notes',
                hintText: 'Anything the shop floor or the office should know',
              ),
            ),
          ],
        ),
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
      await widget.provider.saveProject(
        id: widget.row?.id,
        name: (values['name'] as String).trim(),
        code: (values['code'] as String).trim(),
        description: _trimToNull(values['description']),
        notes: _trimToNull(values['notes']),
        customerId: values['customerId'] as int,
        projectCategoryId: values['projectCategoryId'] as int,
        createdByUserId: values['createdByUserId'] as int,
        priority: values['priority'] as ProjectPriority,
        weight: double.parse(values['weight'] as String),
        creationDate: widget.row?.createdAt ?? SarajevoTime.now(),
        deliveryCompanyId: values['deliveryCompanyId'] as int?,
        deliveryDate: values['deliveryDate'] as DateTime?,
      );

      if (!mounted) return;
      showSavedSnackBar(
          context, _isNew ? 'Project created' : 'Project saved');
      Navigator.of(context).pop('reload');
    } catch (error) {
      setState(() {
        _error = _messageFor(error, 'The project could not be saved');
        _saving = false;
      });
    }
  }

  Future<void> _delete() async {
    final row = widget.row!;

    final confirmed = await confirmDialog(
      context,
      title: 'Delete project',
      message: 'Delete "${row.name}"? Only a project nothing has been booked against '
          'can be deleted - one with work hours or transport cargo keeps its history '
          'and is rejected instead.',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.provider.deleteProject(row.id);

      if (!mounted) return;
      showSavedSnackBar(context, 'Project deleted');
      Navigator.of(context).pop('reload');
    } catch (error) {
      setState(() {
        _error = _messageFor(error, 'The project could not be deleted');
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

/// What the field would be, next to a reminder of where it is actually
/// changed - the same shape account settings already uses for a field an
/// administrator, not this screen, owns.
class _StatusReadout extends StatelessWidget {
  const _StatusReadout({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Status', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Text(status, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          'Changed from the project overview screen.',
          style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

/// A project On hold, Delivered or Rejected only ever has its notes changed
/// here - everything else on this form is quietly ignored by the API, so
/// this says so up front rather than letting an edit look like it landed.
class _LockedStatusBanner extends StatelessWidget {
  const _LockedStatusBanner({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        border: Border.all(color: AppColors.warningBorder),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 18, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This project is "$status" - only its notes can be saved from here.',
              style: TextStyle(fontSize: 13, color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}
