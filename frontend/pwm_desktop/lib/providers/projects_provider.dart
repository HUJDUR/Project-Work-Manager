import 'package:flutter/material.dart';

import '../models/models.dart';
import '../utils/api_client_exception.dart';
import 'auth_provider.dart';
import 'base_provider.dart';
import 'city_provider.dart';
import 'company_provider.dart';
import 'company_type_provider.dart';
import 'country_provider.dart';
import 'project_category_provider.dart';
import 'project_provider.dart';
import 'project_status_type_provider.dart';
import 'user_provider.dart';

enum ProjectsStatusState { idle, loading, ready, failed }

/// The screen's own store. Search, status filter and paging go to the API as a
/// `ProjectSearchObject`, so only one page of projects is ever in memory; the
/// three lookup tables are small and are fetched whole to resolve the names a
/// project carries as ids.
class ProjectsProvider extends ChangeNotifier {
  ProjectsProvider({
    BaseProvider<Project>? projects,
    BaseProvider<Company>? companies,
    BaseProvider<CompanyType>? companyTypes,
    BaseProvider<ProjectCategory>? categories,
    BaseProvider<ProjectStatusType>? statusTypes,
    BaseProvider<User>? users,
    BaseProvider<City>? cities,
    BaseProvider<Country>? countries,
  })  : _projects = projects ?? ProjectProvider(),
        _companies = companies ?? CompanyProvider(),
        _companyTypes = companyTypes ?? CompanyTypeProvider(),
        _categories = categories ?? ProjectCategoryProvider(),
        _statusTypes = statusTypes ?? ProjectStatusTypeProvider(),
        _users = users ?? UserProvider(),
        _cities = cities ?? CityProvider(),
        _countries = countries ?? CountryProvider();

  /// Rows per page of the table.
  static const int pageSize = 8;

  /// Newest project first, ordered by the API.
  static const String sortBy = 'CreationDate desc';

  /// The statuses a project ends in — everything else counts as active.
  static const String deliveredStatus = 'Delivered';
  static const String rejectedStatus = 'Rejected';
  static const String inProductionStatus = 'In production';

  /// Asks for the count; the API clamps a page to at least one row, so the one
  /// row that comes back is thrown away.
  static const Map<String, dynamic> _countOnly = {
    'page': 1,
    'pageSize': 1,
    'includeTotalCount': true,
  };

  final BaseProvider<Project> _projects;
  final BaseProvider<Company> _companies;
  final BaseProvider<CompanyType> _companyTypes;
  final BaseProvider<ProjectCategory> _categories;
  final BaseProvider<ProjectStatusType> _statusTypes;
  final BaseProvider<User> _users;
  final BaseProvider<City> _cities;
  final BaseProvider<Country> _countries;

  ProjectsStatusState _status = ProjectsStatusState.idle;
  String? _errorMessage;

  List<ProjectRow> _rows = const [];
  List<ProjectCategory> _categoryList = const [];
  List<ProjectStatusType> _statusList = const [];
  List<Company> _customerList = const [];
  List<Company> _carrierList = const [];
  List<User> _authorList = const [];
  Map<int, Company> _companyById = const {};
  Map<int, User> _userById = const {};
  Map<int, String> _locationByCompanyId = const {};

  int _totalCount = 0;
  int _deliveredCount = 0;
  int _cancelledCount = 0;
  int _inProductionCount = 0;
  int _matchCount = 0;

  String _search = '';
  int? _statusId;
  int _page = 1;

  ProjectsStatusState get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == ProjectsStatusState.loading;

  List<ProjectCategory> get categories => _categoryList;
  List<ProjectStatusType> get statusTypes => _statusList;

  /// Companies of type Customer — who a project can be raised for.
  List<Company> get customers => _customerList;

  /// Companies of any other type — who can carry the goods out.
  List<Company> get carriers => _carrierList;

  /// Office accounts, which is who raises a project.
  List<User> get authors => _authorList;

  /// The signed-in user, so a new project defaults to its author.
  int? get signedInUserId => AuthProvider.user?.id;

  String get search => _search;
  int? get statusId => _statusId;
  int get page => _page;

  bool get hasFilters => _search.isNotEmpty || _statusId != null;

  /// The page the table shows.
  List<ProjectRow> get rows => _rows;

  /// How many projects the current filters match, across every page.
  int get matchCount => _matchCount;

