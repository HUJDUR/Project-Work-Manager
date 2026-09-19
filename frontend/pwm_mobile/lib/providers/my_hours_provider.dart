import 'package:flutter/material.dart';

import '../models/models.dart';
import '../utils/api_client_exception.dart';
import 'auth_provider.dart';
import 'base_provider.dart';
import 'operation_type_provider.dart';
import 'project_provider.dart';
import 'work_log_detail_provider.dart';

enum MyHoursStatus { idle, loading, ready, failed }

/// The stretch of time the screen is showing. The mockup's picker is a plain
/// dropdown, so these are ranges a worker actually asks for rather than a free
/// date range, which would need two pickers and a lot more screen.
enum HoursPeriod {
  thisWeek('This week'),
  lastWeek('Last week'),
  thisMonth('This month'),
  lastMonth('Last month');

  const HoursPeriod(this.label);

  final String label;
}

/// A half-open range: `from` inclusive, `to` exclusive.
typedef DateRange = ({DateTime from, DateTime to});

/// My Work Hours: the signed-in worker's own bookings, grouped into days.
///
/// The list costs **one request**. `WorkLogDetail` carries its own `UserId`, so
/// the blocks come back already narrowed, and `dateFrom`/`dateTo` keep them to
/// the chosen period. Everything the list shows — the day rows, both totals and
/// both sparklines — is derived from that one answer.
///
/// Project and operation *names* are not: the list never shows them, so they
/// are fetched only when a day is opened, the same way the desktop's
/// `TransportsProvider.linesOf` leaves a load's cargo until its row is tapped.
class MyHoursProvider extends ChangeNotifier {
  MyHoursProvider({
    BaseProvider<WorkLogDetail>? workLogDetails,
    BaseProvider<Project>? projects,
    BaseProvider<OperationType>? operationTypes,
    int? userId,
    DateTime Function()? clock,
  })  : _workLogDetails = workLogDetails ?? WorkLogDetailProvider(),
        _projects = projects ?? ProjectProvider(),
        _operationTypes = operationTypes ?? OperationTypeProvider(),
        _userId = userId ?? AuthProvider.user?.id,
        _clock = clock ?? DateTime.now;

  final BaseProvider<WorkLogDetail> _workLogDetails;
  final BaseProvider<Project> _projects;
  final BaseProvider<OperationType> _operationTypes;
  final int? _userId;
  final DateTime Function() _clock;

  MyHoursStatus _status = MyHoursStatus.idle;
  HoursPeriod _period = HoursPeriod.thisWeek;
  List<WorkDay> _days = const [];
  String? _errorMessage;

  /// Resolved once each and kept: a worker books against the same handful of
  /// projects all week, so opening a second day usually costs nothing.
  final Map<int, Project> _projectCache = {};
  Map<int, String>? _operationNames;

  MyHoursStatus get status => _status;
  HoursPeriod get period => _period;
  List<WorkDay> get days => _days;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == MyHoursStatus.loading;
  bool get isEmpty => _status == MyHoursStatus.ready && _days.isEmpty;

  double get totalHours =>
      _days.fold<double>(0, (sum, day) => sum + day.hours);

  /// Distinct across the whole period, not the sum of each day's count.
  int get projectCount =>
      _days.expand((day) => day.projectIds).toSet().length;

  /// Hours per day across the period, oldest first and including the days with
  /// nothing on them — a sparkline with the gaps left out would draw a week of
  /// two shifts as a straight line.
  List<double> get hoursTrend =>
      _seriesByDay((day) => day?.hours ?? 0);

  List<double> get projectsTrend =>
      _seriesByDay((day) => (day?.projectCount ?? 0).toDouble());

  DateRange get range => rangeFor(_period, _clock());

  Future<void> setPeriod(HoursPeriod period) async {
    if (_period == period) return;

    _period = period;
    await load();
  }

