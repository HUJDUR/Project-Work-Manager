import 'package:material_ui/material_ui.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/app_theme.dart';
import 'lookup_table_screen.dart';
import 'widgets/active_chip.dart';
import 'widgets/lookup_table_config.dart';

/// The Administration screen: eleven reference tables, open only to
/// `AppRoles.admin` (see `AppRoles._blocked`, which is what keeps the other
/// three office roles off this destination - the API narrows the same eleven
/// controllers' writes to `Roles.Admin` for the same reason).
///
/// This is a hub, not a list of its own: each tile pushes `LookupTableScreen`
/// configured for that one table, so the screen itself carries no CRUD logic -
/// see `LookupTableConfig`, which is also where a tile's title and
/// description come from, so the two cannot drift apart.
class AdministrationScreen extends StatelessWidget {
  const AdministrationScreen({super.key});

  static final List<_Tile> _tiles = [
    _tileFor(Icons.category_outlined, _activityLogTypes()),
    _tileFor(Icons.badge_outlined, _userTypes()),
    _tileFor(Icons.build_outlined, _operationTypes()),
    _tileFor(Icons.public_outlined, _countries()),
    _tileFor(Icons.location_city_outlined, _cities()),
    _tileFor(Icons.apartment_outlined, _companyTypes()),
    _tileFor(Icons.business_outlined, _companies()),
    _tileFor(Icons.flag_outlined, _projectStatusTypes()),
    _tileFor(Icons.folder_copy_outlined, _projectCategories()),
    _tileFor(Icons.local_shipping_outlined, _truckLoadStatusTypes()),
    _tileFor(Icons.bar_chart_outlined, _reportTypes()),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Administration',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              'The reference tables the rest of the app is built on.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.gap),
            Expanded(
              child: GridView.builder(
                // A fixed column count stretches into three huge, mostly-empty
                // cards on a wide monitor; capping each card's width instead
                // lets more columns fit as the window grows, with every card
                // staying the same compact height regardless of column count.
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 360,
                  mainAxisSpacing: AppSpacing.gap,
                  crossAxisSpacing: AppSpacing.gap,
                  mainAxisExtent: 96,
                ),
                itemCount: _tiles.length,
                itemBuilder: (context, index) => _TileView(tile: _tiles[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One card on the hub. [open] already knows which table it pushes and with
/// what config - built by [_tileFor], never by hand, so a tile can never show
/// one table's label over another's screen.
class _Tile {
  const _Tile({
    required this.icon,
    required this.title,
    required this.description,
    required this.open,
  });

  final IconData icon;
  final String title;
  final String description;
  final void Function(BuildContext context) open;
}

_Tile _tileFor<T>(IconData icon, LookupTableConfig<T> config) => _Tile(
      icon: icon,
      title: config.title,
      description: config.description,
      open: (context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LookupTableScreen<T>(config: config)),
      ),
    );

class _TileView extends StatelessWidget {
  const _TileView({required this.tile});

  final _Tile tile;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => tile.open(context),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(tile.icon, size: 19, color: AppColors.accent),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tile.title,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tile.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

LookupTableConfig<ActivityLogType> _activityLogTypes() => simpleNameTable<ActivityLogType>(
      title: 'Activity Log Types',
      description: 'What an entry in the activity log can be.',
      createProvider: () => ActivityLogTypeProvider(),
      idOf: (row) => row.id,
      nameOf: (row) => row.name,
      readOnlyReason: "These six activity types are wired into the app's code. "
          "Changing anything would break the application.",
    );

LookupTableConfig<UserType> _userTypes() => simpleNameTable<UserType>(
      title: 'User Types',
      description: 'The five roles an account can hold.',
      createProvider: () => UserTypeProvider(),
      idOf: (row) => row.id,
      nameOf: (row) => row.type,
      fieldKey: 'type',
      fieldLabel: 'Type',
      readOnlyReason: "These five roles are wired into the app's code. "
          "Changing anything would break the application.",
    );

LookupTableConfig<OperationType> _operationTypes() => simpleNameTable<OperationType>(
      title: 'Operation Types',
      description: 'The kinds of work a worker can book hours against.',
      createProvider: () => OperationTypeProvider(),
      idOf: (row) => row.id,
      nameOf: (row) => row.name,
    );

LookupTableConfig<ProjectCategory> _projectCategories() => simpleNameTable<ProjectCategory>(
      title: 'Project Categories',
      description: 'The project type dropdown on Projects and Recommendations.',
      createProvider: () => ProjectCategoryProvider(),
      idOf: (row) => row.id,
      nameOf: (row) => row.name,
    );

LookupTableConfig<CompanyType> _companyTypes() => simpleNameTable<CompanyType>(
      title: 'Company Types',
      description: 'Customer, transport or unload address.',
      createProvider: () => CompanyTypeProvider(),
      idOf: (row) => row.id,
      nameOf: (row) => row.name,
    );

LookupTableConfig<ProjectStatusType> _projectStatusTypes() =>
    simpleNameTable<ProjectStatusType>(
      title: 'Project Status Types',
      description: 'What a project can be - several screens match these by name.',
      createProvider: () => ProjectStatusTypeProvider(),
      idOf: (row) => row.id,
      nameOf: (row) => row.name,
      readOnlyReason: "These statuses are wired into the app's code. "
          "Changing anything would break the application.",
    );

LookupTableConfig<TruckLoadStatusType> _truckLoadStatusTypes() =>
    simpleNameTable<TruckLoadStatusType>(
      title: 'Truck Load Status Types',
      description: 'What a transport load can be - its life cycle matches these by name.',
      createProvider: () => TruckLoadStatusTypeProvider(),
      idOf: (row) => row.id,
      nameOf: (row) => row.name,
      readOnlyReason: "These statuses are wired into the app's code. "
          "Changing anything would break the application.",
    );

LookupTableConfig<ReportTypeLookup> _reportTypes() => LookupTableConfig<ReportTypeLookup>(
      title: 'Report Types',
      description: 'The two PDFs Reports can generate.',
      createProvider: () => ReportTypeProvider(),
      idOf: (row) => row.id,
      columns: [
        LookupColumn('Description', (row, ctx) => row.description),
      ],
      fields: [
        // A picker over the fixed ReportType enum, not a raw id field: the API
        // needs the row's id set explicitly (ReportTypes.Id is
        // ValueGeneratedNever, mirroring that enum), but a form asking the
        // office to type a database id is exactly what it should never do.
        // Naming the kind instead of its number keeps the two in step.
        LookupField(
          key: 'id',
          label: 'Report kind',
          showOnlyOnInsert: true,
          loadOptions: () async => [
            for (final kind in ReportType.values) DropdownOption(kind.value, kind.label),
          ],
        ),
        const LookupField(key: 'description', label: 'Description'),
      ],
      valuesOf: (row) => {'id': row.id, 'description': row.description},
      readOnlyReason: "These report types are wired into the app's code. "
          "Changing anything would break the application.",
    );

LookupTableConfig<Country> _countries() => LookupTableConfig<Country>(
      title: 'Countries',
      description: 'Where a city, and so a company, sits.',
      createProvider: () => CountryProvider(),
      idOf: (row) => row.id,
      columns: [
        LookupColumn('Name', (row, ctx) => row.name),
        LookupColumn('Code', (row, ctx) => row.code),
      ],
      fields: const [
        LookupField(key: 'name', label: 'Name'),
        LookupField(key: 'code', label: 'Code'),
      ],
      valuesOf: (row) => {'name': row.name, 'code': row.code},
    );

LookupTableConfig<City> _cities() => LookupTableConfig<City>(
      title: 'Cities',
      description: 'Where a company sits.',
      createProvider: () => CityProvider(),
      idOf: (row) => row.id,
      columns: [
        LookupColumn('Name', (row, ctx) => row.name),
        LookupColumn('Postal code', (row, ctx) => row.postalCode),
        LookupColumn(
          'Country',
          (row, ctx) => ctx['countryId']?[row.countryId] ?? 'Unknown',
        ),
      ],
      fields: [
        const LookupField(key: 'name', label: 'Name'),
        const LookupField(key: 'postalCode', label: 'Postal code'),
        LookupField(
          key: 'countryId',
          label: 'Country',
          loadOptions: () async {
            final countries = await CountryProvider().getAll();
            return [for (final c in countries) DropdownOption(c.id, c.name)];
          },
        ),
      ],
      valuesOf: (row) => {
        'name': row.name,
        'postalCode': row.postalCode,
        'countryId': row.countryId,
      },
    );

LookupTableConfig<Company> _companies() => LookupTableConfig<Company>(
      title: 'Companies',
      description: 'Customers, carriers and unload addresses.',
      createProvider: () => CompanyProvider(),
      idOf: (row) => row.id,
      columns: [
        LookupColumn('Name', (row, ctx) => row.name),
        LookupColumn(
          'Type',
          (row, ctx) => ctx['companyTypeId']?[row.companyTypeId] ?? 'Unknown',
        ),
        LookupColumn('City', (row, ctx) => ctx['cityId']?[row.cityId] ?? 'Unknown'),
        LookupColumn('Address', (row, ctx) => row.address),
        LookupColumn(
          'Status',
          (row, ctx) => ActiveChip.labelFor(row.isActive),
          cell: (row) => ActiveChip(isActive: row.isActive),
        ),
      ],
      fields: [
        const LookupField(key: 'name', label: 'Name'),
        LookupField(
          key: 'companyTypeId',
          label: 'Company type',
          loadOptions: () async {
            final types = await CompanyTypeProvider().getAll();
            return [for (final t in types) DropdownOption(t.id, t.name)];
          },
        ),
        // Picked first so the city field below can narrow to its cities.
        LookupField(
          key: 'countryId',
          label: 'Country',
          loadOptions: () async {
            final countries = await CountryProvider().getAll();
            return [for (final c in countries) DropdownOption(c.id, c.name)];
          },
        ),
        LookupField(
          key: 'cityId',
          label: 'City',
          dependsOn: 'countryId',
          loadOptions: () async {
            final cities = await CityProvider().getAll();
            return [
              for (final c in cities) DropdownOption(c.id, c.name, groupId: c.countryId),
            ];
          },
        ),
        const LookupField(key: 'address', label: 'Address'),
        const LookupField(key: 'vat', label: 'VAT', required: false),
        const LookupField(key: 'eori', label: 'EORI', required: false),
        const LookupField(
          key: 'isActive',
          label: 'Active',
          toggle: true,
          hint: 'Deactivate rather than delete a company the firm no longer works '
              'with - it stays on its projects and transports, but is not offered '
              'for new ones.',
        ),
      ],
      valuesOf: (row) => {
        'name': row.name,
        'companyTypeId': row.companyTypeId,
        'countryId': row.countryId,
        'cityId': row.cityId,
        'address': row.address,
        'vat': row.vat,
        'eori': row.eori,
        'isActive': row.isActive,
      },
    );
