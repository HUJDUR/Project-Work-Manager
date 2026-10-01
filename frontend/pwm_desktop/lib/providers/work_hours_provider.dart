import '../models/models.dart';
import '../utils/api_client_exception.dart';
import '../utils/app_roles.dart';
import '../utils/sarajevo_time.dart';
import 'base_provider.dart';
import 'operation_type_provider.dart';
import 'package:material_ui/material_ui.dart';
import 'project_provider.dart';
import 'user_provider.dart';
import 'user_type_provider.dart';
import 'work_hours_api_provider.dart';
import 'work_log_detail_provider.dart';
import 'work_log_provider.dart';


enum WorkHoursStatusState { idle, loading, ready, failed }

/// The "hours" dropdown. [apiName] is what `GET /WorkLogDetail/Hours` takes.
enum WorkHoursFilter {
  regularOnly('Regular hours only', 'RegularOnly'),
  overtimeOnly('Overtime hours only', 'OvertimeOnly'),
  inProgressOnly('In progress only', 'InProgressOnly');

  const WorkHoursFilter(this.label, this.apiName);

  final String label;
  final String apiName;
}

/// The Work Hours screen. One page of rows - joined to their worker, project
/// and operation, split into regular and overtime, filtered and sorted - comes
/// ready-made from `GET /WorkLogDetail/Hours`, with the totals of every row the
/// filters match; changing a filter, the sort or the page asks the API again.
/// The lookups loaded alongside only feed the filter and form dropdowns.
class WorkHoursProvider extends ChangeNotifier {
  WorkHoursProvider({
    int? initialProjectId,
    WorkHoursApiProvider? hours,
    BaseProvider<WorkLog>? workLogs,
    BaseProvider<WorkLogDetail>? workLogDetails,
    BaseProvider<User>? users,
    BaseProvider<UserType>? userTypes,
    BaseProvider<Project>? projects,
    BaseProvider<OperationType>? operationTypes,
    Future<List<WorkHoursChange>> Function(int workLogDetailId)? history,
  })  : _history = history ?? WorkLogDetailProvider().history,
        _hours = hours ?? WorkHoursApiProvider(),
        _workLogs = workLogs ?? WorkLogProvider(),
        _workLogDetails = workLogDetails ?? WorkLogDetailProvider(),
        _users = users ?? UserProvider(),
        _userTypes = userTypes ?? UserTypeProvider(),
        _projects = projects ?? ProjectProvider(),
        _operationTypes = operationTypes ?? OperationTypeProvider(),
        // Lets a caller land on this screen already scoped to one project -
        // the Project Details page's "View all work hours" button.
        _projectId = initialProjectId;

  /// A worker's day is regular up to this many hours; the rest is overtime.
  /// Mirrors `OvertimeRules.RegularHoursPerDay` on the API, which does the split.
  static const double regularHoursPerDay = 8;

  static const int pageSize = 8;

  final WorkHoursApiProvider _hours;
  final Future<List<WorkHoursChange>> Function(int workLogDetailId) _history;
  final BaseProvider<WorkLog> _workLogs;
  final BaseProvider<WorkLogDetail> _workLogDetails;
  final BaseProvider<User> _users;
  final BaseProvider<UserType> _userTypes;
  final BaseProvider<Project> _projects;
  final BaseProvider<OperationType> _operationTypes;

  WorkHoursStatusState _status = WorkHoursStatusState.idle;
  String? _errorMessage;
  WorkHoursPage _page = const WorkHoursPage(
    items: [],
    totalCount: 0,
    totalHours: 0,
    regularHours: 0,
    overtimeHours: 0,
    workerCount: 0,
  );
  int _pageNumber = 1;

  /// A column key `GET /WorkLogDetail/Hours` sorts by - newest first to start.
  String _sortKey = 'Date';
  bool _sortAscending = false;
  List<Project> _projectList = const [];
  List<User> _workerList = const [];
  List<OperationType> _operationList = const [];

  /// Bumped per entries request, so an older answer arriving after a newer
  /// one (filters changed quickly) is dropped instead of overwriting it.
  int _request = 0;

  String _search = '';
  int? _projectId;
  DateTimeRange? _dateRange;
  WorkHoursFilter? _hoursFilter;

  WorkHoursStatusState get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == WorkHoursStatusState.loading;

  List<Project> get projects => _projectList;
  List<User> get workers => _workerList;
  List<OperationType> get operationTypes => _operationList;

  String get search => _search;
  int? get projectId => _projectId;
  DateTimeRange? get dateRange => _dateRange;
  WorkHoursFilter? get hoursFilter => _hoursFilter;

  bool get hasFilters =>
      _search.isNotEmpty || _projectId != null || _dateRange != null || _hoursFilter != null;

  /// The page on screen.
  List<WorkHoursEntry> get entries => _page.items;

  int get page => _pageNumber;
  int get pageCount => _page.totalCount == 0 ? 1 : (_page.totalCount / pageSize).ceil();

  /// How many rows the filters match, across every page.
  int get entryCount => _page.totalCount;

  String get sortKey => _sortKey;
  bool get sortAscending => _sortAscending;

  double get totalHours => _page.totalHours;
  double get regularHours => _page.regularHours;
  double get overtimeHours => _page.overtimeHours;
  int get workerCount => _page.workerCount;

  Future<void> setSearch(String value) {
    _search = value;
    return _reloadFirstPage();
  }

