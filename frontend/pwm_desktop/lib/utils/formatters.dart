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
/// The backend stamps every row with `DateTime.UtcNow`, but it round-trips
/// through SQL Server and EF Core first, which drops the `Kind` back to
/// unspecified — so it serialises **without a zone marker**,
/// `2026-09-22T14:30:00`, not `...Z`. Dart parses that as local time, so
/// something that happened a minute ago reads as however many hours this
/// machine sits from UTC. Everywhere else a stamp is shown as a *date*, where
/// that offset never surfaces; it is only the screens that count backwards
/// from now — the dashboard's Activity feed, a report's "generated ...ago",
/// the notification bell — that have to put the zone back on. A value that
/// did arrive with a zone is already right and is only converted.
///
/// The real fix is at the API, and it is a one-line serializer setting that
/// would move every date both apps show — which is why it is not made here.
/// The mobile app carries the same helper for the same reason.
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
