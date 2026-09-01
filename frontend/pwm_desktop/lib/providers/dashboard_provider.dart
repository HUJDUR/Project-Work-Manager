import 'package:flutter/material.dart';

import '../models/models.dart';
import '../utils/api_client_exception.dart';
import '../utils/formatters.dart';
import 'activity_log_provider.dart';
import 'activity_log_type_provider.dart';
import 'base_provider.dart';
import 'company_provider.dart';
import 'operation_type_provider.dart';
import 'project_provider.dart';
import 'project_status_type_provider.dart';
import 'truck_load_provider.dart';
import 'user_provider.dart';
import 'user_type_provider.dart';
import 'work_log_detail_provider.dart';
import 'work_log_provider.dart';

enum DashboardStatus { idle, loading, ready, failed }

/// The API returns raw foreign keys and has no aggregate endpoints, so every
/// join and sum happens here — the seam a server-side `/Dashboard` would take
/// over if the data outgrows seed scale.
class DashboardProvider extends ChangeNotifier {
  DashboardProvider({
    BaseProvider<Project>? projects,
    BaseProvider<User>? users,
    BaseProvider<Company>? companies,
    BaseProvider<WorkLog>? workLogs,
    BaseProvider<WorkLogDetail>? workLogDetails,
    BaseProvider<TruckLoad>? truckLoads,
    BaseProvider<ActivityLog>? activityLogs,
    BaseProvider<ProjectStatusType>? projectStatusTypes,
    BaseProvider<OperationType>? operationTypes,
    BaseProvider<ActivityLogType>? activityLogTypes,
    BaseProvider<UserType>? userTypes,
  })  : _projects = projects ?? ProjectProvider(),
        _users = users ?? UserProvider(),
        _companies = companies ?? CompanyProvider(),
        _workLogs = workLogs ?? WorkLogProvider(),
        _workLogDetails = workLogDetails ?? WorkLogDetailProvider(),
        _truckLoads = truckLoads ?? TruckLoadProvider(),
        _activityLogs = activityLogs ?? ActivityLogProvider(),
        _projectStatusTypes = projectStatusTypes ?? ProjectStatusTypeProvider(),
        _operationTypes = operationTypes ?? OperationTypeProvider(),
        _activityLogTypes = activityLogTypes ?? ActivityLogTypeProvider(),
        _userTypes = userTypes ?? UserTypeProvider();

  static const int windowDays = 30;
  static const int _listLength = 5;
  static const int _projectsInChart = 6;
  static const int _operationsInChart = 6;

  final BaseProvider<Project> _projects;
  final BaseProvider<User> _users;
  final BaseProvider<Company> _companies;
  final BaseProvider<WorkLog> _workLogs;
  final BaseProvider<WorkLogDetail> _workLogDetails;
  final BaseProvider<TruckLoad> _truckLoads;
  final BaseProvider<ActivityLog> _activityLogs;
  final BaseProvider<ProjectStatusType> _projectStatusTypes;
  final BaseProvider<OperationType> _operationTypes;
  final BaseProvider<ActivityLogType> _activityLogTypes;
  final BaseProvider<UserType> _userTypes;

  DashboardStatus _status = DashboardStatus.idle;
  DashboardData? _data;
  String? _errorMessage;

  DashboardStatus get status => _status;
  DashboardData? get data => _data;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == DashboardStatus.loading;

