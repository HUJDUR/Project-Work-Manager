import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../utils/api_client_exception.dart';
import '../utils/app_roles.dart';
import 'activity_log_provider.dart';
import 'activity_log_type_provider.dart';
import 'auth_provider.dart';
import 'base_provider.dart';
import 'generated_report_provider.dart';
import 'project_provider.dart';
import 'report_provider.dart';
import 'user_provider.dart';

enum ReportsStatusState { idle, loading, ready, failed }

/// The Reports screen's own store. Generating a report is one POST that answers
/// PDF bytes; nothing stores the document, so the Recent Reports list is rows in
/// `GeneratedReports` and its download button re-runs the endpoint.
class ReportsProvider extends ChangeNotifier {
  ReportsProvider({
    ReportProvider? reports,
    BaseProvider<GeneratedReport>? generatedReports,
    BaseProvider<ActivityLog>? activityLogs,
    BaseProvider<ActivityLogType>? activityLogTypes,
    BaseProvider<User>? users,
    BaseProvider<Project>? projects,
    DateTime? today,
    String? role,
  })  : availableTypes = AppRoles.reportsFor(role ?? AuthProvider.role),
        _reports = reports ?? ReportProvider(),
        _generatedReports = generatedReports ?? GeneratedReportProvider(),
        _activityLogs = activityLogs ?? ActivityLogProvider(),
        _activityLogTypes = activityLogTypes ?? ActivityLogTypeProvider(),
        _users = users ?? UserProvider(),
        _projects = projects ?? ProjectProvider(),
        _today = today ?? DateTime.now() {
    _year = _today.year;
    _month = _today.month;
    _type = availableTypes.first;
  }

  /// The reports this role may run — a project manager gets transports only.
  final List<ReportType> availableTypes;

  /// How many past runs the Recent Reports panel lists.
  static const int recentCount = 8;

  /// How far back the Period dropdown reaches.
  static const int periodMonths = 24;

  /// Newest first. `GeneratedReports` carries no timestamp of its own any more,
  /// and its Ids are handed out in order, so the Id is the run order.
  static const String recentSortBy = 'Id desc';

  /// The prefix `ReportService` gives the activity log type it writes per run.
  static const String reportLogTypePrefix = 'Generated report - ';

  static final DateFormat _monthLabel = DateFormat('MMMM yyyy');

  final ReportProvider _reports;
  final BaseProvider<GeneratedReport> _generatedReports;
  final BaseProvider<ActivityLog> _activityLogs;
  final BaseProvider<ActivityLogType> _activityLogTypes;
  final BaseProvider<User> _users;
  final BaseProvider<Project> _projects;
  final DateTime _today;

  ReportsStatusState _status = ReportsStatusState.idle;
  String? _errorMessage;

  List<User> _workerList = const [];
  List<Project> _projectList = const [];
  Map<int, User> _userById = const {};
  Map<int, Project> _projectById = const {};
  List<RecentReport> _recent = const [];

  late ReportType _type;
  late int _year;
  late int _month;
  int? _userId;
  int? _projectId;
  DateTimeRange? _dateRange;

  Uint8List? _pdf;
  String? _pdfLabel;
  String _fileName = 'report.pdf';
  bool _generating = false;

  ReportsStatusState get status => _status;
  String? get errorMessage => _errorMessage;

  List<User> get workers => _workerList;
  List<Project> get projects => _projectList;
  List<RecentReport> get recent => _recent;

  ReportType get type => _type;
  int get year => _year;
  int get month => _month;
  int? get userId => _userId;
  int? get projectId => _projectId;
  DateTimeRange? get dateRange => _dateRange;

  /// The bytes the preview pane renders, and what Print and Download hand on.
  Uint8List? get pdf => _pdf;

  /// What the preview is showing, e.g. "Monthly Work Hours · June 2026".
  String? get pdfLabel => _pdfLabel;

  String get fileName => _fileName;
  bool get generating => _generating;

  /// The months the Period dropdown offers, newest first.
  List<DateTime> get periods => [
        for (var back = 0; back < periodMonths; back++)
          DateTime(_today.year, _today.month - back),
      ];

