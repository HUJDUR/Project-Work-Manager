import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../models/models.dart';
import '../providers/workers_provider.dart';
import '../utils/api_client_exception.dart';
import '../utils/app_theme.dart';
import '../utils/dialogs.dart';
import '../utils/password_rules.dart';
import 'widgets/details_scaffold.dart';
import 'widgets/form_fields.dart';

/// One account, new or existing. Pops `'reload'` once it has written.
class WorkerDetailsScreen extends StatefulWidget {
  const WorkerDetailsScreen({super.key, required this.provider, this.row});

  final WorkersProvider provider;

  /// Null when opening an account.
  final WorkerRow? row;

  @override
  State<WorkerDetailsScreen> createState() => _WorkerDetailsScreenState();
}

class _WorkerDetailsScreenState extends State<WorkerDetailsScreen> {
  final _formKey = GlobalKey<FormBuilderState>();

  late final Map<String, dynamic> _initialValue;

  bool _saving = false;
  String? _error;

  /// The two password fields are driven by controllers this state owns: the
  /// confirmation is checked against the password, and a field's value read back
  /// out of the form is not reliably current while the form is validating.
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  /// What is wrong with the pair, shown under them. Null until a save has been
  /// refused, then kept in step as they are corrected.
  String? _passwordError;

  /// A new account must have a password; an edit keeps the current one when the
  /// field is left alone.
  String? _checkPasswords() {
    if (_isNew && _password.text.isEmpty) {
      return 'A new account needs a password.';
    }

    return PasswordRules.validateChange(
      newPassword: _password.text,
      confirmation: _confirmPassword.text,
    );
  }

  void _recheckPasswords() {
    if (_passwordError == null) return;
    setState(() => _passwordError = _checkPasswords());
  }

  bool get _isNew => widget.row == null;

  @override
  void initState() {
    super.initState();

    final row = widget.row;

    _initialValue = {
      'name': row?.name,
      'surname': row?.surname,
      'email': row?.email,
      'phoneNumber': row?.phoneNumber,
      // The table prints an em dash for an account with no job title; the form
      // should show an empty field rather than that placeholder.
      'jobTitle': row?.jobTitle == '—' ? null : row?.jobTitle,
      'userTypeId': row?.roleId ?? _roleIdOf(WorkersProvider.workerRole),
      'isActive': row?.isActive ?? true,
      'operationIds': row?.operationIds ?? const <int>[],
    };
  }

  int? _roleIdOf(String role) => widget.provider.roles
      .where((type) => type.type.toLowerCase() == role.toLowerCase())
      .map((type) => type.id)
      .firstOrNull;

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;

