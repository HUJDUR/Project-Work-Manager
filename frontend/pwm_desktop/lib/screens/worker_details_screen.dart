import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../models/models.dart';
import '../providers/workers_provider.dart';
import '../utils/api_client_exception.dart';
import '../utils/app_roles.dart';
import '../utils/app_theme.dart';
import '../utils/dialogs.dart';
import '../utils/password_rules.dart';
import '../utils/phone_rules.dart';
import 'widgets/details_scaffold.dart';
import 'widgets/form_fields.dart';
import 'widgets/user_avatar.dart';

/// Mirrored on the API by `PictureRules.MaxSizeBytes` - this is a friendlier,
/// earlier refusal, not the only check.
const _maxPictureBytes = 5 * 1024 * 1024;

const _pictureTypeGroup = XTypeGroup(
  label: 'Images',
  extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
);

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

  /// Base64, fetched by id when editing (the list the row came from carries
  /// no pictures) and replaced when a new picture is picked, or cleared back
  /// to null (the name-letters avatar) by Remove.
  String? _picture;

  /// The fetch behind [_picture]; null for a new account.
  Future<void>? _pictureLoad;

  /// Set once a picture is picked or removed here, which the fetch must not undo.
  bool _pictureTouched = false;

  /// False until Save has been pressed once. `FormBuilder`'s own
  /// `autovalidateMode` validates every field the moment any one of them
  /// changes, not just the one being typed in - so each field is instead
  /// re-checked by hand, on its own `onChanged`, and only once there is
  /// something on screen worth keeping in step.
  bool _saveAttempted = false;

  /// Fields that have been focused and then left, each the first time it
  /// happens - from then on that one field validates live too, the same
  /// as every field does once Save has been pressed.
  final _touchedFields = <String>{};

  final _nameFocus = FocusNode();
  final _surnameFocus = FocusNode();
  final _emailFocus = FocusNode();

  /// Validates a field the moment it is left, not only once Save is pressed -
  /// so leaving a broken field behind (typed, then emptied again) is caught
  /// on the way out rather than staying silent until submit.
  void _onFieldBlurred(String name, FocusNode node) {
    if (node.hasFocus) return;
    _touchedFields.add(name);
    _formKey.currentState?.fields[name]?.validate(focusOnInvalid: false);
  }

  /// Re-validates one field in isolation - never the whole form, which would
  /// surface every other untouched field's error along with it.
  void _revalidateField(String name) {
    if (!_saveAttempted && !_touchedFields.contains(name)) return;
    _formKey.currentState?.fields[name]?.validate(focusOnInvalid: false);
  }

  /// The two password fields are driven by controllers this state owns: the
  /// confirmation is checked against the password, and a field's value read back
  /// out of the form is not reliably current while the form is validating.
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

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

  /// Checks the pair the moment either is left, not only once Save is pressed -
  /// same treatment leaving the name/e-mail fields already gets.
  void _onPasswordFieldBlurred(FocusNode node) {
    if (node.hasFocus) return;
    setState(() => _passwordError = _checkPasswords());
  }

  /// The confirm field is just empty so far, not actually wrong - shown as an
  /// unfinished (red, captionless) field rather than as an error message.
  bool get _unconfirmedPassword =>
      _passwordError == PasswordRules.confirmationNeeded;

  bool get _isNew => widget.row == null;

  /// Which role is currently picked, kept in state (rather than read back from
  /// the form) so choosing a new one can immediately change which operations
  /// are offered below it.
  int? _selectedRoleId;

  @override
  void initState() {
    super.initState();

    final row = widget.row;

    _selectedRoleId = row?.roleId ?? _roleIdOf(WorkersProvider.workerRole);
    if (row != null) {
      _pictureLoad = widget.provider.fetchPicture(row.id).then((picture) {
        // A picture picked or removed while this was in flight wins.
        if (mounted && !_pictureTouched) setState(() => _picture = picture);
      });
      // A failed fetch is reported by Save, which awaits this same future -
      // not as an unhandled error the moment the screen opens.
      _pictureLoad!.ignore();
    }

    _initialValue = {
      'name': row?.name,
      'surname': row?.surname,
      'email': row?.email,
      'phoneNumber': row?.phoneNumber,
      'userTypeId': _selectedRoleId,
      'isActive': row?.isActive ?? true,
      'operationIds': row?.operationIds ?? const <int>[],
    };

    _nameFocus.addListener(() => _onFieldBlurred('name', _nameFocus));
    _surnameFocus.addListener(() => _onFieldBlurred('surname', _surnameFocus));
    _emailFocus.addListener(() => _onFieldBlurred('email', _emailFocus));
    _passwordFocus.addListener(() => _onPasswordFieldBlurred(_passwordFocus));
    _confirmPasswordFocus
        .addListener(() => _onPasswordFieldBlurred(_confirmPasswordFocus));
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _surnameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  bool get _isProductionRole {
    final role = widget.provider.roles
        .where((type) => type.id == _selectedRoleId)
        .firstOrNull;
    return role?.type == AppRoles.productionWorker;
  }

  /// The operations offered under the picked role - the office pair for every
  /// role but Production worker, the shop floor for that one. See
  /// `AppRoles.officeOperations` for why the split is exactly these two.
  List<OperationType> get _availableOperations => widget.provider.operationTypes
      .where((op) => AppRoles.isOfficeOperation(op.name) != _isProductionRole)
      .toList();

  /// Switching role can hide operations that were picked under the old one -
  /// they are dropped rather than left selected but invisible.
  void _onRoleChanged(int? roleId) {
    setState(() => _selectedRoleId = roleId);
    _revalidateField('userTypeId');

    final field = _formKey.currentState?.fields['operationIds'];
    final visible = _availableOperations.map((op) => op.id).toSet();
    final current = (field?.value as List<int>?) ?? const <int>[];
    final pruned = current.where(visible.contains).toList();

    if (pruned.length != current.length) {
      field?.didChange(pruned);
    }
  }

  int? _roleIdOf(String role) => widget.provider.roles
      .where((type) => type.type.toLowerCase() == role.toLowerCase())
      .map((type) => type.id)
      .firstOrNull;

  Future<void> _pickPicture() async {
    final file = await openFile(acceptedTypeGroups: const [_pictureTypeGroup]);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    if (bytes.length > _maxPictureBytes) {
      if (!mounted) return;
      setState(() => _error = 'Pick an image under 5 MB.');
      return;
    }

    if (!mounted) return;
    setState(() {
      _picture = base64Encode(bytes);
      _pictureTouched = true;
      _error = null;
    });
  }

  void _removePicture() => setState(() {
        _picture = null;
        _pictureTouched = true;
      });

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
            _PictureField(
              picture: _picture,
              initials: widget.row?.initials ?? '?',
              onPick: _pickPicture,
              onRemove: _removePicture,
            ),
            const SizedBox(height: formSectionGap),
            Row(
              // Top-aligned, not centred: a validator error grows only the
              // field it belongs to, and centring would sink its neighbour
              // to match instead of leaving it where it started.
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FormBuilderTextField(
                    name: 'name',
                    autofocus: _isNew,
                    focusNode: _nameFocus,
                    decoration: appInputDecoration('First name'),
                    validator: FormBuilderValidators.required(
                      errorText: 'A first name is required.',
                    ),
                    onChanged: (_) => _revalidateField('name'),
                  ),
                ),
                const SizedBox(width: formFieldGap),
                Expanded(
                  child: FormBuilderTextField(
                    name: 'surname',
                    focusNode: _surnameFocus,
                    decoration: appInputDecoration('Surname'),
                    validator: FormBuilderValidators.required(
                      errorText: 'A surname is required.',
                    ),
                    onChanged: (_) => _revalidateField('surname'),
                  ),
                ),
              ],
            ),
            // Wider than formFieldGap: a validator error appends its own line
            // under the field, and the ordinary gap reads as cramped once
            // that red text is sitting right above the next field's label.
            const SizedBox(height: formFieldGap + 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FormBuilderTextField(
                    name: 'email',
                    focusNode: _emailFocus,
                    decoration: appInputDecoration('E-mail'),
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.required(
                        errorText: 'Sign-in needs an e-mail address.',
                      ),
                      FormBuilderValidators.email(
                        errorText: 'That is not an e-mail address.',
                      ),
                    ]),
                    onChanged: (_) => _revalidateField('email'),
                  ),
                ),
                const SizedBox(width: formFieldGap),
                Expanded(
                  child: FormBuilderTextField(
                    name: 'phoneNumber',
                    decoration: appInputDecoration('Phone', hintText: 'Optional'),
                    validator: PhoneRules.validate,
                    onChanged: (_) => _revalidateField('phoneNumber'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: formFieldGap + 10),
            SearchableDropdownField<int>(
              name: 'userTypeId',
              label: 'Role',
              validator: FormBuilderValidators.required(
                errorText: 'Pick a role.',
              ),
              onChanged: _onRoleChanged,
              entries: [
                for (final UserType role in provider.roles)
                  DropdownMenuEntry(value: role.id, label: role.type),
              ],
            ),
            const SizedBox(height: formSectionGap),
            // The pair check each other, so they are plain fields with one
            // complaint worked out in _checkPasswords rather than two validators.
            Row(
              children: [
                Expanded(
                  child: PasswordField(
                    controller: _password,
                    focusNode: _passwordFocus,
                    label: 'Password',
                    hintText:
                        _isNew ? null : 'Leave blank to keep the current one',
                    onChanged: (_) => _recheckPasswords(),
                  ),
                ),
                const SizedBox(width: formFieldGap),
                Expanded(
                  child: PasswordField(
                    controller: _confirmPassword,
                    focusNode: _confirmPasswordFocus,
                    label: 'Confirm password',
                    hintText: _isNew ? null : 'Only if you are changing it',
                    onChanged: (_) => _recheckPasswords(),
                    hasError: _unconfirmedPassword,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _unconfirmedPassword ? PasswordRules.describe : (_passwordError ?? PasswordRules.describe),
              style: TextStyle(
                fontSize: 12,
                color: _passwordError == null || _unconfirmedPassword
                    ? AppColors.textSecondary
                    : AppColors.danger,
              ),
            ),
            const SizedBox(height: formSectionGap),
            const Text(
              'Qualified for',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              _isProductionRole
                  ? 'Which shop-floor operations this person may book hours against.'
                  : 'Office roles are limited to Office work and Technical preparation.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            // Re-keyed on the role, so switching from one bucket to the other
            // rebuilds the chip list fresh rather than reusing chip state
            // (and its own internal selection bookkeeping) across the swap.
            FormBuilderFilterChips<int>(
              key: ValueKey(_isProductionRole),
              name: 'operationIds',
              decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
              spacing: 8,
              runSpacing: 4,
              options: [
                for (final OperationType operation in _availableOperations)
                  FormBuilderChipOption(
                    value: operation.id,
                    child: Text(operation.name),
                  ),
              ],
            ),
            const SizedBox(height: formSectionGap),
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
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    _saveAttempted = true;

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
      // The API overwrites the picture with whatever is sent, so the current
      // one has to be known first - saving without it would clear it.
      if (!_pictureTouched) await _pictureLoad;

      await widget.provider.saveWorker(
        id: widget.row?.id,
        name: (values['name'] as String).trim(),
        surname: (values['surname'] as String).trim(),
        email: (values['email'] as String).trim(),
        userTypeId: values['userTypeId'] as int,
        isActive: values['isActive'] as bool? ?? true,
        phoneNumber: _trimToNull(values['phoneNumber']),
        picture: _picture,
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

/// The avatar plus the controls to change or remove it. Optional on both
/// creation and edit - leaving it alone keeps the name-letters avatar.
class _PictureField extends StatelessWidget {
  const _PictureField({
    required this.picture,
    required this.initials,
    required this.onPick,
    required this.onRemove,
  });

  final String? picture;
  final String initials;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        UserAvatar(picture: picture, initials: initials, size: 64, fontSize: 20),
        const SizedBox(width: 16),
        TextButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.photo_camera_outlined, size: 18),
          label: Text(picture == null ? 'Add picture' : 'Change picture'),
        ),
        if (picture != null)
          TextButton(
            onPressed: onRemove,
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Remove'),
          ),
      ],
    );
  }
}
