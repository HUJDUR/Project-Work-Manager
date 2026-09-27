import 'package:flutter/material.dart';

import '../utils/app_roles.dart';
import '../models/models.dart';
import '../utils/api_client_exception.dart';
import 'base_provider.dart';
import 'operation_type_provider.dart';
import 'user_operation_provider.dart';
import 'user_provider.dart';
import 'user_type_provider.dart';

enum WorkersStatusState { idle, loading, ready, failed }

/// Everyone with an account: the shop floor and the office. Search, role filter
/// and paging go to the API as a `UserSearchObject`; the roles, operation types
/// and the `UserOperations` join rows are lookups and are read whole.
class WorkersProvider extends ChangeNotifier {
  WorkersProvider({
    BaseProvider<User>? users,
    BaseProvider<UserType>? userTypes,
    BaseProvider<UserOperation>? userOperations,
    BaseProvider<OperationType>? operationTypes,
  })  : _users = users ?? UserProvider(),
        _userTypes = userTypes ?? UserTypeProvider(),
        _userOperations = userOperations ?? UserOperationProvider(),
        _operationTypes = operationTypes ?? OperationTypeProvider();

  /// Rows per page of the table, as on the projects screen.
  static const int pageSize = 8;

  /// Surname then first name, ordered by the API.
  static const String sortBy = 'Surname, Name';

  /// The role that works the shop floor; the rest run the office.
  static const String workerRole = AppRoles.productionWorker;

  static const List<String> officeRoles = [
    AppRoles.admin,
    AppRoles.workPreparation,
    AppRoles.finances,
    AppRoles.projectManager,
  ];

  /// Asks for the count; the API clamps a page to at least one row, so the one
  /// row that comes back is thrown away.
  static const Map<String, dynamic> _countOnly = {
    'page': 1,
    'pageSize': 1,
    'includeTotalCount': true,
  };

  final BaseProvider<User> _users;
  final BaseProvider<UserType> _userTypes;
  final BaseProvider<UserOperation> _userOperations;
  final BaseProvider<OperationType> _operationTypes;

  WorkersStatusState _status = WorkersStatusState.idle;
  String? _errorMessage;

  List<WorkerRow> _rows = const [];
  List<UserType> _roleList = const [];
  List<OperationType> _operationList = const [];
  List<UserOperation> _qualifications = const [];

  int _headcount = 0;
  int _currentCount = 0;
  int _productionCount = 0;
  int _administrationCount = 0;
  int _matchCount = 0;

  String _search = '';
  int? _roleId;

  /// Null means every worker regardless of employment; otherwise narrows to
  /// currently employed (true) or currently unemployed (false).
  bool? _isActiveFilter;
  int _page = 1;

  WorkersStatusState get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == WorkersStatusState.loading;

  List<UserType> get roles => _roleList;

  /// What the shop floor can be qualified for.
  List<OperationType> get operationTypes => _operationList;

  String get search => _search;
  int? get roleId => _roleId;
  bool? get isActiveFilter => _isActiveFilter;
  int get page => _page;

  bool get hasFilters => _search.isNotEmpty || _roleId != null || _isActiveFilter != null;

  /// The page the table shows.
  List<WorkerRow> get rows => _rows;

  int get matchCount => _matchCount;

  int get pageCount => (_matchCount / pageSize).ceil().clamp(1, 999);

  /// The counters read the whole staff list rather than the filtered page.
  int get headcount => _headcount;

  /// Everyone still employed — an account is deactivated when they leave.
  int get currentCount => _currentCount;
  int get productionCount => _productionCount;
  int get administrationCount => _administrationCount;

  Future<void> setSearch(String value) {
    _search = value;
    _page = 1;
    return _loadPage();
  }

  Future<void> setRole(int? id) {
    _roleId = id;
    _page = 1;
    return _loadPage();
  }

  Future<void> setIsActiveFilter(bool? value) {
    _isActiveFilter = value;
    _page = 1;
    return _loadPage();
  }

  Future<void> setPage(int value) {
    _page = value.clamp(1, pageCount);
    return _loadPage();
  }

  Future<void> clearFilters() {
    _search = '';
    _roleId = null;
    _isActiveFilter = null;
    _page = 1;
    return _loadPage();
  }

  Future<void> load() async {
    _status = WorkersStatusState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final lookups = await Future.wait([
        _all(_userTypes),
        _all(_operationTypes),
      ]);

      _roleList = lookups[0] as List<UserType>;
      _operationList = [...lookups[1] as List<OperationType>]
        ..sort((a, b) => a.name.compareTo(b.name));

      await Future.wait([_loadCounters(), _fetchPage()]);

      _status = WorkersStatusState.ready;
    } on ApiClientException catch (error) {
      _errorMessage = error.message;
      _status = WorkersStatusState.failed;
    } catch (error) {
      _errorMessage = 'Something went wrong while loading workers: $error';
      _status = WorkersStatusState.failed;
    }