  int get pageCount => (_matchCount / pageSize).ceil().clamp(1, 999);

  /// The counters read the whole book rather than the filtered page, because
  /// they sit above the filter bar. The API counts them.
  int get totalCount => _totalCount;
  int get activeCount => _totalCount - _deliveredCount - _cancelledCount;
  int get inProductionCount => _inProductionCount;
  int get deliveredCount => _deliveredCount;

  Future<void> setSearch(String value) {
    _search = value;
    _page = 1;
    return _loadPage();
  }

  Future<void> setStatus(int? id) {
    _statusId = id;
    _page = 1;
    return _loadPage();
  }

  Future<void> setPage(int value) {
    _page = value.clamp(1, pageCount);
    return _loadPage();
  }

  Future<void> clearFilters() {
    _search = '';
    _statusId = null;
    _page = 1;
    return _loadPage();
  }

  /// Lookups, counters and the first page. The lookups only change when the
  /// reference data does, so a write afterwards goes through [refresh].
  Future<void> load() async {
    _status = ProjectsStatusState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final lookups = await Future.wait([
        _all(_companies),
        _all(_companyTypes),
        _all(_categories),
        _all(_statusTypes),
        _all(_users),
        _all(_cities),
        _all(_countries),
      ]);

      final companies = lookups[0] as List<Company>;
      final companyTypes = lookups[1] as List<CompanyType>;
      final categories = lookups[2] as List<ProjectCategory>;
      final statuses = lookups[3] as List<ProjectStatusType>;
      final users = lookups[4] as List<User>;
      final cities = lookups[5] as List<City>;
      final countries = lookups[6] as List<Country>;

      _companyById = {for (final company in companies) company.id: company};
      _userById = {for (final user in users) user.id: user};
      _categoryList = [...categories]..sort((a, b) => a.name.compareTo(b.name));
      _statusList = statuses;

      // Where the goods go is the carrier's city and country, two joins away.
      final countryById = {for (final country in countries) country.id: country};
      final cityById = {for (final city in cities) city.id: city};
      _locationByCompanyId = {
        for (final company in companies)
          if (cityById[company.cityId] case final city?)
            company.id: [city.name, countryById[city.countryId]?.name]
                .whereType<String>()
                .join(', '),
      };

      final customerTypeId = companyTypes
          .where((type) => type.name.toLowerCase() == 'customer')
          .map((type) => type.id)
          .firstOrNull;
      _customerList = companies
          .where((company) =>
              customerTypeId == null || company.companyTypeId == customerTypeId)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      _carrierList = companies
          .where((company) =>
              customerTypeId != null && company.companyTypeId != customerTypeId)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      // A project is raised by someone with an account that still works.
      _authorList = users.where((user) => user.isActive).toList()
        ..sort((a, b) => a.fullName.compareTo(b.fullName));

      await Future.wait([_loadCounters(), _fetchPage()]);

      _status = ProjectsStatusState.ready;
    } on ApiClientException catch (error) {
      _errorMessage = error.message;
      _status = ProjectsStatusState.failed;
    } catch (error) {
      _errorMessage = 'Something went wrong while loading projects: $error';
      _status = ProjectsStatusState.failed;
    }

