import '../models/models.dart';
import '../utils/api_client_exception.dart';
import '../utils/sarajevo_time.dart';
import '../utils/shop_floor.dart';
import 'auth_provider.dart';
import 'base_provider.dart';
import 'operation_type_provider.dart';
import 'package:flutter/material.dart';
import 'project_provider.dart';
import 'project_status_type_provider.dart';
import 'user_operation_provider.dart';
import 'work_log_detail_provider.dart';
import 'work_log_provider.dart';


enum ClockInStatus { idle, loading, ready, failed }

/// Clocking on and off a piece of work.
///
/// The shapes, which are not interchangeable:
///
/// - a **`WorkLog` is a shift** — one day of work, from the first clock-in to
///   the last clock-out, and its `Hours` is the day's total;
/// - its **`WorkLogDetail`s are the separate operations** worked through that
///   day;
/// - a **session** is one of those details while it is still running, which is
///   to say while its `FinishedAt` is null.
///
/// So clocking in joins today's shift, raising one only if this is the first
/// session of the day, and adds a detail to it. Clocking out closes the detail
/// and totals the day back onto the shift. **One shift per day, not per
/// session** — three sessions on a Tuesday are three details on one Tuesday
/// shift, not three shifts.
///
/// Two things narrow the dropdowns to what this worker can honestly pick:
/// projects are the ones **in production** (booking time to a delivered job is
/// not a thing), and operations are the ones they are **qualified for** through
/// `UserOperations`.
class ClockInProvider extends ChangeNotifier {
  ClockInProvider({
    BaseProvider<WorkLog>? workLogs,
    BaseProvider<WorkLogDetail>? workLogDetails,
    BaseProvider<Project>? projects,
    BaseProvider<ProjectStatusType>? projectStatuses,
    BaseProvider<OperationType>? operationTypes,
    BaseProvider<UserOperation>? userOperations,
    int? userId,
    DateTime Function()? clock,
  })  : _workLogs = workLogs ?? WorkLogProvider(),
        _workLogDetails = workLogDetails ?? WorkLogDetailProvider(),
        _projects = projects ?? ProjectProvider(),
        _projectStatuses = projectStatuses ?? ProjectStatusTypeProvider(),
        _operationTypes = operationTypes ?? OperationTypeProvider(),
        _userOperations = userOperations ?? UserOperationProvider(),
        _userId = userId ?? AuthProvider.user?.id,
        _clock = clock ?? SarajevoTime.now;

  /// The status whose projects may be booked against — the same definition the
  /// Projects tab lists by, kept in one place.
  static const String bookableStatus = ShopFloor.liveStatus;

  /// How far back to look for a session left running. A shift that crossed
  /// midnight is still the one in progress; anything older than this was a
  /// worker who forgot, and is not something to silently resume.
  static const Duration openSessionWindow = Duration(days: 2);

  final BaseProvider<WorkLog> _workLogs;
  final BaseProvider<WorkLogDetail> _workLogDetails;
  final BaseProvider<Project> _projects;
  final BaseProvider<ProjectStatusType> _projectStatuses;
  final BaseProvider<OperationType> _operationTypes;
  final BaseProvider<UserOperation> _userOperations;
  final int? _userId;
  final DateTime Function() _clock;

  ClockInStatus _status = ClockInStatus.idle;
  String? _errorMessage;
  bool _isSubmitting = false;

  List<Project> _projectOptions = const [];
  List<OperationType> _operationOptions = const [];
  ActiveSession? _active;

  int? _selectedProjectId;
  int? _selectedOperationId;

  ClockInStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == ClockInStatus.loading;

  /// True while a clock-in or clock-out is in flight, which is what stops the
  /// buttons being pressed twice and booking the same minute again.
  bool get isSubmitting => _isSubmitting;

  List<Project> get projectOptions => _projectOptions;
  List<OperationType> get operationOptions => _operationOptions;
  ActiveSession? get active => _active;
  bool get hasActiveSession => _active != null;

  int? get selectedProjectId => _selectedProjectId;
  int? get selectedOperationId => _selectedOperationId;

