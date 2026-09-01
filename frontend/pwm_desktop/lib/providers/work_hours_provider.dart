import 'package:flutter/material.dart';

import '../models/models.dart';
import '../utils/api_client_exception.dart';
import 'base_provider.dart';
import 'operation_type_provider.dart';
import 'project_provider.dart';
import 'user_provider.dart';
import 'user_type_provider.dart';
import 'work_log_detail_provider.dart';
import 'work_log_provider.dart';

enum WorkHoursStatusState { idle, loading, ready, failed }

/// Rows come from `WorkLogDetail`, but the worker, project and operation names
/// live in three other tables and regular/overtime is not stored at all, so the
/// whole screen is assembled here.
class WorkHoursProvider extends ChangeNotifier {
  WorkHoursProvider({
    BaseProvider<WorkLog>? workLogs,
    BaseProvider<WorkLogDetail>? workLogDetails,
    BaseProvider<User>? users,
    BaseProvider<UserType>? userTypes,
    BaseProvider<Project>? projects,
    BaseProvider<OperationType>? operationTypes,
  })  : _workLogs = workLogs ?? WorkLogProvider(),
        _workLogDetails = workLogDetails ?? WorkLogDetailProvider(),
        _users = users ?? UserProvider(),
        _userTypes = userTypes ?? UserTypeProvider(),
        _projects = projects ?? ProjectProvider(),
        _operationTypes = operationTypes ?? OperationTypeProvider();

  /// A worker's day is regular up to this many hours; the rest is overtime.
  static const double regularHoursPerDay = 8;

  final BaseProvider<WorkLog> _workLogs;
  final BaseProvider<WorkLogDetail> _workLogDetails;
  final BaseProvider<User> _users;
  final BaseProvider<UserType> _userTypes;
  final BaseProvider<Project> _projects;
  final BaseProvider<OperationType> _operationTypes;

  WorkHoursStatusState _status = WorkHoursStatusState.idle;
  String? _errorMessage;
  List<WorkHoursEntry> _allEntries = const [];
  List<Project> _projectList = const [];
  List<User> _workerList = const [];
  List<OperationType> _operationList = const [];

  String _search = '';
  int? _projectId;
  DateTimeRange? _dateRange;
  bool _overtimeOnly = false;
  bool _inProgressOnly = false;

  WorkHoursStatusState get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == WorkHoursStatusState.loading;

  List<Project> get projects => _projectList;
  List<User> get workers => _workerList;
  List<OperationType> get operationTypes => _operationList;

  String get search => _search;
  int? get projectId => _projectId;
  DateTimeRange? get dateRange => _dateRange;
  bool get overtimeOnly => _overtimeOnly;
  bool get inProgressOnly => _inProgressOnly;

  bool get hasFilters =>
      _search.isNotEmpty ||
      _projectId != null ||
      _dateRange != null ||
      _overtimeOnly ||
      _inProgressOnly;

  List<WorkHoursEntry> get entries {
    final needle = _search.trim().toLowerCase();

    return _allEntries.where((entry) {
      if (needle.isNotEmpty && !entry.workerName.toLowerCase().contains(needle)) {
        return false;
      }
      if (_projectId != null && entry.projectId != _projectId) return false;
      if (_overtimeOnly && !entry.isOvertime) return false;
      if (_inProgressOnly && entry.status != WorkHoursStatus.inProgress) return false;

      final range = _dateRange;
      if (range != null) {
        final day = DateUtils.dateOnly(entry.date);
        if (day.isBefore(DateUtils.dateOnly(range.start))) return false;
        if (day.isAfter(DateUtils.dateOnly(range.end))) return false;
      }

      return true;
    }).toList();
  }

  double get totalHours => entries.fold(0, (sum, entry) => sum + entry.totalHours);
  double get regularHours => entries.fold(0, (sum, entry) => sum + entry.regularHours);
  double get overtimeHours => entries.fold(0, (sum, entry) => sum + entry.overtimeHours);
  int get workerCount => entries.map((entry) => entry.userId).toSet().length;

  void setSearch(String value) {
    _search = value;
    notifyListeners();
  }

  void setProject(int? id) {
    _projectId = id;
    notifyListeners();
  }

  void setDateRange(DateTimeRange? range) {
    _dateRange = range;
    notifyListeners();
  }

  void setOvertimeOnly(bool value) {
    _overtimeOnly = value;
    notifyListeners();
  }

  void setInProgressOnly(bool value) {
    _inProgressOnly = value;
    notifyListeners();
  }

  void clearFilters() {
    _search = '';
    _projectId = null;
    _dateRange = null;
    _overtimeOnly = false;
    _inProgressOnly = false;
    notifyListeners();
  }

