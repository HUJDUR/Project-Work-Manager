import 'package:flutter/material.dart';

import '../models/models.dart';
import '../utils/api_client_exception.dart';
import '../utils/shop_floor.dart';
import 'auth_provider.dart';
import 'base_provider.dart';
import 'city_provider.dart';
import 'company_provider.dart';
import 'country_provider.dart';
import 'project_category_provider.dart';
import 'project_provider.dart';
import 'project_status_type_provider.dart';
import 'work_log_detail_provider.dart';

enum ProjectsStatus { idle, loading, ready, failed }

/// A delivery destination: the company the job goes to, and its address on one
/// line. [ProjectsProvider.deliveryOf] builds it.
typedef DeliveryPlace = ({String name, String address});

/// The Projects tab: what the shop floor is building, and what this worker has
/// put into any one of them.
///
/// **Only projects that are in production** — see [ShopFloor]. This is the
/// production workers' app; a delivered job or a rejected quote is not
/// something they can act on, so there is no status filter to offer and every
/// row is live by construction.
///
/// **Search and paging go to the API** as a `ProjectSearchObject`, along with
/// that status, the way the desktop's projects screen does it — projects are
/// not a lookup table and reading the lot to filter in Dart would stop working
/// the moment the shop has a few hundred. A page is appended rather than
/// replacing what is on screen, so "Load more" grows the list.
///
/// The names beside each row come from small lookups read once and kept —
/// statuses and categories, plus the companies, cities and countries that make
/// up a delivery destination. The worker's own hours are **not** in that
/// bargain — see [workOn].
class ProjectsProvider extends ChangeNotifier {
  ProjectsProvider({
    BaseProvider<Project>? projects,
    BaseProvider<ProjectStatusType>? statuses,
    BaseProvider<ProjectCategory>? categories,
    BaseProvider<Company>? companies,
    BaseProvider<City>? cities,
    BaseProvider<Country>? countries,
    BaseProvider<WorkLogDetail>? workLogDetails,
    int? userId,
  })  : _projects = projects ?? ProjectProvider(),
        _statuses = statuses ?? ProjectStatusTypeProvider(),
        _categories = categories ?? ProjectCategoryProvider(),
        _companies = companies ?? CompanyProvider(),
        _cities = cities ?? CityProvider(),
        _countries = countries ?? CountryProvider(),
        _workLogDetails = workLogDetails ?? WorkLogDetailProvider(),
        _userId = userId ?? AuthProvider.user?.id;

  /// A page a thumb can scroll through without a wall of rows.
  static const int pageSize = 8;

  final BaseProvider<Project> _projects;
  final BaseProvider<ProjectStatusType> _statuses;
  final BaseProvider<ProjectCategory> _categories;
  final BaseProvider<Company> _companies;
  final BaseProvider<City> _cities;
  final BaseProvider<Country> _countries;
  final BaseProvider<WorkLogDetail> _workLogDetails;
  final int? _userId;

  ProjectsStatus _status = ProjectsStatus.idle;
  String? _errorMessage;

  List<ProjectRow> _rows = const [];
  int _page = 1;
  int? _totalCount;
  bool _isLoadingMore = false;

  String _search = '';

  /// The id [ShopFloor.liveStatus] wears here, resolved once from the lookup.
  /// Null means the database has no such status — a seeding problem, and the
  /// reason nothing is listed rather than everything.
  int? _liveStatusId;

  Map<int, String> _statusNames = const {};
  Map<int, String> _categoryNames = const {};
  Map<int, Company> _companyById = const {};
  Map<int, City> _cityById = const {};
  Map<int, String> _countryNames = const {};

  ProjectsStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == ProjectsStatus.loading;
  bool get isLoadingMore => _isLoadingMore;
  List<ProjectRow> get rows => _rows;
  String get search => _search;
  int? get totalCount => _totalCount;
  bool get isEmpty => _status == ProjectsStatus.ready && _rows.isEmpty;

  /// True while the API says there are rows past the ones already shown.
  bool get hasMore {
    final total = _totalCount;
    return _liveStatusId != null && total != null && _rows.length < total;
  }

  Future<void> applySearch(String search) async {
    final trimmed = search.trim();
    if (trimmed == _search) return;

    _search = trimmed;
    await load();
  }

  /// First page, plus the lookups the rows are named from.
  Future<void> load() async {
    _status = ProjectsStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _loadLookupsOnce();

      _page = 1;
      _rows = _liveStatusId == null ? const [] : await _fetchPage(_page);

      _status = ProjectsStatus.ready;
    } on ApiClientException catch (error) {
      _errorMessage = error.message;
      _status = ProjectsStatus.failed;
    } catch (error) {
      _errorMessage = 'Something went wrong while loading projects: $error';
      _status = ProjectsStatus.failed;
    }