    notifyListeners();
  }

  /// What a details screen asks for after saving.
  Future<void> refresh() async {
    try {
      await Future.wait([_loadCounters(), _fetchPage()]);
      _status = WorkersStatusState.ready;
    } on ApiClientException catch (error) {
      _errorMessage = error.message;
      _status = WorkersStatusState.failed;
    } catch (error) {
      _errorMessage = 'Something went wrong while loading workers: $error';
      _status = WorkersStatusState.failed;
    }

    notifyListeners();
  }

  Future<void> _loadPage() async {
    try {
      await _fetchPage();
    } on ApiClientException catch (error) {
      _errorMessage = error.message;
      _status = WorkersStatusState.failed;
    } catch (error) {
      _errorMessage = 'Something went wrong while loading workers: $error';
      _status = WorkersStatusState.failed;
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
        if (_roleId != null) 'userTypeId': _roleId,
        if (_isActiveFilter != null) 'isActive': _isActiveFilter,
      };

  Future<void> _fetchPage() async {
    // Qualifications come along because the page's rows list them, and because
    // the details form diffs against them when it saves.
    final results = await Future.wait([
      _users.get(filter: filter),
      _all(_userOperations),
    ]);

    final page = results[0] as PageResult<User>;
    _qualifications = results[1] as List<UserOperation>;

    _matchCount = page.totalCount ?? page.items.length;
    if (page.items.isEmpty && _page > 1 && _matchCount > 0) {
      _page = pageCount;
      return _fetchPage();
    }

    _rows = _buildRows(page.items);
  }

  Future<void> _loadCounters() async {
    final counts = await Future.wait([
      _count(const {}),
      _count(const {'isActive': true}),
      _countActiveRole(workerRole),
      for (final role in officeRoles) _countActiveRole(role),
    ]);

    _headcount = counts[0];
    _currentCount = counts[1];
    _productionCount = counts[2];
    _administrationCount = counts.skip(3).reduce((a, b) => a + b);
  }

  Future<int> _count(Map<String, dynamic> extra) async {
    final result = await _users.get(filter: {..._countOnly, ...extra});
    return result.totalCount ?? 0;
  }

  /// A role this database does not have counts as nobody.
  Future<int> _countActiveRole(String role) async {
    final id = _roleIdOf(role);
    if (id == null) return 0;

    return _count({'isActive': true, 'userTypeId': id});
  }

  /// A whole lookup table, paged through by [BaseProvider.getAll] because the
  /// API caps how many rows one request may return.
  Future<List<E>> _all<E>(BaseProvider<E> provider) => provider.getAll();

  /// Every row matching the search box, role filter and active-only toggle -
  /// not just the page [rows] holds. The workers table's own column sort and
  /// filter (an Excel-style AutoFilter, tried here first) need the whole
  /// matching set to sort and check values against, not one page of eight.
  Future<List<WorkerRow>> loadAllRows() async {
    final users = await _users.getAll(filter: {
      'sortBy': sortBy,
      if (_search.trim().isNotEmpty) 'search': _search.trim(),
      if (_roleId != null) 'userTypeId': _roleId,
      if (_isActiveFilter != null) 'isActive': _isActiveFilter,
    });
    return _buildRows(users);
  }

  int? _roleIdOf(String role) => _roleList
      .where((type) => type.type.toLowerCase() == role.toLowerCase())
      .map((type) => type.id)
      .firstOrNull;

  List<WorkerRow> _buildRows(List<User> users) {
    final roleById = {for (final type in _roleList) type.id: type};
    final operationById = {for (final operation in _operationList) operation.id: operation};

    final operationsByUser = <int, List<UserOperation>>{};
    for (final qualification in _qualifications) {
      (operationsByUser[qualification.userId] ??= []).add(qualification);
    }

    return users.map((user) {
      final held = operationsByUser[user.id] ?? const <UserOperation>[];

      return WorkerRow(
        id: user.id,
        name: user.name,
        surname: user.surname,
        initials: user.initials,
        email: user.email,
        roleId: user.userTypeId,
        roleName: roleById[user.userTypeId]?.type ?? 'Unknown',
        isActive: user.isActive,
        phoneNumber: user.phoneNumber,
        operations: held
            .map((qualification) => operationById[qualification.operationTypeId]?.name)
            .whereType<String>()
            .toList()
          ..sort(),
        operationIds:
            held.map((qualification) => qualification.operationTypeId).toList(),
      );
    }).toList();
  }

  /// Inserts when [id] is null and updates otherwise. Qualifications are stored
  /// as rows, so they are diffed: what was ticked and is new gets inserted, what
  /// was unticked gets deleted.
  Future<void> saveWorker({
    int? id,
    required String name,
    required String surname,
    required String email,
    required int userTypeId,
    required bool isActive,
    String? phoneNumber,
    String? password,
    List<int> operationIds = const [],
  }) async {
    final body = {
      'name': name,
      'surname': surname,
      'email': email,
      'userTypeId': userTypeId,
      'isActive': isActive,
      'phoneNumber': phoneNumber,
      // Required on insert; on update the API keeps the old one when it is null.
      if (password != null && password.isNotEmpty) 'password': password,
    };

    // On insert the id comes back from the API; on update it is the one we sent.
    final int userId;
    if (id == null) {
      userId = (await _users.insert(body)).id;
    } else {
      await _users.update(id, body);
      userId = id;
    }

    await _saveQualifications(userId, operationIds);
  }

  Future<void> _saveQualifications(int userId, List<int> operationIds) async {
    final held = _qualifications.where((row) => row.userId == userId).toList();
    final wanted = operationIds.toSet();
    final current = held.map((row) => row.operationTypeId).toSet();

    await Future.wait(wanted.difference(current).map(
          (operationTypeId) => _userOperations
              .insert({'userId': userId, 'operationTypeId': operationTypeId}),
        ));

    await Future.wait(
      held
          .where((row) => !wanted.contains(row.operationTypeId))
          .map((row) => _userOperations.remove(row.id)),
    );
  }

  /// Removes the qualifications first: they point at the account.
  Future<void> deleteWorker(int id) async {
    await Future.wait(
      _qualifications
          .where((row) => row.userId == id)
          .map((row) => _userOperations.remove(row.id)),
    );

    await _users.remove(id);
  }
}
