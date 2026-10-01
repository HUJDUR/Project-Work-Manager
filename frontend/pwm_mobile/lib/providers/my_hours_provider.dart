import '../models/models.dart';
import '../utils/api_client_exception.dart';
import '../utils/sarajevo_time.dart';
import 'package:flutter/material.dart';
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

/// My Work Hours: the signed-in worker's own bookings, grouped into days and
/// paged - `GET /WorkLogDetail/MyDays` answers one page of days, newest first,
/// each with its blocks already named, plus the whole period's totals and each
/// worked day's figures, so the metric cards and trend lines always cover the
/// period however few pages are loaded. [loadMore] appends the next page.
class MyHoursProvider extends ChangeNotifier {
  MyHoursProvider({
    WorkLogDetailProvider? workLogDetails,
    DateTime Function()? clock,
  })  : _workLogDetails = workLogDetails ?? WorkLogDetailProvider(),
        _clock = clock ?? SarajevoTime.now;

  /// Days per page - about two working weeks.
  static const int pageSize = 10;

  final WorkLogDetailProvider _workLogDetails;
  final DateTime Function() _clock;

  MyHoursStatus _status = MyHoursStatus.idle;
  HoursPeriod _period = HoursPeriod.thisWeek;
  List<WorkDay> _days = const [];
  WorkDaysPage? _summary;
  int _page = 1;
  bool _isLoadingMore = false;
  String? _errorMessage;

  /// Bumped per request, so a slow answer for the period just left cannot
  /// overwrite the one now showing.
  int _request = 0;

  MyHoursStatus get status => _status;
  HoursPeriod get period => _period;
  List<WorkDay> get days => _days;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == MyHoursStatus.loading;
  bool get isEmpty => _status == MyHoursStatus.ready && _days.isEmpty;

  /// Whether the period has days beyond those loaded so far.
  bool get hasMore => _days.length < (_summary?.totalCount ?? 0);
  bool get isLoadingMore => _isLoadingMore;

  double get totalHours => _summary?.totalHours ?? 0;

  /// Distinct across the whole period, not the sum of each day's count.
  int get projectCount => _summary?.projectCount ?? 0;

  /// Hours per day across the period, oldest first and including the days with
  /// nothing on them - a sparkline with the gaps left out would draw a week of
  /// two shifts as a straight line.
  List<double> get hoursTrend => _seriesByDay((day) => day?.hours ?? 0);

  List<double> get projectsTrend =>
      _seriesByDay((day) => (day?.projectCount ?? 0).toDouble());

  DateRange get range => rangeFor(_period, _clock());

  Future<void> setPeriod(HoursPeriod period) async {
    if (_period == period) return;

    _period = period;
    await load();
  }

  /// The first page of the period, replacing whatever was loaded.
  Future<void> load() async {
    final request = ++_request;
    _status = MyHoursStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final page = await _fetch(1);
      if (request != _request) return;

      _summary = page;
      _days = page.days;
      _page = 1;
      _status = MyHoursStatus.ready;
    } on ApiClientException catch (error) {
      if (request != _request) return;
      _errorMessage = error.message;
      _status = MyHoursStatus.failed;
    } catch (error) {
      if (request != _request) return;
      _errorMessage = 'Something went wrong while loading your hours: $error';
      _status = MyHoursStatus.failed;
    }

    notifyListeners();
  }

  /// The next page of days, added under the ones already showing. Throws
  /// [ApiClientException] with the API's own wording if it fails, leaving the
  /// loaded days as they are.
  Future<void> loadMore() async {
    if (!hasMore || _isLoadingMore || _status != MyHoursStatus.ready) return;

    final request = _request;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _fetch(_page + 1);
      if (request != _request) return;

      _summary = page;
      _days = [..._days, ...page.days];
      _page++;
    } finally {
      if (request == _request) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<WorkDaysPage> _fetch(int page) {
    final window = range;
    return _workLogDetails.myDays(
      from: window.from,
      to: window.to,
      page: page,
      pageSize: pageSize,
    );
  }

  /// A day's blocks, already named by the API.
  Future<List<WorkEntry>> entriesFor(WorkDay day) async => day.entries;

  /// One value per calendar day of the period, oldest first.
  List<double> _seriesByDay(double Function(WorkDayTotal?) valueOf) {
    final trend = _summary?.trend ?? const <WorkDayTotal>[];
    if (trend.isEmpty) return const [];

    final byDate = {for (final day in trend) _dateOf(day.date): day};
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
