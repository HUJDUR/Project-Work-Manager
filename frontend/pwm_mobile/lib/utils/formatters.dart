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
/// The backend stamps every row with `DateTime.UtcNow` and serialises it
/// **without a zone marker** — `2026-09-14T17:45:18`, not `...Z` — so Dart parses
/// it as local and a message sent a minute ago reads as however many hours this
/// machine sits from UTC. Everywhere else in both apps a stamp is shown as a
/// *date*, where that offset never surfaces; the notifications list is the only
/// screen that counts backwards from now, which is why this is the only place
/// that has to put the zone back on. A value that did arrive with a zone is
/// already right and is only converted.
///
/// The real fix is at the API, and it is a one-line serializer setting that
/// would move every date the desktop shows — which is why it is not made here.
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