    return DetailsScaffold(
      title: _isNew ? 'New Worker' : widget.row!.fullName,
      subtitle: _isNew
          ? 'Open an account for someone joining'
          : '${widget.row!.roleName} · ${widget.row!.email}',
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
                  child: FormBuilderTextField(
                    name: 'name',
                    autofocus: _isNew,
                    decoration: appInputDecoration('First name'),
                    validator: FormBuilderValidators.required(
                      errorText: 'A first name is required.',
                    ),
                  ),
                ),
                const SizedBox(width: formFieldGap),
                Expanded(
                  child: FormBuilderTextField(
                    name: 'surname',
                    decoration: appInputDecoration('Surname'),
                    validator: FormBuilderValidators.required(
                      errorText: 'A surname is required.',
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
                    name: 'email',
                    decoration: appInputDecoration('E-mail'),
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.required(
                        errorText: 'Sign-in needs an e-mail address.',
                      ),
                      FormBuilderValidators.email(
                        errorText: 'That is not an e-mail address.',
                      ),
                    ]),
                  ),
                ),
                const SizedBox(width: formFieldGap),
                Expanded(
                  child: FormBuilderTextField(
                    name: 'phoneNumber',
                    decoration: appInputDecoration('Phone', hintText: 'Optional'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: formFieldGap),
            Row(
              children: [
                Expanded(
                  child: FormBuilderTextField(
                    name: 'jobTitle',
                    decoration: appInputDecoration('Job title', hintText: 'Optional'),
                  ),
                ),
                const SizedBox(width: formFieldGap),
                Expanded(
                  child: FormBuilderDropdown<int>(
                    name: 'userTypeId',
                    isExpanded: true,
                    decoration: appInputDecoration('Role'),
                    validator: FormBuilderValidators.required(
                      errorText: 'Pick a role.',
                    ),
                    items: [
                      for (final UserType role in provider.roles)
                        DropdownMenuItem(
                          value: role.id,
                          child: Text(role.type, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: formFieldGap),
            // The pair check each other, so they are plain fields with one
            // complaint worked out in _checkPasswords rather than two validators.
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _password,
                    obscureText: true,
                    onChanged: (_) => _recheckPasswords(),
                    decoration: appInputDecoration(
                      'Password',
                      hintText:
                          _isNew ? null : 'Leave blank to keep the current one',
                    ),
                  ),
                ),
                const SizedBox(width: formFieldGap),
                Expanded(
                  child: TextField(
                    controller: _confirmPassword,
                    obscureText: true,
                    onChanged: (_) => _recheckPasswords(),
                    decoration: appInputDecoration(
                      'Confirm password',
                      hintText: _isNew ? null : 'Only if you are changing it',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _passwordError ?? PasswordRules.describe,
              style: TextStyle(
                fontSize: 12,
                color: _passwordError == null
                    ? AppColors.textSecondary
                    : AppColors.danger,
              ),
            ),
            const SizedBox(height: formFieldGap),
            // The switch is a ListTile, which paints its ink on the nearest
            // Material - the card's decoration would otherwise hide it.
            Material(
              color: Colors.transparent,
              child: FormBuilderSwitch(
                name: 'isActive',
                title: const Text('Currently employed'),
                subtitle: Text(
                  'An account is deactivated rather than deleted when someone leaves.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                decoration: const InputDecoration(border: InputBorder.none),
              ),
            ),
            const SizedBox(height: formFieldGap),
            const Text(
              'Qualified for',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Which operations this person may book hours against. Office staff need none.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            FormBuilderFilterChips<int>(
              name: 'operationIds',
              decoration: const InputDecoration(border: InputBorder.none),
              spacing: 8,
              runSpacing: 4,
              options: [
                for (final OperationType operation in provider.operationTypes)
                  FormBuilderChipOption(
                    value: operation.id,
                    child: Text(operation.name),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final passwordError = _checkPasswords();
    final detailsValid = _formKey.currentState?.saveAndValidate() ?? false;

    if (!detailsValid || passwordError != null) {
      setState(() => _passwordError = passwordError);
      return;
    }

    final values = _formKey.currentState!.value;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.provider.saveWorker(
        id: widget.row?.id,
        name: (values['name'] as String).trim(),
        surname: (values['surname'] as String).trim(),
        email: (values['email'] as String).trim(),
        userTypeId: values['userTypeId'] as int,
        isActive: values['isActive'] as bool? ?? true,
        phoneNumber: _trimToNull(values['phoneNumber']),
        jobTitle: _trimToNull(values['jobTitle']),
        password: _password.text.isEmpty ? null : _password.text,
        operationIds: (values['operationIds'] as List<int>?) ?? const [],
      );

      if (!mounted) return;
      showSavedSnackBar(context, _isNew ? 'Account created' : 'Account saved');
      Navigator.of(context).pop('reload');
    } catch (error) {
      setState(() {
        _error = _messageFor(error, 'The account could not be saved');
        _saving = false;
      });
    }
  }

  Future<void> _delete() async {
    final row = widget.row!;

    final confirmed = await confirmDialog(
      context,
      title: 'Delete account',
      message: 'Delete ${row.fullName}? Deactivating instead keeps their work '
          'history intact.',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.provider.deleteWorker(row.id);

      if (!mounted) return;
      showSavedSnackBar(context, 'Account deleted');
      Navigator.of(context).pop('reload');
    } catch (error) {
      setState(() {
        _error = _messageFor(error, 'The account could not be deleted');
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
