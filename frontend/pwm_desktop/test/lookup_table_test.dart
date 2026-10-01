import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwm_desktop/models/models.dart';
import 'package:pwm_desktop/providers/base_provider.dart';
import 'package:pwm_desktop/screens/lookup_table_screen.dart';
import 'package:pwm_desktop/screens/widgets/active_chip.dart';
import 'package:pwm_desktop/screens/widgets/lookup_table_config.dart';

/// Answers the table's one read, and records what the form writes.
class _FakeCompanies extends BaseProvider<Company> {
  _FakeCompanies(this.rows) : super('Company');

  final List<Company> rows;
  final List<Map<String, dynamic>> inserted = [];

  @override
  Company fromJson(dynamic data) => throw UnimplementedError();

  @override
  Future<PageResult<Company>> get({dynamic filter}) async => PageResult<Company>()..items = rows;

  @override
  Future<Company> insert(dynamic request) async {
    inserted.add(Map<String, dynamic>.from(request as Map));
    return rows.first;
  }
}

Company _company(int id, String name, {bool isActive = true}) => Company(
      id: id,
      name: name,
      countryId: 1,
      cityId: 1,
      address: 'Street 1',
      companyTypeId: 1,
      isActive: isActive,
    );

/// The Companies table's own Name and Status columns and Active switch, over a
/// fake provider - the real config reads its dropdowns from the API.
LookupTableConfig<Company> _config(_FakeCompanies provider) => LookupTableConfig<Company>(
      title: 'Companies',
      description: 'Customers, carriers and unload addresses.',
      createProvider: () => provider,
      idOf: (row) => row.id,
      columns: [
        LookupColumn('Name', (row, ctx) => row.name),
        LookupColumn(
          'Status',
          (row, ctx) => ActiveChip.labelFor(row.isActive),
          cell: (row) => ActiveChip(isActive: row.isActive),
        ),
      ],
      fields: const [
        LookupField(key: 'name', label: 'Name'),
        LookupField(key: 'isActive', label: 'Active', toggle: true),
      ],
      valuesOf: (row) => {'name': row.name, 'isActive': row.isActive},
    );

Future<void> _pump(WidgetTester tester, _FakeCompanies provider) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(home: LookupTableScreen<Company>(config: _config(provider))));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows each company\'s status, and filters by it like Excel', (tester) async {
    await _pump(
      tester,
      _FakeCompanies([
        _company(1, 'Euro Spedicija d.o.o.'),
        _company(2, 'Brzi Prevoz d.o.o.', isActive: false),
      ]),
    );

    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Inactive'), findsOneWidget);

    // The Status header opens the checklist of every value the column holds.
    await tester.tap(find.text('Status'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Inactive'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Euro Spedicija d.o.o.'), findsOneWidget);
    expect(find.text('Brzi Prevoz d.o.o.'), findsNothing);
  });

  testWidgets('a new company starts out active', (tester) async {
    final provider = _FakeCompanies([_company(1, 'Euro Spedicija d.o.o.')]);
    await _pump(tester, provider);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Novi Prevoz d.o.o.');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(provider.inserted.single, {'name': 'Novi Prevoz d.o.o.', 'isActive': true});
  });

  test('a picker offers active companies, and the one a record already has', () {
    final gone = _company(2, 'Brzi Prevoz d.o.o.', isActive: false);

    expect(_company(1, 'Euro Spedicija d.o.o.').isSelectableFor(null), isTrue);
    expect(gone.isSelectableFor(null), isFalse);
    expect(gone.isSelectableFor(1), isFalse);
    expect(gone.isSelectableFor(2), isTrue);
  });
}
