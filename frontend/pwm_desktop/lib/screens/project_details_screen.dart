import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../models/models.dart';
import '../providers/projects_provider.dart';
import '../utils/api_client_exception.dart';
import '../utils/app_theme.dart';
import '../utils/dialogs.dart';
import '../utils/formatters.dart';
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
      // A project starts life in production; the first seeded status stands in
      // if the shop ever renames that one.
      'projectStatusId': row?.statusId ??
          _statusIdOf('in production') ??
          widget.provider.statusTypes.firstOrNull?.id,
      'priority': row?.priority ?? ProjectPriority.medium,
      // Whoever is signed in raised it, unless it was raised before.
      'createdByUserId': row?.createdByUserId ?? widget.provider.signedInUserId,
      'weight': row?.weight.toString(),
      'productionStartDate': row?.startDate ?? DateUtils.dateOnly(DateTime.now()),
      'deliveryCompanyId': row?.deliveryCompanyId,
      'deliveryDate': row?.endDate,
    };
  }

  int? _statusIdOf(String name) => widget.provider.statusTypes
      .where((status) => status.name.toLowerCase() == name)
      .map((status) => status.id)
      .firstOrNull;

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;

    return DetailsScaffold(
      title: _isNew ? 'New Project' : widget.row!.displayName,
      subtitle: _isNew
          ? 'Raise a project for a customer'
          : 'Created ${apiTimeToLocal(widget.row!.createdAt).toString().split(' ').first}',
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
                  child: FormBuilderTextField(
                    name: 'name',
                    autofocus: _isNew,
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
                  child: FormBuilderDropdown<int>(
                    name: 'projectCategoryId',
                    isExpanded: true,
                    decoration: appInputDecoration('Category'),
                    validator: FormBuilderValidators.required(
                      errorText: 'Pick a category.',
                    ),
                    items: [
                      for (final ProjectCategory category in provider.categories)
                        DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name, overflow: TextOverflow.ellipsis),
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
                    name: 'productionStartDate',
                    inputType: InputType.date,
                    format: formFieldDateFormat,
                    firstDate: DateTime(DateTime.now().year - 2),
                    lastDate: DateTime(DateTime.now().year + 3),
                    decoration: appInputDecoration('Production start'),
                    validator: FormBuilderValidators.required(
                      errorText: 'The schema needs a production start date.',
                    ),
                  ),
                ),
                const SizedBox(width: formFieldGap),
                Expanded(
                  child: FormBuilderDateTimePicker(
                    name: 'deliveryDate',
                    inputType: InputType.date,
                    format: formFieldDateFormat,
                    firstDate: DateTime(DateTime.now().year - 2),
                    lastDate: DateTime(DateTime.now().year + 3),
                    // Left empty until the project is scheduled.
                    decoration: appInputDecoration('Delivery date', hintText: 'Not set'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: formSectionGap),
            Row(
              children: [
                Expanded(
                  child: FormBuilderDropdown<int>(
                    name: 'customerId',
                    isExpanded: true,
                    decoration: appInputDecoration('Customer'),
                    validator: FormBuilderValidators.required(
                      errorText: 'Pick the customer this is built for.',
                    ),
                    items: [
                      for (final Company customer in provider.customers)
                        DropdownMenuItem(
                          value: customer.id,
                          child: Text(customer.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: formFieldGap),
                Expanded(
                  child: FormBuilderDropdown<int?>(
                    name: 'deliveryCompanyId',
                    isExpanded: true,
                    decoration: appInputDecoration(
                      'Delivery company',
                      // The mockup's Location is this company's city and country.
                      hintText: 'Not assigned',
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Not assigned')),
                      for (final Company company in provider.deliveryCompanies)
                        DropdownMenuItem(
                          value: company.id,
                          child: Text(company.name, overflow: TextOverflow.ellipsis),
                        ),
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
              children: [
                Expanded(
                  child: FormBuilderDropdown<int>(
                    name: 'projectStatusId',
                    isExpanded: true,
                    decoration: appInputDecoration('Status'),
                    validator: FormBuilderValidators.required(
                      errorText: 'Pick a status.',
                    ),
                    items: [
                      for (final ProjectStatusType status in provider.statusTypes)
                        DropdownMenuItem(
                          value: status.id,
                          child: Text(status.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: formFieldGap),
                Expanded(
                  child: FormBuilderDropdown<ProjectPriority>(
                    name: 'priority',
                    isExpanded: true,
                    decoration: appInputDecoration('Priority'),
                    validator: FormBuilderValidators.required(
                      errorText: 'Pick a priority.',
                    ),
                    items: [
                      for (final priority in ProjectPriority.values)
                        DropdownMenuItem(
                          value: priority,
                          child: Text(priority.label),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: formFieldGap),
            FormBuilderDropdown<int>(
              name: 'createdByUserId',
              isExpanded: true,
              decoration: appInputDecoration('Created by'),
              validator: FormBuilderValidators.required(
                errorText: 'Every project has an author.',
              ),
              items: [
                for (final User author in provider.authors)
                  DropdownMenuItem(
                    value: author.id,
                    child: Text(author.fullName, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
            const SizedBox(height: formSectionGap),
            FormBuilderTextField(
              name: 'description',
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
        projectStatusId: values['projectStatusId'] as int,
        createdByUserId: values['createdByUserId'] as int,
        priority: values['priority'] as ProjectPriority,
        weight: double.parse(values['weight'] as String),
        creationDate: widget.row?.createdAt ?? DateTime.now(),
        productionStartDate: values['productionStartDate'] as DateTime,
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
      message: 'Delete "${row.name}"? Its work hours and transports go with it.',
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
