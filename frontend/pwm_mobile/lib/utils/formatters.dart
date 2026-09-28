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

/// A timestamp from the API, as local time.
///
/// The API now forces every `DateTime` it serialises to carry a `Z` (see
/// `UtcDateTimeConverter` on the backend), so a value read from the wire
/// arrives with `isUtc == true` and the first branch below is the one that
/// actually runs. The second branch is a leftover safety net for anything
/// that predates that fix or was parsed some other way - a naive value is
/// still assumed to be UTC (the backend's own convention) rather than
/// already-local, which is the mistake this function exists to undo. Call
/// this wherever a stamp is shown as a *time*, not only where something
/// counts backwards from now; a bare *date* rarely needs it, but a clock
/// reading does. The desktop app carries the same helper for the same reason.
DateTime apiTimeToLocal(DateTime value) => value.isUtc
    ? value.toLocal()
    : DateTime.utc(
        value.year,
        value.month,
        value.day,
        value.hour,
        value.minute,
        value.second,
        value.millisecond,
        value.microsecond,
      ).toLocal();

/// How long ago something happened, for a list read top-down where the exact
/// minute does not matter — "12 min ago", "3 h ago", then a plain date once it
/// is a week old and "ago" stops meaning anything useful. The desktop's
/// `formatRelative` is the same function; a stamp should not read two ways
/// across the two apps.
String formatRelative(DateTime date, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final difference = reference.difference(date);

  if (difference.isNegative) return formatDate(date);
  if (difference.inMinutes < 1) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) return '${difference.inHours} h ago';
  if (difference.inDays < 7) return '${difference.inDays} d ago';

  return formatDate(date);
}

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

/// Kilograms in, tonnes out — a project's weight runs into thousands of kg, the
/// same conversion the desktop's formatter makes.
String formatTonnes(double kilograms) => '${_decimal.format(kilograms / 1000)} t';
