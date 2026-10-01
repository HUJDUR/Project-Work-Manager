import 'package:material_ui/material_ui.dart';

import '../models/models.dart';
import '../utils/api_client_exception.dart';
import 'activity_log_provider.dart';
import 'activity_log_type_provider.dart';
import 'base_provider.dart';
import 'user_provider.dart';

enum ActivitiesStatusState { idle, loading, ready, failed }

/// Every recorded sign-in, sign-out, message and report run, across every
/// account — admin-only, both here (see `AppRoles`) and on the API (see
/// `ActivityLogController`). The log grows with every sign-in, so the API
/// filters, sorts and pages it; this holds one page at a time.
class ActivitiesProvider extends ChangeNotifier {
  ActivitiesProvider({
    BaseProvider<ActivityLog>? activityLogs,
    BaseProvider<ActivityLogType>? activityLogTypes,
    BaseProvider<User>? users,
  })  : _activityLogs = activityLogs ?? ActivityLogProvider(),
        _activityLogTypes = activityLogTypes ?? ActivityLogTypeProvider(),
        _users = users ?? UserProvider();

  static const int pageSize = 8;

  final BaseProvider<ActivityLog> _activityLogs;
  final BaseProvider<ActivityLogType> _activityLogTypes;
  final BaseProvider<User> _users;

  ActivitiesStatusState _status = ActivitiesStatusState.idle;
  String? _errorMessage;

  List<User> _userList = const [];
  List<ActivityLogType> _typeList = const [];

  List<ActivityRow> _rows = const [];
  int _totalCount = 0;
  int _page = 1;

  /// Bumped per request, so an older answer arriving after a newer one
  /// (filters changed quickly) is dropped instead of overwriting it.
  int _request = 0;

  String _search = '';
  int? _typeId;
  DateTimeRange? _dateRange;

  /// A key `GET /ActivityLog` sorts by - newest first to start.
  String _sortKey = 'Date';
  bool _sortAscending = false;

  ActivitiesStatusState get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == ActivitiesStatusState.loading;

  List<ActivityLogType> get activityTypes => _typeList;

  /// The page on screen.
  List<ActivityRow> get rows => _rows;
  int get page => _page;
  int get pageCount => _totalCount == 0 ? 1 : (_totalCount / pageSize).ceil();

  String get search => _search;
  int? get activityTypeId => _typeId;
  DateTimeRange? get dateRange => _dateRange;
  String get sortKey => _sortKey;
  bool get sortAscending => _sortAscending;

  bool get hasFilters => _search.isNotEmpty || _typeId != null || _dateRange != null;

  Future<void> load() async {
    _status = ActivitiesStatusState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final lookups = await Future.wait([_users.getAll(), _activityLogTypes.getAll()]);

      _userList = lookups[0] as List<User>;
      _typeList = [...lookups[1] as List<ActivityLogType>]
        ..sort((a, b) => a.name.compareTo(b.name));

      await _fetch();
      _status = ActivitiesStatusState.ready;
    } on ApiClientException catch (error) {
      _errorMessage = error.message;
      _status = ActivitiesStatusState.failed;
    } catch (error) {
      _errorMessage = 'Something went wrong while loading activities: $error';
      _status = ActivitiesStatusState.failed;
    }

    notifyListeners();
  }

  Future<void> setSearch(String value) {
    _search = value.trim();
    return _reloadFirstPage();
  }

  Future<void> setActivityType(int? id) {
    _typeId = id;
    return _reloadFirstPage();
  }

  Future<void> setDateRange(DateTimeRange? range) {
    _dateRange = range;
    return _reloadFirstPage();
  }

  Future<void> clearFilters() {
    _search = '';
    _typeId = null;
    _dateRange = null;
    return _reloadFirstPage();
  }

  /// The same column again flips the direction; a new one starts ascending.
  Future<void> setSort(String key) {
    _sortAscending = key == _sortKey ? !_sortAscending : true;
    _sortKey = key;
    return _reloadFirstPage();
  }

  Future<void> setPage(int value) {
    _page = value;
    return _reload();
  }

  Future<void> _reloadFirstPage() {
    _page = 1;
    return _reload();
  }

  Future<void> _reload() async {
    final request = ++_request;
    notifyListeners();

    try {
      await _fetch(request: request);
      if (request != _request) return;
      _errorMessage = null;
      _status = ActivitiesStatusState.ready;
    } on ApiClientException catch (error) {
      if (request != _request) return;
      _errorMessage = error.message;
      _status = ActivitiesStatusState.failed;
    } catch (error) {
      if (request != _request) return;
      _errorMessage = 'Something went wrong while loading activities: $error';
      _status = ActivitiesStatusState.failed;
    }

    notifyListeners();
  }

  Future<void> _fetch({int? request}) async {
    final range = _dateRange;

    final result = await _activityLogs.get(filter: {
      'page': _page,
      'pageSize': pageSize,
      'includeTotalCount': true,
      'sortBy': _sortAscending ? _sortKey : '$_sortKey desc',
      if (_search.isNotEmpty) 'search': _search,
      'activityLogTypeId': ?_typeId,
      if (range != null) 'dateFrom': DateUtils.dateOnly(range.start),
      // The last day whole, up to its final millisecond.
      if (range != null)
        'dateTo': DateUtils.dateOnly(range.end)
            .add(const Duration(days: 1))
            .subtract(const Duration(milliseconds: 1)),
    });

    if (request != null && request != _request) return;
    _rows = _buildRows(result.items);
    _totalCount = result.totalCount ?? result.items.length;
  }

  List<ActivityRow> _buildRows(List<ActivityLog> logs) {
    final userById = {for (final user in _userList) user.id: user};
    final typeById = {for (final type in _typeList) type.id: type};

    return logs.map((log) {
      final user = userById[log.userId];

      return ActivityRow(
        id: log.id,
        userId: log.userId,
        userName: user?.fullName ?? 'Unknown user',
        userInitials: user?.initials ?? '?',
        activityLogTypeId: log.activityLogTypeId,
        activityTypeName: typeById[log.activityLogTypeId]?.name ?? 'Unknown activity',
        date: log.date,
      );
    }).toList();
  }
}
