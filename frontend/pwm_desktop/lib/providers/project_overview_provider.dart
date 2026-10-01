import 'package:material_ui/material_ui.dart';

import '../models/models.dart';
import '../utils/api_client_exception.dart';
import 'base_provider.dart';
import 'company_provider.dart';
import 'operation_type_provider.dart';
import 'project_provider.dart';
import 'truck_load_detail_provider.dart';
import 'truck_load_provider.dart';
import 'truck_load_status_type_provider.dart';
import 'user_provider.dart';
import 'work_log_detail_provider.dart';

enum ProjectOverviewStatusState { idle, loading, ready, failed }

/// Everything the read-only Project Details page shows beyond the project row
/// itself, laid out as in `docs/mockups/desktop/Project details.png`: who has
/// booked work against it, what that adds up to per operation, and which
/// truck loads carry it. The project row itself is read once by the caller,
/// which already has it - this only fetches what is scoped to [projectId].
class ProjectOverviewProvider extends ChangeNotifier {
  ProjectOverviewProvider({
    required this.projectId,
    ProjectProvider? projects,
    BaseProvider<WorkLogDetail>? workLogDetails,
    BaseProvider<User>? users,
    BaseProvider<OperationType>? operationTypes,
    BaseProvider<TruckLoadDetail>? truckLoadDetails,
    BaseProvider<TruckLoad>? truckLoads,
    BaseProvider<Company>? companies,
    BaseProvider<TruckLoadStatusType>? truckLoadStatusTypes,
  })  : _projects = projects ?? ProjectProvider(),
        _workLogDetails = workLogDetails ?? WorkLogDetailProvider(),
        _users = users ?? UserProvider(),
        _operationTypes = operationTypes ?? OperationTypeProvider(),
        _truckLoadDetails = truckLoadDetails ?? TruckLoadDetailProvider(),
        _truckLoads = truckLoads ?? TruckLoadProvider(),
        _companies = companies ?? CompanyProvider(),
        _truckLoadStatusTypes = truckLoadStatusTypes ?? TruckLoadStatusTypeProvider();

  final int projectId;

  final ProjectProvider _projects;
  final BaseProvider<WorkLogDetail> _workLogDetails;
  final BaseProvider<User> _users;
  final BaseProvider<OperationType> _operationTypes;
  final BaseProvider<TruckLoadDetail> _truckLoadDetails;
  final BaseProvider<TruckLoad> _truckLoads;
  final BaseProvider<Company> _companies;
  final BaseProvider<TruckLoadStatusType> _truckLoadStatusTypes;

  ProjectOverviewStatusState _status = ProjectOverviewStatusState.idle;
  String? _errorMessage;
  List<ProjectWorkEntry> _workEntries = const [];
  List<ProjectTransportEntry> _transportEntries = const [];
  List<ProjectStatusChangeEntry> _statusHistory = const [];

  bool _changingStatus = false;
  String? _statusChangeError;

  ProjectOverviewStatusState get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == ProjectOverviewStatusState.loading;

  /// Newest first.
  List<ProjectWorkEntry> get workEntries => _workEntries;
  List<ProjectTransportEntry> get transportEntries => _transportEntries;

  /// The project's status history, newest first - the audit trail behind
  /// its life cycle.
  List<ProjectStatusChangeEntry> get statusHistory => _statusHistory;

  bool get isChangingStatus => _changingStatus;
  String? get statusChangeError => _statusChangeError;

  /// Every hour in [workEntries], added up per operation and sorted by that
  /// total - the busiest operation on this project first.
  List<ProjectOperationSummary> get operationSummary {
    final totals = <String, double>{};
    for (final entry in _workEntries) {
      totals[entry.operationName] = (totals[entry.operationName] ?? 0) + entry.hours;
    }

    return totals.entries
        .map((entry) =>
            ProjectOperationSummary(operationName: entry.key, totalHours: entry.value))
        .toList()
      ..sort((a, b) => b.totalHours.compareTo(a.totalHours));
  }

  Future<void> load() async {
    _status = ProjectOverviewStatusState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _workLogDetails.getAll(filter: {'projectId': projectId}),
        _users.getAll(),
        _operationTypes.getAll(),
        _truckLoadDetails.getAll(filter: {'projectId': projectId}),
        _companies.getAll(),
        _truckLoadStatusTypes.getAll(),
        _projects.statusHistory(projectId),
      ]);

      final details = results[0] as List<WorkLogDetail>;
      final users = results[1] as List<User>;
      final operations = results[2] as List<OperationType>;
      final lines = results[3] as List<TruckLoadDetail>;
      final companies = results[4] as List<Company>;
      final statuses = results[5] as List<TruckLoadStatusType>;
      _statusHistory = results[6] as List<ProjectStatusChangeEntry>;

      final userById = {for (final user in users) user.id: user};
      final operationById = {for (final operation in operations) operation.id: operation};
      final companyById = {for (final company in companies) company.id: company};
      final statusById = {for (final status in statuses) status.id: status};

      _workEntries = details
          .map((detail) => ProjectWorkEntry(
                id: detail.id,
                workerName: userById[detail.userId]?.fullName ?? 'Unknown worker',
                operationName:
                    operationById[detail.operationTypeId]?.name ?? 'Unknown operation',
                date: detail.startedAt,
                hours: detail.hours,
              ))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      // The lines only carry a truckLoadId; the load itself (date, carrier,
      // status) is fetched one at a time rather than through `getAll` - a
      // project only ever sits on a handful of loads, nowhere near the whole
      // table.
      final truckLoadIds = lines.map((line) => line.truckLoadId).toSet();
      final truckLoads = await Future.wait(truckLoadIds.map(_truckLoads.getById));
      final truckLoadById = {for (final load in truckLoads) load.id: load};

      _transportEntries = lines
          .map((line) {
            final load = truckLoadById[line.truckLoadId];
            if (load == null) return null;

            return ProjectTransportEntry(
              id: line.id,
              truckLoadId: line.truckLoadId,
              loadDate: load.loadDate,
              carrierName: companyById[load.transportCompanyId]?.name ?? 'Unknown carrier',
              weight: line.netoWeight,
              statusName: statusById[load.truckLoadStatusId]?.name ?? 'Unknown',
            );
          })
          .whereType<ProjectTransportEntry>()
          .toList()
        ..sort((a, b) => b.loadDate.compareTo(a.loadDate));

      _status = ProjectOverviewStatusState.ready;
    } on ApiClientException catch (error) {
      _errorMessage = error.message;
      _status = ProjectOverviewStatusState.failed;
    } catch (error) {
      _errorMessage = 'Something went wrong while loading the project: $error';
      _status = ProjectOverviewStatusState.failed;
    }

    notifyListeners();
  }

  /// Moves the project to [newStatusId] and refreshes the history underneath
  /// it. The row itself (name, customer, the joined `statusName`...) is the
  /// caller's - `ProjectOverviewScreen` re-reads it through `ProjectsProvider`
  /// the same way it already does after the edit form writes.
  Future<bool> changeStatus(int newStatusId, {String? reason}) async {
    _changingStatus = true;
    _statusChangeError = null;
    notifyListeners();

    var succeeded = false;

    try {
      await _projects.changeStatus(projectId, newStatusId, reason: reason);
      _statusHistory = await _projects.statusHistory(projectId);
      succeeded = true;
    } on ApiClientException catch (error) {
      _statusChangeError = error.message;
    } catch (error) {
      _statusChangeError = 'The status could not be changed: $error';
    }

    _changingStatus = false;
    notifyListeners();

    return succeeded;
  }
}