  DateTime get period => DateTime(_year, _month);

  static String periodLabel(DateTime month) => _monthLabel.format(month);

  void setType(ReportType value) {
    if (_type == value) return;
    _type = value;
    notifyListeners();
  }

  void setPeriod(DateTime value) {
    _year = value.year;
    _month = value.month;
    notifyListeners();
  }

  void setWorker(int? id) {
    _userId = id;
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

  /// The workers and projects the parameter dropdowns offer, and the past runs.
  Future<void> load() async {
    _status = ReportsStatusState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final lookups = await Future.wait([
        _all(_users),
        _all(_projects),
      ]);

      final users = lookups[0] as List<User>;
      final projects = lookups[1] as List<Project>;

      _userById = {for (final user in users) user.id: user};
      _projectById = {for (final project in projects) project.id: project};

      _workerList = users.where((user) => user.isActive).toList()
        ..sort((a, b) => a.fullName.compareTo(b.fullName));
      _projectList = [...projects]..sort((a, b) => a.name.compareTo(b.name));

      await _fetchRecent();

      _status = ReportsStatusState.ready;
    } on ApiClientException catch (error) {
      _errorMessage = error.message;
      _status = ReportsStatusState.failed;
    } catch (error) {
      _errorMessage = 'Something went wrong while loading reports: $error';
      _status = ReportsStatusState.failed;
    }

    notifyListeners();
  }

  /// Queues the selected report, waits for `pwm.Worker` to render it - off
  /// RabbitMQ, in its own process - and hands the PDF to the preview once it
  /// answers "Completed". A run also writes a `GeneratedReport` row, so the
  /// recent list is refetched after it either way.
  Future<void> generate() async {
    _generating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final queued = switch (_type) {
        ReportType.monthlyWorkHours => await _reports.monthlyWorkHours(
            year: _year,
            month: _month,
            userId: _userId,
            projectId: _projectId,
          ),
        ReportType.transportLoads => await _reports.transportLoads(
            projectId: _projectId,
            dateFrom: _dateRange?.start,
            dateTo: _endOfDay(_dateRange?.end),
          ),
      };

      await _reports.awaitCompletion(queued.id);
      _pdf = await _reports.download(queued.id);

      _pdfLabel = '${_type.label} · ${_parameterSummary()}';
      _fileName = _type == ReportType.monthlyWorkHours
          ? 'monthly-work-hours-$_year-${_month.toString().padLeft(2, '0')}.pdf'
          : 'transport-loads.pdf';
    } on ApiClientException catch (error) {
      _errorMessage = error.message;
    } catch (error) {
      _errorMessage = 'The report could not be generated: $error';
    }

    try {
      // Best-effort: a row is written whether the run succeeded or failed, so
      // the list is refreshed either way, but a failure to refresh it must not
      // overwrite the result already recorded above.
      await _fetchRecent();
    } catch (_) {
      // Ignored - see the comment above.
    }

