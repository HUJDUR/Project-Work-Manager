import '../../providers/base_provider.dart';

/// One choice in a foreign-key dropdown - a row from another lookup table,
/// reduced to what a form needs to show and to send.
class DropdownOption {
  const DropdownOption(this.id, this.label);

  final int id;
  final String label;
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
  });

  final String key;
  final String label;

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

  bool get isDropdown => loadOptions != null;
}

/// One column of a lookup table's list. [ctx] carries the options every
/// dropdown field loaded, keyed by [LookupField.key], so a column can resolve
/// a foreign key to the name the form would show for it.
class LookupColumn<T> {
  const LookupColumn(this.label, this.valueOf);

  final String label;
  final String Function(T row, Map<String, Map<int, String>> ctx) valueOf;
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
  });

  final String title;
  final String description;
  final BaseProvider<T> Function() createProvider;
  final int Function(T row) idOf;
  final List<LookupColumn<T>> columns;
  final List<LookupField> fields;

  /// The form's initial values when editing a row - keyed the same as [fields].
  final Map<String, dynamic> Function(T row) valuesOf;

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
  );
}
