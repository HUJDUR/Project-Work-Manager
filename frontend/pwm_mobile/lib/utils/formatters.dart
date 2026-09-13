import 'package:intl/intl.dart';

final _dayMonth = DateFormat('d MMM');
final _weekdayDayMonth = DateFormat('EEE, d MMM');
final _dayMonthYear = DateFormat('d MMM yyyy');
final _timeOfDay = DateFormat('HH:mm');
final _whole = NumberFormat('#,##0');
final _decimal = NumberFormat('#,##0.0');

/// Hours as the shop reads a shift — `7h 30m`, the form every mobile mockup
/// uses. The desktop says `7.5 h` instead, because its tables total whole days.
String formatClockHours(double hours) {
  final totalMinutes = (hours * 60).round();
  return '${totalMinutes ~/ 60}h ${(totalMinutes % 60).toString().padLeft(2, '0')}m';
}

String formatCount(num value) => _whole.format(value);

String formatDate(DateTime date) => _dayMonth.format(date);

String formatTime(DateTime date) => _timeOfDay.format(date);

/// A day as the hours list heads it: "Tue, 8 Sep".
String formatDayLabel(DateTime date) => _weekdayDayMonth.format(date);

String formatFullDate(DateTime date) => _dayMonthYear.format(date);

/// Hours as a bare figure for a card that carries its own "hrs" label, where
/// [formatClockHours] would repeat the unit.
String formatHoursValue(double hours) {
  final rounded = double.parse(hours.toStringAsFixed(1));
  return rounded == rounded.roundToDouble()
      ? _whole.format(rounded)
      : _decimal.format(rounded);
}

/// The span a block of work covers — "07:01 - 09:55", or open-ended while the
/// worker is still on it.
String formatTimeRange(DateTime from, DateTime? to) =>
    '${formatTime(from)} - ${to == null ? '...' : formatTime(to)}';

/// A running session's elapsed time, ticking: `0:07:12`, `11:03:40`. Seconds are
/// shown because this counts up on screen and a clock that never visibly moves
/// reads as broken.
String formatElapsed(Duration elapsed) {
  final seconds = elapsed.inSeconds;
  final minutes = (seconds ~/ 60) % 60;

  return '${seconds ~/ 3600}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${(seconds % 60).toString().padLeft(2, '0')}';
}
