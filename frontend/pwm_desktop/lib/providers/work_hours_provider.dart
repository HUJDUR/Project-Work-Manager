import '../models/models.dart';
import '../utils/api_client_exception.dart';
import '../utils/app_roles.dart';
import '../utils/sarajevo_time.dart';
import 'base_provider.dart';
import 'operation_type_provider.dart';
import 'package:flutter/material.dart';
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

/// The Work Hours screen. The rows - joined to their worker, project and
/// operation, split into regular and overtime, and filtered - come ready-made
/// from `GET /WorkLogDetail/Hours`; changing a filter asks the API again rather
/// than narrowing a downloaded table. The lookups loaded alongside only feed the
/// filter and form dropdowns.
class WorkHoursProvider extends ChangeNotifier {
  WorkHoursProvider({
    int? initialProjectId,
    BaseProvider<WorkHoursEntry>? hours,
    BaseProvider<WorkLog>? workLogs,
    BaseProvider<WorkLogDetail>? workLogDetails,
    BaseProvider<User>? users,
    BaseProvider<UserType>? userTypes,
    BaseProvider<Project>? projects,
    BaseProvider<OperationType>? operationTypes,
  })  : _hours = hours ?? WorkHoursApiProvider(),
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
  /// Mirrors `WorkLogDetailService.RegularHoursPerDay`, which does the split.
  static const double regularHoursPerDay = 8;

  final BaseProvider<WorkHoursEntry> _hours;
  final BaseProvider<WorkLog> _workLogs;
  final BaseProvider<WorkLogDetail> _workLogDetails;
  final BaseProvider<User> _users;
  final BaseProvider<UserType> _userTypes;
  final BaseProvider<Project> _projects;
  final BaseProvider<OperationType> _operationTypes;

  WorkHoursStatusState _status = WorkHoursStatusState.idle;
  String? _errorMessage;
  List<WorkHoursEntry> _entries = const [];
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

  /// Every row the filters match, newest first.
  List<WorkHoursEntry> get entries => _entries;

  double get totalHours => _entries.fold(0, (sum, entry) => sum + entry.totalHours);
  double get regularHours => _entries.fold(0, (sum, entry) => sum + entry.regularHours);
  double get overtimeHours => _entries.fold(0, (sum, entry) => sum + entry.overtimeHours);
  int get workerCount => _entries.map((entry) => entry.userId).toSet().length;

  Future<void> setSearch(String value) {
    _search = value;
    return _reloadEntries();
  }

  Future<void> setProject(int? id) {
    _projectId = id;
    return _reloadEntries();
  }

  Future<void> setDateRange(DateTimeRange? range) {
    _dateRange = range;
    return _reloadEntries();
  }

  Future<void> setHoursFilter(WorkHoursFilter? value) {
    _hoursFilter = value;
    return _reloadEntries();
  }

  Future<void> clearFilters() {
    _search = '';
    _projectId = null;
    _dateRange = null;
    _hoursFilter = null;
    return _reloadEntries();
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
      _entries = results[3] as List<WorkHoursEntry>;

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

  Future<List<WorkHoursEntry>> _fetchEntries() {
    final range = _dateRange;

    return _hours.getAll(filter: {
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

      _entries = entries;
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
    };

    if (id == null) {
      await _workLogDetails.insert(block);
    } else {
      await _workLogDetails.update(id, block);
    }
  }

  /// Removes the block; the API drops the shift with it when nothing else was
  /// booked against it, in the same save.
  Future<void> deleteWorkHours(WorkHoursEntry entry) =>
      _workLogDetails.remove(entry.id);
}
