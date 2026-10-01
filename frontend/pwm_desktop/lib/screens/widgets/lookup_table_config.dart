import 'package:material_ui/material_ui.dart';

import '../../providers/base_provider.dart';

/// One choice in a foreign-key dropdown - a row from another lookup table,
/// reduced to what a form needs to show and to send.
class DropdownOption {
  const DropdownOption(this.id, this.label, {this.groupId});

  final int id;
  final String label;

  /// Set when this option belongs to a group another field narrows by - e.g.
  /// a city's countryId, so `LookupField.dependsOn` can filter the city list
  /// down to the country picked in the parent field. Null for an option with
  /// no such parent.
  final int? groupId;
}

/// One field of a lookup table's add/edit form. [key] doubles as the JSON
/// property the insert/update request carries it under - every one of these
/// tables' requests are flat and match the form one-for-one, so there is no
/// separate request-building step.
class LookupField {
  const LookupField({
    required this.key,
    required this.label,
    this.numeric = false,
    this.required = true,
    this.showOnlyOnInsert = false,
    this.loadOptions,
    this.dependsOn,
    this.toggle = false,
    this.hint,
  });

  final String key;
  final String label;

  /// An on/off switch rather than a text field - on for a new row.
  final bool toggle;

  /// A line under the field saying what it does.
  final String? hint;

  /// Whether the field is a plain number rather than free text.
  final bool numeric;

  /// False only for `Company`'s `vat`/`eori` - the columns that are nullable
  /// on the entity itself. An empty field is sent as `null`, not `""`.
  final bool required;

  /// True only for `ReportTypeLookup`'s `id` - the one field an update
  /// request cannot carry because the row's id never changes once written.
  final bool showOnlyOnInsert;

  /// Set for a foreign key: how to fetch the rows it may point at. Loaded once
  /// per form, and reused to resolve the column showing this field in the list.
  final Future<List<DropdownOption>> Function()? loadOptions;

  /// Key of another field in the same form whose value narrows this field's
  /// options - e.g. Company's `cityId` depends on `countryId`, so only cities
  /// whose `DropdownOption.groupId` matches the picked country show up. Null
  /// for a field whose options are not filtered by another field.
  final String? dependsOn;

  bool get isDropdown => loadOptions != null;
}

/// One column of a lookup table's list. [ctx] carries the options every
/// dropdown field loaded, keyed by [LookupField.key], so a column can resolve
/// a foreign key to the name the form would show for it.
class LookupColumn<T> {
  const LookupColumn(this.label, this.valueOf, {this.cell});

  final String label;

  /// The cell's text - also what the column sorts and filters by.
  final String Function(T row, Map<String, Map<int, String>> ctx) valueOf;

  /// Draws the cell instead of [valueOf]'s plain text - e.g. a status chip.
  final Widget Function(T row)? cell;
}

/// Everything the generic `LookupTableScreen` needs to manage one table -
/// which provider talks to it, what the list shows, and what the form asks for.
class LookupTableConfig<T> {
  const LookupTableConfig({
    required this.title,
    required this.description,
    required this.createProvider,
    required this.idOf,
    required this.columns,
    required this.fields,
    required this.valuesOf,
    this.readOnlyReason,
  });

  final String title;
  final String description;
  final BaseProvider<T> Function() createProvider;
  final int Function(T row) idOf;
  final List<LookupColumn<T>> columns;
  final List<LookupField> fields;

  /// The form's initial values when editing a row - keyed the same as [fields].
  final Map<String, dynamic> Function(T row) valuesOf;

  /// Set only for `ActivityLogType`: why its table has no Add/edit/delete, shown
  /// as a banner in place of those controls. The API backs this with the same
  /// restriction (`ActivityLogTypeController` has no write actions), so this is
  /// what explains a read-only screen rather than what causes one.
  final String? readOnlyReason;

  bool get isReadOnly => readOnlyReason != null;

  List<LookupField> fieldsFor({required bool isNew}) =>
      isNew ? fields : fields.where((f) => !f.showOnlyOnInsert).toList();
}

/// Most of these tables are nothing but an id and a name (or, for `UserType`,
/// a `type`) - this builds that shape in one line rather than repeating the
/// column and field boilerplate six times over.
LookupTableConfig<T> simpleNameTable<T>({
  required String title,
  required String description,
  required BaseProvider<T> Function() createProvider,
  required int Function(T) idOf,
  required String Function(T) nameOf,
  String fieldKey = 'name',
  String fieldLabel = 'Name',
  String? readOnlyReason,
}) {
  return LookupTableConfig<T>(
    title: title,
    description: description,
    createProvider: createProvider,
    idOf: idOf,
    columns: [
      LookupColumn(fieldLabel, (row, ctx) => nameOf(row)),
    ],
    fields: [
      LookupField(key: fieldKey, label: fieldLabel),
    ],
    valuesOf: (row) => {fieldKey: nameOf(row)},
    readOnlyReason: readOnlyReason,
  );
}