  /// What stops a worker clocking in: already on something, nothing picked, or
  /// nothing to pick. Null when the button should work.
  String? get clockInBlockedReason {
    if (_active != null) {
      return 'Clock out of your current session first.';
    }
    if (_operationOptions.isEmpty) {
      return 'You are not qualified for any operations yet. Ask the office.';
    }
    if (_projectOptions.isEmpty) {
      return 'No projects are in production to book against.';
    }
    if (_selectedProjectId == null || _selectedOperationId == null) {
      return 'Pick a project and an operation.';
    }
    return null;
  }

  bool get canClockIn => clockInBlockedReason == null && !_isSubmitting;

  void selectProject(int? id) {
    _selectedProjectId = id;
    notifyListeners();
  }

  void selectOperation(int? id) {
    _selectedOperationId = id;
    notifyListeners();
  }

  Future<void> load() async {
    final userId = _userId;

    if (userId == null) {
      _errorMessage = 'No account is signed in.';
      _status = ClockInStatus.failed;
      notifyListeners();
      return;
    }

    _status = ClockInStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _bookableProjects(),
        _qualifiedOperations(userId),
        _openBlock(userId),
      ]);

      _projectOptions = results[0] as List<Project>;
      _operationOptions = results[1] as List<OperationType>;
      _active = await _describe(results[2] as WorkLogDetail?);

      // A pick that is no longer on offer must not survive a reload.
      if (!_projectOptions.any((p) => p.id == _selectedProjectId)) {
        _selectedProjectId = null;
      }
      if (!_operationOptions.any((o) => o.id == _selectedOperationId)) {
        _selectedOperationId = null;
      }

      _status = ClockInStatus.ready;
    } on ApiClientException catch (error) {
      _errorMessage = error.message;
      _status = ClockInStatus.failed;
    } catch (error) {
      _errorMessage = 'Something went wrong while loading Clock In: $error';
      _status = ClockInStatus.failed;
    }

    notifyListeners();
  }

  /// Opens a shift and a block on it, both left unfinished. Throws
  /// [ApiClientException] with the API's own wording if either write is refused.
  Future<void> clockIn() async {
    final userId = _userId;
    final projectId = _selectedProjectId;
    final operationId = _selectedOperationId;

    if (userId == null || projectId == null || operationId == null || _isSubmitting) {
      return;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final now = _clock();
      final shift = await _shiftForToday(userId, now);

      final block = await _workLogDetails.insert({
        'workLogId': shift.id,
        'userId': userId,
        'operationTypeId': operationId,
        'projectId': projectId,
        'startedAt': SarajevoTime.toApi(now),
        'finishedAt': null,
        'hours': 0,
      });

      _active = await _describe(block);
      _selectedProjectId = null;
      _selectedOperationId = null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Closes the block and the shift it hangs off, both at the same moment, with
  /// the hours between. Throws [ApiClientException] if the API refuses.
  Future<void> clockOut() async {
    final session = _active;
    final userId = _userId;

    if (session == null || userId == null || _isSubmitting) return;

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final now = _clock();
      final worked = session.elapsedAt(now);
      final hours = _hoursOf(worked);

      await _workLogDetails.update(session.id, {
        'workLogId': session.workLogId,
        'userId': userId,
        'operationTypeId': session.block.operationTypeId,
        'projectId': session.block.projectId,
        'startedAt': SarajevoTime.toApi(session.startedAt),
        'finishedAt': SarajevoTime.toApi(now),
        'hours': hours,
      });

      // The shift is the whole day, so its hours are the day's operations
      // totalled — not this one session's. They are read back rather than added
      // to, so a session booked from somewhere else still lands in the total.
      // Its start has to be sent back unchanged, and only the row knows it.
      final shift = await _workLogs.getById(session.workLogId);
      final booked =
          await _workLogDetails.getAll(filter: {'workLogId': shift.id});
      final total = booked.fold<double>(0, (sum, block) => sum + block.hours);

      await _workLogs.update(shift.id, {
        'userId': userId,
        'clockedIn': SarajevoTime.toApi(shift.clockedIn),
        'clockedOut': SarajevoTime.toApi(now),
        'hours': double.parse(total.toStringAsFixed(2)),
      });

      _active = null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Today's shift, raised if this is the first session of the day.
  ///
  /// **One shift per day, not per session.** A `WorkLog` is the day; its details
  /// are the separate operations worked through it. So a second session joins
  /// the shift already there rather than starting another, and a shift that was
  /// clocked out of is reopened — the worker is back on the clock, and the day
  /// runs from the first clock-in to the last clock-out.
  Future<WorkLog> _shiftForToday(int userId, DateTime now) async {
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final shifts = await _workLogs.getAll(filter: {
      'userId': userId,
      'dateFrom': dayStart,
      // `DateTo` is compared against `ClockedIn` inclusively, so it stops a
      // microsecond short of tomorrow rather than on it.
      'dateTo': dayEnd.subtract(const Duration(microseconds: 1)),
    });

    final today = shifts
        .where((shift) =>
            !shift.clockedIn.isBefore(dayStart) && shift.clockedIn.isBefore(dayEnd))
        .toList()
      ..sort((a, b) => a.clockedIn.compareTo(b.clockedIn));

    final existing = today.firstOrNull;

    if (existing == null) {
      return await _workLogs.insert({
        'userId': userId,
        'clockedIn': SarajevoTime.toApi(now),
        'clockedOut': null,
        'hours': 0,
      });
    }

    if (existing.clockedOut == null) {
      return existing;
    }

    return await _workLogs.update(existing.id, {
      'userId': userId,
      'clockedIn': SarajevoTime.toApi(existing.clockedIn),
      // Back on the clock: the day is not over after all.
      'clockedOut': null,
      'hours': existing.hours,
    });
  }

  /// Hours to two decimals, which is the precision the seeded rows carry and
  /// enough for a booking read off a clock.
  static double _hoursOf(Duration worked) =>
      double.parse((worked.inSeconds / 3600).toStringAsFixed(2));

  Future<List<Project>> _bookableProjects() async {
    final statuses = await _projectStatuses.getAll();
    final bookable = ShopFloor.liveStatusId(statuses);

    // No such status is a seeding problem, not a reason to offer every project
    // including the ones already delivered.
    if (bookable == null) return const [];

    final projects =
        await _projects.getAll(filter: {'projectStatusId': bookable});

    return projects..sort((a, b) => a.code.compareTo(b.code));
  }

  Future<List<OperationType>> _qualifiedOperations(int userId) async {
    final results = await Future.wait([
      _userOperations.getAll(filter: {'userId': userId}),
      _operationTypes.getAll(),
    ]);
    final qualifications = results[0] as List<UserOperation>;
    final allowed =
        qualifications.map((row) => row.operationTypeId).toSet();

    final operations = results[1] as List<OperationType>;

    return operations.where((operation) => allowed.contains(operation.id)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// The block left running, if there is one. There is no "unfinished" filter on
  /// the API, so this asks for the recent ones and picks the open one out.
  Future<WorkLogDetail?> _openBlock(int userId) async {
    final since = _clock().subtract(openSessionWindow);

    final recent = await _workLogDetails.getAll(filter: {
      'userId': userId,
      'dateFrom': since,
    });

    final open = recent
        .where((block) => block.finishedAt == null && !block.startedAt.isBefore(since))
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    return open.firstOrNull;
  }

  /// Puts names to a block's ids. The project usually comes from the list
  /// already loaded; one that has since left production does not, so it is
  /// fetched — a session must still say what it is running against.
  Future<ActiveSession?> _describe(WorkLogDetail? block) async {
    if (block == null) return null;

    var project =
        _projectOptions.where((p) => p.id == block.projectId).firstOrNull;
    project ??= await _projects.getById(block.projectId);

    final operation = _operationOptions
        .where((o) => o.id == block.operationTypeId)
        .firstOrNull;

    return ActiveSession(
      block: block,
      projectLabel: project.code.isEmpty
          ? project.name
          : '${project.code} - ${project.name}',
      operationName: operation?.name ?? 'Unknown operation',
    );
  }
}
