import 'package:flutter/material.dart';

import '../models/active_session.dart';
import '../models/clock_in_option.dart';
import '../utils/api_client_exception.dart';
import 'clock_in_api_provider.dart';

enum ClockInStatus { idle, loading, ready, failed }

/// Clocking on and off a piece of work.
///
/// A `WorkLog` is a shift - one day, first clock-in to last clock-out - and its
/// `WorkLogDetail`s are the separate operations worked through it; a session is
/// the one still running. All of that is the API's to do: clocking in is one
/// request that names a project and an operation, clocking out is one request
/// that names nothing. The server takes the time from its own clock, works out
/// the hours, joins or raises the day's shift, and refuses a second session on
/// top of a running one - so none of it rests on the phone.
///
/// What the dropdowns offer comes from the API too: projects in production, and
/// only the operations this worker is qualified for.
class ClockInProvider extends ChangeNotifier {
  ClockInProvider({ClockInApiProvider? api}) : _api = api ?? ClockInApiProvider();

  final ClockInApiProvider _api;

  ClockInStatus _status = ClockInStatus.idle;
  String? _errorMessage;
  bool _isSubmitting = false;

  List<ClockInOption> _projectOptions = const [];
  List<ClockInOption> _operationOptions = const [];
  ActiveSession? _active;

  int? _selectedProjectId;
  int? _selectedOperationId;

  ClockInStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == ClockInStatus.loading;

  /// True while a clock-in or clock-out is in flight, which is what stops the
  /// buttons being pressed twice.
  bool get isSubmitting => _isSubmitting;

  List<ClockInOption> get projectOptions => _projectOptions;
  List<ClockInOption> get operationOptions => _operationOptions;
  ActiveSession? get active => _active;
  bool get hasActiveSession => _active != null;

  int? get selectedProjectId => _selectedProjectId;
  int? get selectedOperationId => _selectedOperationId;

  /// What stops a worker clocking in: already on something, nothing picked, or
  /// nothing to pick. Null when the button should work. The API checks all of
  /// this again - this only says so before the tap rather than after.
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
    _status = ClockInStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final options = await _api.options();

      _projectOptions = options.projects;
      _operationOptions = options.operations;
      _active = options.session;

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

  /// The longest note a session may carry - `WorkBookingRules.NoteMaxLength`
  /// on the API.
  static const int noteMaxLength = 200;

  String _note = '';

  /// Optional; whatever the worker wants to add about this session.
  String get note => _note;

  void setNote(String value) {
    _note = value;
  }

  /// Starts a session on the picked project and operation. Throws
  /// [ApiClientException] with the API's own wording if it is refused.
  Future<void> clockIn() async {
    final projectId = _selectedProjectId;
    final operationId = _selectedOperationId;

    if (projectId == null || operationId == null || _isSubmitting) return;

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final note = _note.trim();
      _active = await _api.clockIn(
        projectId: projectId,
        operationTypeId: operationId,
        note: note.isEmpty ? null : note,
      );
      _selectedProjectId = null;
      _selectedOperationId = null;
      _note = '';
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Ends the running session. Throws [ApiClientException] if the API refuses.
  Future<void> clockOut() async {
    if (_active == null || _isSubmitting) return;

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.clockOut();
      _active = null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