  Future<void> load() async {
    _status = DashboardStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final windowStart = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: windowDays));

      final results = await Future.wait([
        _rows(_projects),
        _rows(_users),
        _rows(_companies),
        _rows(_workLogs),
        _rows(_workLogDetails),
        _rows(_truckLoads),
        _rows(_activityLogs),
        _rows(_projectStatusTypes),
        _rows(_operationTypes),
        _rows(_activityLogTypes),
        _rows(_userTypes),
      ]);

      _data = _aggregate(
        projects: results[0] as List<Project>,
        users: results[1] as List<User>,
        companies: results[2] as List<Company>,
        workLogs: results[3] as List<WorkLog>,
        workLogDetails: results[4] as List<WorkLogDetail>,
        truckLoads: results[5] as List<TruckLoad>,
        activityLogs: results[6] as List<ActivityLog>,
        statuses: results[7] as List<ProjectStatusType>,
        operations: results[8] as List<OperationType>,
        activityTypes: results[9] as List<ActivityLogType>,
        userTypes: results[10] as List<UserType>,
        windowStart: windowStart,
      );

      _status = DashboardStatus.ready;
    } on ApiClientException catch (error) {
      _errorMessage = error.message;
      _status = DashboardStatus.failed;
    } catch (error) {
      _errorMessage = 'Something went wrong while loading the dashboard: $error';
      _status = DashboardStatus.failed;
    }

    notifyListeners();
  }

  /// A whole lookup table, paged through by [BaseProvider.getAll] because the
  /// API caps how many rows one request may return.
  Future<List<E>> _rows<E>(BaseProvider<E> provider) => provider.getAll();

  DashboardData _aggregate({
    required List<Project> projects,
    required List<User> users,
    required List<Company> companies,
    required List<WorkLog> workLogs,
    required List<WorkLogDetail> workLogDetails,
    required List<TruckLoad> truckLoads,
    required List<ActivityLog> activityLogs,
    required List<ProjectStatusType> statuses,
    required List<OperationType> operations,
    required List<ActivityLogType> activityTypes,
    required List<UserType> userTypes,
    required DateTime windowStart,
  }) {
    final projectById = {for (final project in projects) project.id: project};
    final userById = {for (final user in users) user.id: user};
    final companyById = {for (final company in companies) company.id: company};
    final workLogById = {for (final log in workLogs) log.id: log};
    final statusById = {for (final status in statuses) status.id: status.name};
    final operationById = {
      for (final operation in operations) operation.id: operation.name
    };
    final activityTypeById = {for (final type in activityTypes) type.id: type.name};

    final workerTypeId = userTypes
        .where((type) => type.type.toLowerCase() == 'worker')
        .map((type) => type.id)
        .firstOrNull;

    const closedStatuses = {'delivered', 'cancelled'};
    final activeProjects = projects.where((project) {
      final status = (statusById[project.projectStatusId] ?? '').toLowerCase();
      return !closedStatuses.contains(status);
    }).toList();

    final inProduction = projects.where((project) {
      final status = (statusById[project.projectStatusId] ?? '').toLowerCase();
      return status == 'in production';
    }).length;

    final recentDetails = workLogDetails
        .where((detail) => detail.startedAt.isAfter(windowStart))
        .toList();
    final hoursInWindow =
        recentDetails.fold<double>(0, (sum, detail) => sum + detail.hours);

    final activeWorkers = users
        .where((user) =>
            user.isActive && (workerTypeId == null || user.userTypeId == workerTypeId))
        .length;
    final workersWithBookings = recentDetails
        .map((detail) => workLogById[detail.workLogId]?.userId)
        .whereType<int>()
        .toSet()
        .length;

    final recentLoads =
        truckLoads.where((load) => load.loadDate.isAfter(windowStart)).toList();
    final shippedWeight =
        recentLoads.fold<double>(0, (sum, load) => sum + load.netWeight);

    final metrics = <SummaryMetric>[
      SummaryMetric(
        icon: Icons.schedule_outlined,
        label: 'Hours logged',
        value: formatHours(hoursInWindow),
        caption: 'last $windowDays days',
      ),
      SummaryMetric(
        icon: Icons.folder_outlined,
        label: 'Active projects',
        value: formatCount(activeProjects.length),
        caption: '$inProduction in production',
      ),
      SummaryMetric(
        icon: Icons.groups_outlined,
        label: 'Workers',
        value: formatCount(activeWorkers),
        caption: '$workersWithBookings booked hours',
      ),
      SummaryMetric(
        icon: Icons.local_shipping_outlined,
        label: 'Transports',
        value: formatCount(recentLoads.length),
        caption: 'last $windowDays days',
      ),
      SummaryMetric(
        icon: Icons.scale_outlined,
        label: 'Shipped weight',
        value: formatTonnes(shippedWeight),
        caption: 'last $windowDays days',
      ),
    ];

    return DashboardData(
      metrics: metrics,
      hoursByProject: _topSlices(
        _sumHours(recentDetails, (detail) => projectById[detail.projectId]?.name),
        _projectsInChart,
      ),
      hoursByOperation: _topSlicesWithRemainder(
        _sumHours(recentDetails, (detail) => operationById[detail.operationTypeId]),
        _operationsInChart,
      ),
      recentWork: _buildWorkEntries(
          workLogDetails, workLogById, userById, projectById, operationById),
      recentTransports: _buildTransportEntries(truckLoads, companyById),
      recentActivity: _buildActivityEntries(activityLogs, userById, activityTypeById),
      windowDays: windowDays,
    );
  }

  Map<String, double> _sumHours(
    List<WorkLogDetail> details,
    String? Function(WorkLogDetail) keyOf,
  ) {
    final totals = <String, double>{};

    for (final detail in details) {
      final key = keyOf(detail);
      if (key == null || key.isEmpty) continue;
      totals[key] = (totals[key] ?? 0) + detail.hours;
    }

    return totals;
  }

  List<ChartSlice> _topSlices(Map<String, double> totals, int limit) {
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries
        .take(limit)
        .map((entry) => ChartSlice(label: entry.key, value: entry.value))
        .toList();
  }

  List<ChartSlice> _topSlicesWithRemainder(Map<String, double> totals, int limit) {
    final ranked = _topSlices(totals, totals.length);
    if (ranked.length <= limit + 1) return ranked;

    final remainder = ranked
        .skip(limit)
        .fold<double>(0, (sum, slice) => sum + slice.value);

    return [
      ...ranked.take(limit),
      ChartSlice(label: 'Other', value: remainder),
    ];
  }

  List<WorkEntry> _buildWorkEntries(
    List<WorkLogDetail> details,
    Map<int, WorkLog> workLogById,
    Map<int, User> userById,
    Map<int, Project> projectById,
    Map<int, String> operationById,
  ) {
    final sorted = [...details]..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    return sorted.take(_listLength).map((detail) {
      final worker = userById[workLogById[detail.workLogId]?.userId];

      return WorkEntry(
        workerName: worker?.fullName ?? 'Unknown worker',
        workerInitials: worker?.initials ?? '?',
        projectName: projectById[detail.projectId]?.name ?? 'Unknown project',
        operationName: operationById[detail.operationTypeId] ?? 'Unknown operation',
        hours: detail.hours,
        startedAt: detail.startedAt,
      );
    }).toList();
  }

  List<TransportEntry> _buildTransportEntries(
    List<TruckLoad> loads,
    Map<int, Company> companyById,
  ) {
    final sorted = [...loads]..sort((a, b) => b.loadDate.compareTo(a.loadDate));

    return sorted
        .take(_listLength)
        .map((load) => TransportEntry(
              driverName: load.driverFullName,
              vehicleRegistration: load.vehicleRegistration,
              carrierName: companyById[load.transportCompanyId]?.name ?? 'Unknown carrier',
              loadDate: load.loadDate,
              netWeight: load.netWeight,
            ))
        .toList();
  }

  List<ActivityEntry> _buildActivityEntries(
    List<ActivityLog> logs,
    Map<int, User> userById,
    Map<int, String> activityTypeById,
  ) {
    final sorted = [...logs]..sort((a, b) => b.date.compareTo(a.date));

    return sorted
        .take(_listLength)
        .map((log) => ActivityEntry(
              title: activityTypeById[log.activityLogTypeId] ?? 'Activity',
              actorName: userById[log.userId]?.fullName ?? 'Unknown user',
              date: log.date,
            ))
        .toList();
  }
}
