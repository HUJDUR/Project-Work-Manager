import 'package:flutter/material.dart';

import '../models/models.dart';
import '../utils/api_client_exception.dart';
import 'activity_log_provider.dart';
import 'activity_log_type_provider.dart';
import 'base_provider.dart';
import 'user_provider.dart';

enum ActivitiesStatusState { idle, loading, ready, failed }

/// Every recorded sign-in, sign-out, message and report run, across every
/// account — admin-only, both here (see `AppRoles`) and on the API (see
/// `ActivityLogController`). The whole log is read at once, the same as the
/// Workers and Projects tables, for their own Excel-style column sort and
/// filter — which is filter enough that this does not also offer its own.
class ActivitiesProvider extends ChangeNotifier {
  ActivitiesProvider({
    BaseProvider<ActivityLog>? activityLogs,
    BaseProvider<ActivityLogType>? activityLogTypes,
    BaseProvider<User>? users,
  })  : _activityLogs = activityLogs ?? ActivityLogProvider(),
        _activityLogTypes = activityLogTypes ?? ActivityLogTypeProvider(),
        _users = users ?? UserProvider();

  /// Newest first, ordered by the API — the table's own Date column defaults
  /// to the same order (see `ActivitiesTable`), but this keeps the very first
  /// fetch, before any client-side sort runs, in that order too.
  static const String sortBy = 'Date desc';

  final BaseProvider<ActivityLog> _activityLogs;
  final BaseProvider<ActivityLogType> _activityLogTypes;
  final BaseProvider<User> _users;

  ActivitiesStatusState _status = ActivitiesStatusState.idle;
  String? _errorMessage;

  List<User> _userList = const [];
  List<ActivityLogType> _typeList = const [];

  ActivitiesStatusState get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == ActivitiesStatusState.loading;

  Future<void> load() async {
    _status = ActivitiesStatusState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final lookups = await Future.wait([_all(_users), _all(_activityLogTypes)]);

      _userList = lookups[0] as List<User>;
      _typeList = lookups[1] as List<ActivityLogType>;

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

  /// A whole lookup table, paged through by [BaseProvider.getAll] because the
  /// API caps how many rows one request may return.
  Future<List<E>> _all<E>(BaseProvider<E> provider) => provider.getAll();

  /// The whole activity log — the table's own column sort and filter need the
  /// whole set to sort and check values against, not one page at a time.
  Future<List<ActivityRow>> loadAllRows() async {
    final logs = await _activityLogs.getAll(filter: {'sortBy': sortBy});
    return _buildRows(logs);
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
