import '../models/models.dart';
import '../utils/api_client_exception.dart';
import '../utils/sarajevo_time.dart';
import 'base_provider.dart';
import 'company_provider.dart';
import 'company_type_provider.dart';
import 'package:flutter/material.dart';
import 'project_provider.dart';
import 'project_status_type_provider.dart';
import 'truck_load_detail_provider.dart';
import 'truck_load_provider.dart';
import 'truck_load_status_type_provider.dart';


enum TransportsStatusState { idle, loading, ready, failed }

/// The screen's own store. Search, status, the date range and paging go to the
/// API as a `TruckLoadSearchObject`, so only one page of loads is ever in
/// memory; the carriers, statuses and projects are read whole to resolve the
/// names a load carries as ids and to fill the details form's dropdowns.
///
/// What is on a truck lives in `TruckLoadDetails` and the table does not show
/// it, so those lines are fetched per load by [linesOf] when a row is opened
/// rather than for the whole page.
class TransportsProvider extends ChangeNotifier {
  TransportsProvider({
    TruckLoadProvider? truckLoads,
    BaseProvider<TruckLoadDetail>? truckLoadDetails,
    BaseProvider<TruckLoadStatusType>? statusTypes,
    BaseProvider<Company>? companies,
    BaseProvider<CompanyType>? companyTypes,
    BaseProvider<Project>? projects,
    BaseProvider<ProjectStatusType>? projectStatusTypes,
  })  : _truckLoads = truckLoads ?? TruckLoadProvider(),
        _truckLoadDetails = truckLoadDetails ?? TruckLoadDetailProvider(),
        _statusTypes = statusTypes ?? TruckLoadStatusTypeProvider(),
        _companies = companies ?? CompanyProvider(),
        _companyTypes = companyTypes ?? CompanyTypeProvider(),
        _projects = projects ?? ProjectProvider(),
        _projectStatusTypes = projectStatusTypes ?? ProjectStatusTypeProvider();

  /// Rows per page of the table.
  static const int pageSize = 8;

  /// Most recent load first, ordered by the API.
  static const String sortBy = 'LoadDate desc';

  /// Companies of this type are the shop's customers, so they are not carriers.
  static const String customerType = 'Customer';

  /// Only a project actively being made is fit to load onto a truck - one still
  /// on hold, rejected, or already delivered has no business on the cargo list.
  static const String loadableProjectStatus = 'In production';

  final TruckLoadProvider _truckLoads;
  final BaseProvider<TruckLoadDetail> _truckLoadDetails;
  final BaseProvider<TruckLoadStatusType> _statusTypes;
  final BaseProvider<Company> _companies;
  final BaseProvider<CompanyType> _companyTypes;
  final BaseProvider<Project> _projects;
  final BaseProvider<ProjectStatusType> _projectStatusTypes;

  TransportsStatusState _status = TransportsStatusState.idle;
  String? _errorMessage;

  List<TransportRow> _rows = const [];
  List<TruckLoadStatusType> _statusList = const [];
  List<Company> _carrierList = const [];
  List<Project> _projectList = const [];
  Map<int, Company> _companyById = const {};
  Map<int, Project> _projectById = const {};

  int _matchCount = 0;

  String _search = '';
  int? _statusId;
  DateTimeRange? _dateRange;
  int _page = 1;

  TransportsStatusState get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == TransportsStatusState.loading;

  /// The page the table shows.
  List<TransportRow> get rows => _rows;

  List<TruckLoadStatusType> get statusTypes => _statusList;

  /// Who can carry a load out — every company that is not a customer.
  List<Company> get carriers => _carrierList;

  /// What can be loaded onto a truck.
  List<Project> get projects => _projectList;

  String get search => _search;
  int? get statusId => _statusId;
  DateTimeRange? get dateRange => _dateRange;
  int get page => _page;

  bool get hasFilters =>
      _search.isNotEmpty || _statusId != null || _dateRange != null;

  /// How many loads the current filters match, across every page.
  int get matchCount => _matchCount;

  int get pageCount => (_matchCount / pageSize).ceil().clamp(1, 999);

  Future<void> setSearch(String value) {
    _search = value;
    _page = 1;
    return _loadPage();
  }

  Future<void> setStatus(int? id) {
    _statusId = id;
    _page = 1;
    return _loadPage();
  }

  Future<void> setDateRange(DateTimeRange? range) {
    _dateRange = range;
    _page = 1;
    return _loadPage();
  }

  Future<void> setPage(int value) {
    _page = value.clamp(1, pageCount);
    return _loadPage();
  }

  Future<void> clearFilters() {
    _search = '';
    _statusId = null;
    _dateRange = null;
    _page = 1;
    return _loadPage();
  }

