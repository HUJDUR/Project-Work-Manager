import 'package:intl/intl.dart';

final _dayMonth = DateFormat('dd.MM.');
final _dayMonthYear = DateFormat('dd.MM.yyyy.');
final _timeOfDay = DateFormat('HH:mm');
final _decimal = NumberFormat('#,##0.0');
final _whole = NumberFormat('#,##0');

String formatHours(double hours) {
  final rounded = double.parse(hours.toStringAsFixed(1));
  return rounded == rounded.roundToDouble()
      ? '${_whole.format(rounded)} h'
      : '${_decimal.format(rounded)} h';
}

/// Kilograms in, tonnes out — shop-floor loads run into thousands of kg.
String formatTonnes(double kilograms) => '${_decimal.format(kilograms / 1000)} t';

String formatCount(num value) => _whole.format(value);

String formatDate(DateTime date) => _dayMonth.format(date);

String formatFullDate(DateTime date) => _dayMonthYear.format(date);

String formatTime(DateTime date) => _timeOfDay.format(date);

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
/// reading does. The mobile app carries the same helper for the same reason.
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
