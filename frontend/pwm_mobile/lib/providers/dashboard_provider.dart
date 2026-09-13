import 'package:flutter/material.dart';

import '../models/models.dart';
import '../utils/api_client_exception.dart';
import 'auth_provider.dart';
import 'base_provider.dart';
import 'work_log_detail_provider.dart';

enum DashboardStatus { idle, loading, ready, failed }

/// The shop floor's home screen, scoped to whoever is signed in: their hours
/// today and this week, and how many projects each covered.
///
/// One request does it. `WorkLogDetail` carries its own `UserId`, so the blocks
/// come back already narrowed to this worker, and `dateFrom` keeps it to the
/// current week rather than their whole history. Today's numbers are then a
/// subset of the week's, which is why there is no second call for them.
class DashboardProvider extends ChangeNotifier {
  DashboardProvider({
    BaseProvider<WorkLogDetail>? workLogDetails,
    int? userId,
    DateTime Function()? clock,
  })  : _workLogDetails = workLogDetails ?? WorkLogDetailProvider(),
        _userId = userId ?? AuthProvider.user?.id,
        _clock = clock ?? DateTime.now;

  final BaseProvider<WorkLogDetail> _workLogDetails;
  final int? _userId;
  final DateTime Function() _clock;

  DashboardStatus _status = DashboardStatus.idle;
  WorkerSummary? _summary;
  String? _errorMessage;

  DashboardStatus get status => _status;
  WorkerSummary? get summary => _summary;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == DashboardStatus.loading;

  /// The signed-in account's first name, for the greeting. Falls back to the
  /// mockup's wording when nobody is signed in — the dev bypass in `main`.
  String get greetingName {
    final name = AuthProvider.user?.name.trim() ?? '';
    return name.isEmpty ? 'Worker' : name;
  }

  Future<void> load() async {
    final userId = _userId;

    if (userId == null) {
      _errorMessage = 'No account is signed in.';
      _status = DashboardStatus.failed;
      notifyListeners();
      return;
    }

    _status = DashboardStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final now = _clock();
      final today = DateTime(now.year, now.month, now.day);
      // The shop's week runs Monday to Sunday.
      final weekStart = today.subtract(Duration(days: now.weekday - 1));

      final blocks = await _workLogDetails.getAll(filter: {
        'userId': userId,
        'dateFrom': weekStart,
      });

      // A block the API let through that predates the week would inflate the
      // totals, so the window is applied here as well as in the request.
      final thisWeek =
          blocks.where((b) => !b.startedAt.isBefore(weekStart)).toList();
      final todaysWork =
          thisWeek.where((b) => !b.startedAt.isBefore(today)).toList();

      _summary = WorkerSummary(
        todayHours: _hours(todaysWork),
        todayProjects: _projectCount(todaysWork),
        weekHours: _hours(thisWeek),
        weekProjects: _projectCount(thisWeek),
        weekStart: weekStart,
      );
      _status = DashboardStatus.ready;
    } on ApiClientException catch (error) {
      _errorMessage = error.message;
      _status = DashboardStatus.failed;
    } catch (error) {
      _errorMessage = 'Something went wrong while loading your work: $error';
      _status = DashboardStatus.failed;
    }

    notifyListeners();
  }

  double _hours(List<WorkLogDetail> blocks) =>
      blocks.fold<double>(0, (sum, block) => sum + block.hours);

  int _projectCount(List<WorkLogDetail> blocks) =>
      blocks.map((block) => block.projectId).toSet().length;
}