  /// Lookups and the first page. The lookups only change when the reference
  /// data does, so a write afterwards goes through [refresh].
  Future<void> load() async {
    _status = TransportsStatusState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final lookups = await Future.wait([
        _all(_statusTypes),
        _all(_companies),
        _all(_companyTypes),
        _all(_projects),
        _all(_projectStatusTypes),
      ]);

      final statuses = lookups[0] as List<TruckLoadStatusType>;
      final companies = lookups[1] as List<Company>;
      final companyTypes = lookups[2] as List<CompanyType>;
      final projects = lookups[3] as List<Project>;
      final projectStatuses = lookups[4] as List<ProjectStatusType>;

      _statusList = statuses;
      _companyById = {for (final company in companies) company.id: company};
      // Every project, regardless of status - a load already carrying one that
      // has since moved on (finished, put on hold) still needs its name.
      _projectById = {for (final project in projects) project.id: project};

      final customerTypeId = companyTypes
          .where((type) => type.name.toLowerCase() == customerType.toLowerCase())
          .map((type) => type.id)
          .firstOrNull;
      _carrierList = companies
          .where((company) =>
              customerTypeId == null || company.companyTypeId != customerTypeId)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      final loadableStatusId = projectStatuses
          .where((status) => status.name.toLowerCase() == loadableProjectStatus.toLowerCase())
          .map((status) => status.id)
          .firstOrNull;
      _projectList = projects
          .where((project) =>
              loadableStatusId == null || project.projectStatusId == loadableStatusId)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      await _fetchPage();

      _status = TransportsStatusState.ready;
    } on ApiClientException catch (error) {
      _errorMessage = error.message;
      _status = TransportsStatusState.failed;
    } catch (error) {
      _errorMessage = 'Something went wrong while loading transports: $error';
      _status = TransportsStatusState.failed;
    }