  Future<void> setProject(int? id) {
    _projectId = id;
    return _reloadFirstPage();
  }

  Future<void> setDateRange(DateTimeRange? range) {
    _dateRange = range;
    return _reloadFirstPage();
  }

  Future<void> setHoursFilter(WorkHoursFilter? value) {
    _hoursFilter = value;
    return _reloadFirstPage();
  }

  /// The same column again flips the direction; a new one starts ascending.
  Future<void> setSort(String key) {
    _sortAscending = key == _sortKey ? !_sortAscending : true;
    _sortKey = key;
    return _reloadFirstPage();
  }

  Future<void> setPage(int value) {
    _pageNumber = value;
    return _reloadEntries();
  }

  Future<void> _reloadFirstPage() {
    _pageNumber = 1;
    return _reloadEntries();
  }

  Future<void> clearFilters() {
    _search = '';
    _projectId = null;
    _dateRange = null;
    _hoursFilter = null;
    return _reloadFirstPage();
  }

  Future<void> load() async {
    _status = WorkHoursStatusState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _projects.getAll(),
        _userTypes.getAll(),
        _operationTypes.getAll(),
        _fetchEntries(),
      ]);

      final projects = results[0] as List<Project>;
      final userTypes = results[1] as List<UserType>;
      final operations = results[2] as List<OperationType>;
      _page = results[3] as WorkHoursPage;

      _projectList = [...projects]..sort((a, b) => a.name.compareTo(b.name));
      _operationList = [...operations]..sort((a, b) => a.name.compareTo(b.name));
      _workerList = await _activeWorkers(userTypes);

      _status = WorkHoursStatusState.ready;
    } on ApiClientException catch (error) {
      _errorMessage = error.message;
      _status = WorkHoursStatusState.failed;
    } catch (error) {
      _errorMessage = 'Something went wrong while loading work hours: $error';
      _status = WorkHoursStatusState.failed;
    }

    notifyListeners();
  }

  /// The workers a new entry can be booked for: active production workers,
  /// filtered by the API rather than out of the whole user table.
  Future<List<User>> _activeWorkers(List<UserType> userTypes) async {
    final workerTypeId = userTypes
        .where((type) => type.type == AppRoles.productionWorker)
        .map((type) => type.id)
        .firstOrNull;

    final users = await _users.getAll(filter: {
      'isActive': true,
      'userTypeId': ?workerTypeId,
    });

    return [...users]..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  Future<WorkHoursPage> _fetchEntries() {
    final range = _dateRange;

    return _hours.page({
      'page': _pageNumber,
      'pageSize': pageSize,
      'includeTotalCount': true,
      'sortBy': _sortAscending ? _sortKey : '$_sortKey desc',
      if (_search.trim().isNotEmpty) 'search': _search.trim(),
      'projectId': ?_projectId,
      if (range != null) 'dateFrom': DateUtils.dateOnly(range.start),
      if (range != null) 'dateTo': DateUtils.dateOnly(range.end),
      'hoursFilter': ?_hoursFilter?.apiName,
    });
  }

  Future<void> _reloadEntries() async {
    final request = ++_request;
    notifyListeners();

    try {
      final entries = await _fetchEntries();
      if (request != _request) return;

      _page = entries;
      _errorMessage = null;
      _status = WorkHoursStatusState.ready;
    } on ApiClientException catch (error) {
      if (request != _request) return;
      _errorMessage = error.message;
      _status = WorkHoursStatusState.failed;
    } catch (error) {
      if (request != _request) return;
      _errorMessage = 'Something went wrong while loading work hours: $error';
      _status = WorkHoursStatusState.failed;
    }

    notifyListeners();
  }

  /// Inserts when [id] is null and updates otherwise. Adding writes the shift
  /// first because the detail needs its id - the API has no endpoint that
  /// creates both. Editing writes the same pair back.
  Future<void> saveWorkHours({
    int? id,
    int? workLogId,
    required int userId,
    required int projectId,
    required int operationTypeId,
    required DateTime startedAt,
    required DateTime finishedAt,
    String? note,
  }) async {
    final hours = finishedAt.difference(startedAt).inMinutes / 60;

    final shift = {
      'userId': userId,
      'clockedIn': SarajevoTime.toApi(startedAt),
      'clockedOut': SarajevoTime.toApi(finishedAt),
      'hours': hours,
    };

    final logId = workLogId == null
        ? (await _workLogs.insert(shift)).id
        : (await _workLogs.update(workLogId, shift)).id;

    final block = {
      'workLogId': logId,
      'userId': userId,
      'operationTypeId': operationTypeId,
      'projectId': projectId,
      'startedAt': SarajevoTime.toApi(startedAt),
      'finishedAt': SarajevoTime.toApi(finishedAt),
      'hours': hours,
      'note': (note == null || note.trim().isEmpty) ? null : note.trim(),
    };

    if (id == null) {
      await _workLogDetails.insert(block);
    } else {
      await _workLogDetails.update(id, block);
    }
  }

  /// Who corrected [entry], when, and from what to what - newest first.
  Future<List<WorkHoursChange>> history(WorkHoursEntry entry) => _history(entry.id);

  /// Removes the block; the API drops the shift with it when nothing else was
  /// booked against it, in the same save.
  Future<void> deleteWorkHours(WorkHoursEntry entry) =>
      _workLogDetails.remove(entry.id);
}