    _generating = false;
    notifyListeners();
  }

  /// Re-opens a past report in the preview. Most are already "Completed" and
  /// download immediately; one still queued or mid-render is waited on the
  /// same way [generate] waits on a fresh one.
  Future<void> openRecent(RecentReport report) async {
    _generating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (report.status != ReportRunStatus.completed) {
        await _reports.awaitCompletion(report.id);
      }

      _pdf = await _reports.download(report.id);
      _pdfLabel = '${report.title} · ${report.summary}';
      _fileName = 'report-${report.id}.pdf';
    } on ApiClientException catch (error) {
      _errorMessage = error.message;
    } catch (error) {
      _errorMessage = 'The report could not be downloaded: $error';
    }

    _generating = false;
    notifyListeners();
  }

  Future<void> _fetchRecent() async {
    final results = await Future.wait([
      _generatedReports.get(filter: {
        'page': 1,
        'pageSize': recentCount,
        'includeTotalCount': false,
        'sortBy': recentSortBy,
      }),
      _fetchRuns(),
    ]);

    final result = results[0] as PageResult<GeneratedReport>;
    final runs = results[1] as Map<int, ActivityLog>;

    _recent = [
      for (final report in result.items) _toRecent(report, runs[report.id]),
    ];
  }

  /// Who ran a report and when. `GeneratedReports` does not hold that any more —
  /// the ActivityLog entry pointing back at the report is the record of the run.
  Future<Map<int, ActivityLog>> _fetchRuns() async {
    final types = await _all(_activityLogTypes);

    final reportTypes = types.where(
      (type) => type.name.startsWith(reportLogTypePrefix),
    );

    final pages = await Future.wait([
      for (final type in reportTypes)
        _activityLogs.get(filter: {
          'activityLogTypeId': type.id,
          'page': 1,
          'pageSize': 100,
          'includeTotalCount': false,
          'sortBy': 'Date desc',
        }),
    ]);

    return {
      for (final page in pages)
        for (final log in page.items) ?log.generatedReportId: log,
    };
  }

  RecentReport _toRecent(GeneratedReport report, ActivityLog? run) => RecentReport(
        id: report.id,
        type: report.reportType,
        summary: _describe(report),
        generatedAt: run?.date,
        generatedByName: _userById[run?.userId]?.fullName ?? 'Unknown user',
        status: report.runStatus,
        errorMessage: report.errorMessage,
      );

  /// Reads the request the run was made with back out of its stored JSON.
  /// `JsonSerializer.Serialize` writes the property names as they are declared,
  /// so the keys arrive in PascalCase.
  String _describe(GeneratedReport report) {
    final Map<String, dynamic> parameters;
    try {
      parameters = jsonDecode(report.parameters) as Map<String, dynamic>;
    } catch (_) {
      return 'Parameters could not be read';
    }

    T? read<T>(String key) {
      for (final entry in parameters.entries) {
        if (entry.key.toLowerCase() == key.toLowerCase()) return entry.value as T?;
      }
      return null;
    }

    return switch (report.reportType) {
      ReportType.monthlyWorkHours => [
          if (read<int>('year') case final year?)
            periodLabel(DateTime(year, read<int>('month') ?? 1))
          else
            'Unknown period',
          _userById[read<int>('userId')]?.fullName ?? 'All workers',
          _projectById[read<int>('projectId')]?.name ?? 'All projects',
        ].join(' · '),
      ReportType.transportLoads => [
          _projectById[read<int>('projectId')]?.name ?? 'All projects',
          _rangeLabel(read<String>('dateFrom'), read<String>('dateTo')),
        ].join(' · '),
    };
  }

  static String _rangeLabel(String? from, String? to) {
    final start = from == null ? null : DateTime.tryParse(from);
    final end = to == null ? null : DateTime.tryParse(to);
    if (start == null && end == null) return 'All dates';

    final formatter = DateFormat('d MMM yyyy');
    if (start != null && end != null) {
      return '${formatter.format(start)} - ${formatter.format(end)}';
    }

    return start != null
        ? 'From ${formatter.format(start)}'
        : 'Until ${formatter.format(end!)}';
  }

  String _parameterSummary() => switch (_type) {
        ReportType.monthlyWorkHours => [
            periodLabel(period),
            _userById[_userId]?.fullName ?? 'All workers',
            _projectById[_projectId]?.name ?? 'All projects',
          ].join(' · '),
        ReportType.transportLoads => [
            _projectById[_projectId]?.name ?? 'All projects',
            _dateRange == null
                ? 'All dates'
                : _rangeLabel(
                    _dateRange!.start.toIso8601String(),
                    _dateRange!.end.toIso8601String(),
                  ),
          ].join(' · '),
      };

  /// The API compares `DateTo` against a timestamp, so a range has to run to the
  /// last second of its closing day rather than to midnight.
  static DateTime? _endOfDay(DateTime? date) => date == null
      ? null
      : DateUtils.dateOnly(date)
          .add(const Duration(days: 1) - const Duration(seconds: 1));

  Future<List<E>> _all<E>(BaseProvider<E> provider) => provider.getAll();
}