    notifyListeners();
  }

  /// What a details screen asks for after saving: the page again, without
  /// re-reading the reference data.
  Future<void> refresh() => _loadPage();

  Future<void> _loadPage() async {
    try {
      await _fetchPage();
      _status = TransportsStatusState.ready;
    } on ApiClientException catch (error) {
      _errorMessage = error.message;
      _status = TransportsStatusState.failed;
    } catch (error) {
      _errorMessage = 'Something went wrong while loading transports: $error';
      _status = TransportsStatusState.failed;
    }

    notifyListeners();
  }

  /// The search object the table's filters add up to. `DateTo` is compared
  /// against a `LoadDate` that carries a time of day, so the range runs to the
  /// last second of its closing day rather than to midnight.
  Map<String, dynamic> get filter => {
        'page': _page,
        'pageSize': pageSize,
        'includeTotalCount': true,
        'sortBy': sortBy,
        if (_search.trim().isNotEmpty) 'search': _search.trim(),
        if (_statusId != null) 'truckLoadStatusId': _statusId,
        if (_dateRange != null) ...{
          'dateFrom': SarajevoTime.toApi(DateUtils.dateOnly(_dateRange!.start)),
          'dateTo': SarajevoTime.toApi(DateUtils.dateOnly(_dateRange!.end)
              .add(const Duration(days: 1) - const Duration(seconds: 1))),
        },
      };

  Future<void> _fetchPage() async {
    final result = await _truckLoads.get(filter: filter);

    _matchCount = result.totalCount ?? result.items.length;
    // A delete can empty the last page; step back rather than show nothing.
    if (result.items.isEmpty && _page > 1 && _matchCount > 0) {
      _page = pageCount;
      return _fetchPage();
    }

    _rows = _buildRows(result.items);
  }

  /// A whole lookup table, paged through by [BaseProvider.getAll] because the
  /// API caps how many rows one request may return.
  Future<List<E>> _all<E>(BaseProvider<E> provider) => provider.getAll();

  /// Every row matching the search box, status filter and date range - not
  /// just the page [rows] holds. The transports table's own column sort and
  /// filter (an Excel-style AutoFilter) need the whole matching set to sort
  /// and check values against, not one page of eight.
  Future<List<TransportRow>> loadAllRows() async {
    final loads = await _truckLoads.getAll(filter: {
      'sortBy': sortBy,
      if (_search.trim().isNotEmpty) 'search': _search.trim(),
      if (_statusId != null) 'truckLoadStatusId': _statusId,
      if (_dateRange != null) ...{
        'dateFrom': SarajevoTime.toApi(DateUtils.dateOnly(_dateRange!.start)),
        'dateTo': SarajevoTime.toApi(DateUtils.dateOnly(_dateRange!.end)
            .add(const Duration(days: 1) - const Duration(seconds: 1))),
      },
    });
    return _buildRows(loads);
  }

  List<TransportRow> _buildRows(List<TruckLoad> loads) {
    final statusById = {for (final status in _statusList) status.id: status};

    return loads
        .map((load) => TransportRow(
              id: load.id,
              carrierId: load.transportCompanyId,
              carrierName:
                  _companyById[load.transportCompanyId]?.name ?? 'Unknown carrier',
              statusId: load.truckLoadStatusId,
              statusName: statusById[load.truckLoadStatusId]?.name ?? 'Unknown',
              loadDate: load.loadDate,
              driverName: load.driverName,
              driverSurname: load.driverSurname,
              vehicleRegistration: load.vehicleRegistration,
              emptyWeight: load.emptyWeight,
              fullWeight: load.fullWeight,
              note: load.note,
              price: load.price,
            ))
        .toList();
  }

  /// Re-reads one load after its edit form - or a status change - has
  /// written, joined the same way [rows] is, so the overview screen showing
  /// it can refresh in place rather than falling back to the table's own page.
  Future<TransportRow> fetchRow(int id) async {
    final load = await _truckLoads.getById(id);
    return _buildRows([load]).single;
  }

  /// `PATCH /TruckLoad/{id}/Status` - the only way a load's status ever
  /// changes. [price] is the invoice amount in EUR, asked for by the popup
  /// the "Finished" transition opens; the API refuses that jump without it.
  Future<void> changeStatus(int id, int newStatusId, {double? price}) =>
      _truckLoads.changeStatus(id, newStatusId, price: price);

  /// The audit trail behind one load's status, newest first.
  Future<List<TruckLoadStatusChangeEntry>> statusHistory(int id) =>
      _truckLoads.statusHistory(id);

  /// What is on one truck, in the order it comes off. Fetched when a row is
  /// opened, because the table does not show cargo and a page of eight loads
  /// would otherwise cost eight more requests.
  Future<List<TransportLine>> linesOf(int truckLoadId) async {
    final details =
        await _truckLoadDetails.getAll(filter: {'truckLoadId': truckLoadId});

    return details
        .map((detail) => TransportLine(
              id: detail.id,
              projectId: detail.projectId,
              projectName: _projectById[detail.projectId]?.name ?? 'Unknown project',
              brutoWeight: detail.brutoWeight,
              netoWeight: detail.netoWeight,
              unloadPriority: detail.unloadPriority,
              unloadColor: detail.unloadColor,
            ))
        .toList()
      ..sort((a, b) => a.unloadPriority.compareTo(b.unloadPriority));
  }

  /// Inserts when [id] is null and updates otherwise — the details screen uses
  /// the same form for both. Cargo lives in its own table, so the lines are
  /// diffed against [originalLines]: what is new gets inserted, what is gone
  /// gets deleted, and the rest is put back.
  ///
  /// Carries no status: a load always starts "Ordered" and only ever moves
  /// on, or has its cargo changed, through [changeStatus] - see the API's own
  /// `TruckLoadInsertRequest` for why this request cannot express either.
  /// [price] is only ever honoured by the API while "Delivered"; sent
  /// unconditionally here the same way `phoneNumber` is elsewhere, so an
  /// unrelated edit does not accidentally blank out an amount already entered.
  Future<void> saveTransport({
    int? id,
    required int transportCompanyId,
    required DateTime loadDate,
    required String driverName,
    required String driverSurname,
    required String vehicleRegistration,
    required double emptyWeight,
    required double fullWeight,
    String? note,
    double? price,
    List<TransportLine> lines = const [],
    List<TransportLine> originalLines = const [],
  }) async {
    final body = {
      'transportCompanyId': transportCompanyId,
      'loadDate': SarajevoTime.toApi(loadDate),
      'driverName': driverName,
      'driverSurname': driverSurname,
      'vehicleRegistration': vehicleRegistration,
      'emptyWeight': emptyWeight,
      'fullWeight': fullWeight,
      'note': note,
      'price': price,
    };

    // On insert the id comes back from the API; on update it is the one we sent.
    final int loadId;
    if (id == null) {
      loadId = (await _truckLoads.insert(body)).id;
    } else {
      await _truckLoads.update(id, body);
      loadId = id;
    }

    await _saveLines(loadId, lines, originalLines);
  }

  Future<void> _saveLines(
    int truckLoadId,
    List<TransportLine> lines,
    List<TransportLine> originalLines,
  ) async {
    final kept = lines.where((line) => !line.isNew).map((line) => line.id).toSet();

    await Future.wait(
      originalLines
          .where((line) => !kept.contains(line.id))
          .map((line) => _truckLoadDetails.remove(line.id)),
    );

    await Future.wait(lines.map((line) {
      final body = {
        'truckLoadId': truckLoadId,
        'projectId': line.projectId,
        'brutoWeight': line.brutoWeight,
        'netoWeight': line.netoWeight,
        'unloadPriority': line.unloadPriority,
        'unloadColor': line.unloadColor,
      };

      return line.isNew
          ? _truckLoadDetails.insert(body)
          : _truckLoadDetails.update(line.id, body);
    }));
  }

  /// The cargo goes with the truck: `TruckLoadDetails` cascades from
  /// `TruckLoads`, so the database drops the lines itself.
  Future<void> deleteTransport(int id) => _truckLoads.remove(id);
}