  Future<void> load() async {
    final userId = _userId;

    if (userId == null) {
      _errorMessage = 'No account is signed in.';
      _status = MyHoursStatus.failed;
      notifyListeners();
      return;
    }

    _status = MyHoursStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final window = range;

      final blocks = await _workLogDetails.getAll(filter: {
        'userId': userId,
        'dateFrom': window.from,
        'dateTo': window.to,
      });

      // The window is applied here as well as in the request, so an API that
      // ignores the dates cannot put another month's work in this one's totals.
      _days = _group(blocks.where((block) =>
          !block.startedAt.isBefore(window.from) &&
          block.startedAt.isBefore(window.to)));

      _status = MyHoursStatus.ready;
    } on ApiClientException catch (error) {
      _errorMessage = error.message;
      _status = MyHoursStatus.failed;
    } catch (error) {
      _errorMessage = 'Something went wrong while loading your hours: $error';
      _status = MyHoursStatus.failed;
    }

    notifyListeners();
  }

  /// The blocks of one day with their project and operation names filled in.
  /// Throws [ApiClientException] the way every other call does, so the day
  /// screen can show the API's own wording.
  Future<List<WorkEntry>> entriesFor(WorkDay day) async {
    final results = await Future.wait([
      _operationNamesOnce(),
      _cacheProjects(day.projectIds),
    ]);
    final operations = results[0] as Map<int, String>;

    return day.blocks.map((block) {
      final project = _projectCache[block.projectId];

      return WorkEntry(
        projectName: project?.name ?? 'Unknown project',
        projectCode: project?.code ?? '',
        operationName: operations[block.operationTypeId] ?? 'Unknown operation',
        startedAt: block.startedAt,
        hours: block.hours,
        finishedAt: block.finishedAt,
      );
    }).toList();
  }

  /// Operations are a small fixed lookup, so the whole table is read once.
  Future<Map<int, String>> _operationNamesOnce() async {
    final cached = _operationNames;
    if (cached != null) return cached;

    final rows = await _operationTypes.getAll();
    return _operationNames = {for (final row in rows) row.id: row.name};
  }

  /// Projects are **not** a lookup table — they grow — so this asks for the few
  /// the day actually names rather than reading the lot. There is no "by ids"
  /// filter on `ProjectSearchObject`, which is why it is one call each; adding
  /// one would collapse this to a single request.
  Future<void> _cacheProjects(Set<int> ids) async {
    final missing = ids.where((id) => !_projectCache.containsKey(id)).toList();
    if (missing.isEmpty) return;

    final fetched = await Future.wait(missing.map(_projects.getById));

    for (final project in fetched) {
      _projectCache[project.id] = project;
    }
  }

  List<WorkDay> _group(Iterable<WorkLogDetail> blocks) {
    final byDate = <DateTime, List<WorkLogDetail>>{};

    for (final block in blocks) {
      final date = _dateOf(block.startedAt);
      (byDate[date] ??= []).add(block);
    }

    final days = byDate.entries
        .map((entry) => WorkDay(
              date: entry.key,
              blocks: entry.value
                ..sort((a, b) => a.startedAt.compareTo(b.startedAt)),
            ))
        .toList()
      // Newest day first: the one a worker wants is the one just finished.
      ..sort((a, b) => b.date.compareTo(a.date));

    return days;
  }

  /// One value per calendar day of the period, oldest first.
  List<double> _seriesByDay(double Function(WorkDay?) valueOf) {
    if (_days.isEmpty) return const [];

    final byDate = {for (final day in _days) day.date: day};
    final window = range;
    final series = <double>[];

    for (var date = window.from;
        date.isBefore(window.to);
        date = _dateOf(date.add(const Duration(days: 1)))) {
      series.add(valueOf(byDate[date]));
    }

    return series;
  }

  static DateTime _dateOf(DateTime moment) =>
      DateTime(moment.year, moment.month, moment.day);

  /// What each period means, resolved against [now]. The week runs **Monday to
  /// Sunday**, the same rule the dashboard counts by.
  static DateRange rangeFor(HoursPeriod period, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final thisWeek = today.subtract(Duration(days: now.weekday - 1));

    return switch (period) {
      HoursPeriod.thisWeek => (
          from: thisWeek,
          to: thisWeek.add(const Duration(days: 7)),
        ),
      HoursPeriod.lastWeek => (
          from: thisWeek.subtract(const Duration(days: 7)),
          to: thisWeek,
        ),
      HoursPeriod.thisMonth => (
          from: DateTime(now.year, now.month, 1),
          to: DateTime(now.year, now.month + 1, 1),
        ),
      HoursPeriod.lastMonth => (
          from: DateTime(now.year, now.month - 1, 1),
          to: DateTime(now.year, now.month, 1),
        ),
    };
  }
}