  Future<void> load() async {
    _status = WorkHoursStatusState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _rows(_workLogs),
        _rows(_workLogDetails),
        _rows(_users),
        _rows(_userTypes),
        _rows(_projects),
        _rows(_operationTypes),
      ]);

      final workLogs = results[0] as List<WorkLog>;
      final details = results[1] as List<WorkLogDetail>;
      final users = results[2] as List<User>;
      final userTypes = results[3] as List<UserType>;
      final projects = results[4] as List<Project>;
      final operations = results[5] as List<OperationType>;

      _projectList = [...projects]..sort((a, b) => a.name.compareTo(b.name));
      _operationList = [...operations]..sort((a, b) => a.name.compareTo(b.name));

      final workerTypeId = userTypes
          .where((type) => type.type.toLowerCase() == 'worker')
          .map((type) => type.id)
          .firstOrNull;
      _workerList = users
          .where((user) =>
              user.isActive && (workerTypeId == null || user.userTypeId == workerTypeId))
          .toList()
        ..sort((a, b) => a.fullName.compareTo(b.fullName));

      _allEntries = _buildEntries(workLogs, details, users, projects, operations);
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

  /// A whole lookup table, paged through by [BaseProvider.getAll] because the
  /// API caps how many rows one request may return.
  Future<List<E>> _rows<E>(BaseProvider<E> provider) => provider.getAll();

  List<WorkHoursEntry> _buildEntries(
    List<WorkLog> workLogs,
    List<WorkLogDetail> details,
    List<User> users,
    List<Project> projects,
    List<OperationType> operations,
  ) {
    final workLogById = {for (final log in workLogs) log.id: log};
    final userById = {for (final user in users) user.id: user};
    final projectById = {for (final project in projects) project.id: project};
    final operationById = {for (final operation in operations) operation.id: operation};

    // Overtime is whatever a worker books past eight hours on a given day, so
    // the split depends on the other rows of that day and on their order.
    final ordered = [...details]..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final usedPerWorkerDay = <String, double>{};

    final entries = <WorkHoursEntry>[];
    for (final detail in ordered) {
      final workLog = workLogById[detail.workLogId];
      final worker = userById[workLog?.userId];
      final day = DateUtils.dateOnly(detail.startedAt);
      final key = '${workLog?.userId}-${day.toIso8601String()}';

      final used = usedPerWorkerDay[key] ?? 0;
      final regular = (regularHoursPerDay - used).clamp(0, detail.hours).toDouble();
      usedPerWorkerDay[key] = used + detail.hours;

      entries.add(WorkHoursEntry(
        id: detail.id,
        workLogId: detail.workLogId,
        userId: workLog?.userId ?? 0,
        projectId: detail.projectId,
        operationTypeId: detail.operationTypeId,
        workerName: worker?.fullName ?? 'Unknown worker',
        workerInitials: worker?.initials ?? '?',
        projectName: projectById[detail.projectId]?.name ?? 'Unknown project',
        operationName: operationById[detail.operationTypeId]?.name ?? 'Unknown operation',
        date: detail.startedAt,
        startedAt: detail.startedAt,
        finishedAt: detail.finishedAt,
        regularHours: regular,
        overtimeHours: detail.hours - regular,
        status: detail.finishedAt == null || workLog?.clockedOut == null
            ? WorkHoursStatus.inProgress
            : WorkHoursStatus.completed,
      ));
    }

    return entries.reversed.toList();
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
      'clockedIn': startedAt.toIso8601String(),
      'clockedOut': finishedAt.toIso8601String(),
      'hours': hours,
    };

    final logId = workLogId == null
        ? (await _workLogs.insert(shift)).id
        : (await _workLogs.update(workLogId, shift)).id;

    final block = {
      'workLogId': logId,
      'operationTypeId': operationTypeId,
      'projectId': projectId,
      'startedAt': startedAt.toIso8601String(),
      'finishedAt': finishedAt.toIso8601String(),
      'hours': hours,
    };

    if (id == null) {
      await _workLogDetails.insert(block);
    } else {
      await _workLogDetails.update(id, block);
    }
  }

  /// Removes the block, and the shift with it when nothing else was booked
  /// against it - a shift with no work on it is not a record of anything.
  Future<void> deleteWorkHours(WorkHoursEntry entry) async {
    await _workLogDetails.remove(entry.id);

    final siblings = _allEntries
        .where((other) => other.workLogId == entry.workLogId && other.id != entry.id);
    if (siblings.isEmpty) {
      await _workLogs.remove(entry.workLogId);
    }
  }
}