    notifyListeners();
  }

  /// The next page, appended. Quietly does nothing when there is no more or a
  /// page is already on its way, so a second tap cannot double up the list.
  Future<void> loadMore() async {
    if (_isLoadingMore || !hasMore) return;

    _isLoadingMore = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final next = await _fetchPage(_page + 1);

      _page += 1;
      _rows = [..._rows, ...next];
    } on ApiClientException catch (error) {
      _errorMessage = error.message;
    } catch (error) {
      _errorMessage = 'Something went wrong while loading more: $error';
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  /// What the signed-in worker has booked against one project.
  ///
  /// One request, narrowed by `userId` **and** `projectId` — the two filters
  /// `WorkLogDetailSearchObject` already carries — so this never reads more
  /// than the project actually being looked at.
  Future<ProjectWork> workOn(int projectId) async {
    final userId = _userId;
    if (userId == null) return ProjectWork.none;

    final blocks = await _workLogDetails.getAll(filter: {
      'userId': userId,
      'projectId': projectId,
    });

    if (blocks.isEmpty) return ProjectWork.none;

    final hours = blocks.fold<double>(0, (sum, block) => sum + block.hours);
    final days = blocks
        .map((block) => DateTime(
              block.startedAt.year,
              block.startedAt.month,
              block.startedAt.day,
            ))
        .toSet();

    return ProjectWork(
      hours: hours,
      days: days.length,
      lastWorked: blocks
          .map((block) => block.startedAt)
          .reduce((a, b) => a.isAfter(b) ? a : b),
    );
  }

  /// Where the job is delivered: the company named by
  /// `Project.DeliveryCompanyId`, with its address written out as one line —
  /// "Industriestrasse 14, 80331 Munich, Germany".
  ///
  /// Null when the project has no delivery company (the column is nullable) or
  /// the lookup does not know it. The **customer** is deliberately not shown
  /// anywhere: who ordered the job is the office's business; where it goes is
  /// the shop floor's.
  DeliveryPlace? deliveryOf(ProjectRow row) {
    final id = row.project.deliveryCompanyId;
    if (id == null) return null;

    final company = _companyById[id];
    if (company == null) return null;

    final city = _cityById[company.cityId];
    final country = city == null ? null : _countryNames[city.countryId];

    final town = city == null
        ? null
        : [city.postalCode, city.name]
            .where((part) => part.isNotEmpty)
            .join(' ');

    final address = [company.address, town, country]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join(', ');

    return (name: company.name, address: address);
  }

  Future<void> _loadLookupsOnce() async {
    if (_statusNames.isNotEmpty) return;

    // Five small lookups, read once between them: the three that name a row and
    // the two that turn a company's `CityId` into a town and a country.
    final results = await Future.wait([
      _statuses.getAll(),
      _categories.getAll(),
      _companies.getAll(),
      _cities.getAll(),
      _countries.getAll(),
    ]);

    final statuses = results[0] as List<ProjectStatusType>;
    _liveStatusId = ShopFloor.liveStatusId(statuses);
    _statusNames = {for (final row in statuses) row.id: row.name};
    _categoryNames = {
      for (final row in results[1] as List<ProjectCategory>) row.id: row.name
    };
    _companyById = {
      for (final row in results[2] as List<Company>) row.id: row
    };
    _cityById = {for (final row in results[3] as List<City>) row.id: row};
    _countryNames = {
      for (final row in results[4] as List<Country>) row.id: row.name
    };
  }

  Future<List<ProjectRow>> _fetchPage(int page) async {
    final result = await _projects.get(filter: {
      if (_search.isNotEmpty) 'search': _search,
      // Never optional: the whole tab is the live book, so a search that
      // matched a delivered job must still not turn one up.
      'projectStatusId': _liveStatusId,
      'page': page,
      'pageSize': pageSize,
      'includeTotalCount': true,
      // Newest first, the same order the desktop lists them in.
      'sortBy': 'CreationDate desc',
    });

    _totalCount = result.totalCount;

    return result.items.map(_describe).toList();
  }

  ProjectRow _describe(Project project) => ProjectRow(
        project: project,
        statusName: _statusNames[project.projectStatusId] ?? 'Unknown',
        categoryName: _categoryNames[project.projectCategoryId] ?? 'Uncategorised',
      );
}