    notifyListeners();
  }

  /// What a details screen asks for after saving: the counters and the page
  /// again, without re-reading the reference data.
  Future<void> refresh() async {
    try {
      await Future.wait([_loadCounters(), _fetchPage()]);
      _status = ProjectsStatusState.ready;
    } on ApiClientException catch (error) {
      _errorMessage = error.message;
      _status = ProjectsStatusState.failed;
    } catch (error) {
      _errorMessage = 'Something went wrong while loading projects: $error';
      _status = ProjectsStatusState.failed;
    }

    notifyListeners();
  }

  Future<void> _loadPage() async {
    try {
      await _fetchPage();
    } on ApiClientException catch (error) {
      _errorMessage = error.message;
      _status = ProjectsStatusState.failed;
    } catch (error) {
      _errorMessage = 'Something went wrong while loading projects: $error';
      _status = ProjectsStatusState.failed;
    }

    notifyListeners();
  }

  /// The search object the table's filters add up to.
  Map<String, dynamic> get filter => {
        'page': _page,
        'pageSize': pageSize,
        'includeTotalCount': true,
        'sortBy': sortBy,
        if (_search.trim().isNotEmpty) 'search': _search.trim(),
        if (_statusId != null) 'projectStatusId': _statusId,
      };

  Future<void> _fetchPage() async {
    final result = await _projects.get(filter: filter);

    _matchCount = result.totalCount ?? result.items.length;
    // A delete can empty the last page; step back rather than show nothing.
    if (result.items.isEmpty && _page > 1 && _matchCount > 0) {
      _page = pageCount;
      return _fetchPage();
    }

    _rows = _buildRows(result.items);
  }

  Future<void> _loadCounters() async {
    final counts = await Future.wait([
      _countAll(),
      _countByStatus(_statusIdOf(deliveredStatus)),
      _countByStatus(_statusIdOf(rejectedStatus)),
      _countByStatus(_statusIdOf(inProductionStatus)),
    ]);

    _totalCount = counts[0];
    _deliveredCount = counts[1];
    _cancelledCount = counts[2];
    _inProductionCount = counts[3];
  }

  Future<int> _countAll() async {
    final result = await _projects.get(filter: _countOnly);
    return result.totalCount ?? 0;
  }

  /// A status this database does not have counts as none of them.
  Future<int> _countByStatus(int? statusId) async {
    if (statusId == null) return 0;

    final result =
        await _projects.get(filter: {..._countOnly, 'projectStatusId': statusId});
    return result.totalCount ?? 0;
  }

  /// A whole lookup table, paged through by [BaseProvider.getAll] because the
  /// API caps how many rows one request may return.
  Future<List<E>> _all<E>(BaseProvider<E> provider) => provider.getAll();

  int? _statusIdOf(String name) => _statusList
      .where((status) => status.name.toLowerCase() == name.toLowerCase())
      .map((status) => status.id)
      .firstOrNull;

  List<ProjectRow> _buildRows(List<Project> projects) {
    final categoryById = {for (final category in _categoryList) category.id: category};
    final statusById = {for (final status in _statusList) status.id: status};

    return projects
        .map((project) => ProjectRow(
              id: project.id,
              name: project.name,
              code: project.code,
              description: project.description,
              notes: project.notes,
              weight: project.weight,
              priority: project.priorityLevel,
              createdByUserId: project.createdByUserId,
              createdByName:
                  _userById[project.createdByUserId]?.fullName ?? 'Unknown user',
              customerId: project.customerId,
              customerName: _companyById[project.customerId]?.name ?? 'Unknown customer',
              categoryId: project.projectCategoryId,
              categoryName:
                  categoryById[project.projectCategoryId]?.name ?? 'Uncategorised',
              statusId: project.projectStatusId,
              statusName: statusById[project.projectStatusId]?.name ?? 'Unknown',
              createdAt: project.creationDate,
              startDate: project.productionStartDate,
              endDate: project.deliveryDate,
              deliveryCompanyId: project.deliveryCompanyId,
              location: project.deliveryCompanyId == null
                  ? null
                  : _locationByCompanyId[project.deliveryCompanyId],
            ))
        .toList();
  }

  /// Inserts when [id] is null and updates otherwise — the details screen uses
  /// the same form for both. The caller reloads; this only writes.
  Future<void> saveProject({
    int? id,
    required String name,
    required String code,
    required int customerId,
    required int projectCategoryId,
    required int projectStatusId,
    required int createdByUserId,
    required ProjectPriority priority,
    required double weight,
    required DateTime creationDate,
    required DateTime productionStartDate,
    String? description,
    String? notes,
    int? deliveryCompanyId,
    DateTime? deliveryDate,
  }) async {
    final body = {
      'name': name,
      'code': code,
      'description': description,
      'notes': notes,
      'priority': priority.value,
      'customerId': customerId,
      'projectCategoryId': projectCategoryId,
      'projectStatusId': projectStatusId,
      'createdByUserId': createdByUserId,
      'weight': weight,
      // Creation date is NOT NULL in the schema, so the client always sends it.
      'creationDate': creationDate.toIso8601String(),
      'productionStartDate': productionStartDate.toIso8601String(),
      'deliveryCompanyId': deliveryCompanyId,
      'deliveryDate': deliveryDate?.toIso8601String(),
    };

    if (id == null) {
      await _projects.insert(body);
    } else {
      await _projects.update(id, body);
    }
  }

  Future<void> deleteProject(int id) => _projects.remove(id);
}
