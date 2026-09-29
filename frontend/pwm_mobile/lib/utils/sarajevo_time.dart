import 'package:json_annotation/json_annotation.dart';

/// The shop runs on Sarajevo time, whatever time zone the device is set to.
///
/// The API speaks UTC - every timestamp it sends carries a `Z`, and every one it
/// receives is read as UTC. Inside the app every [DateTime] is Sarajevo
/// wall-clock time instead, held as a plain (non-UTC) value: what a date picker
/// returns, what `DateUtils.dateOnly` cuts to a day, what is printed. The two
/// meet in exactly two places - [fromApi] on the way in (models do it through
/// [ApiDateTimeConverter]) and [toApi] on the way out.
///
/// Mirrors `SarajevoTime` on the API. Europe/Sarajevo is CET (UTC+1), and CEST
/// (UTC+2) from 01:00 UTC on the last Sunday of March to 01:00 UTC on the last
/// Sunday of October - the EU rule.
abstract final class SarajevoTime {
  /// Now, on a Sarajevo wall clock.
  static DateTime now() => fromUtc(DateTime.now().toUtc());

  /// A UTC instant as Sarajevo wall-clock time.
  static DateTime fromUtc(DateTime instant) {
    final utc = instant.toUtc();
    final wall = utc.add(_offsetAt(utc));
    return DateTime(wall.year, wall.month, wall.day, wall.hour, wall.minute,
        wall.second, wall.millisecond, wall.microsecond);
  }

  /// A Sarajevo wall-clock time as the UTC instant it names.
  static DateTime toUtc(DateTime wall) {
    final asIfUtc = DateTime.utc(wall.year, wall.month, wall.day, wall.hour,
        wall.minute, wall.second, wall.millisecond, wall.microsecond);
    // The offset is chosen by the instant it applies at; one refinement settles it.
    final guess = asIfUtc.subtract(const Duration(hours: 1));
    return asIfUtc.subtract(_offsetAt(asIfUtc.subtract(_offsetAt(guess))));
  }

  /// An API timestamp string, as Sarajevo wall-clock time.
  static DateTime fromApi(String value) => fromUtc(_parseAsUtc(value));

  /// A Sarajevo wall-clock time, as the UTC string the API reads.
  static String toApi(DateTime wall) => toUtc(wall).toIso8601String();

  /// The API always sends a `Z`; a value without one is still its UTC, never
  /// this device's local time.
  static DateTime _parseAsUtc(String value) {
    final parsed = DateTime.parse(value);
    return parsed.isUtc
        ? parsed
        : DateTime.utc(parsed.year, parsed.month, parsed.day, parsed.hour,
            parsed.minute, parsed.second, parsed.millisecond, parsed.microsecond);
  }

  static Duration _offsetAt(DateTime utc) {
    final summerStarts = _lastSundayAt1Utc(utc.year, DateTime.march);
    final summerEnds = _lastSundayAt1Utc(utc.year, DateTime.october);
    final isSummer = !utc.isBefore(summerStarts) && utc.isBefore(summerEnds);
    return Duration(hours: isSummer ? 2 : 1);
  }

  static DateTime _lastSundayAt1Utc(int year, int month) {
    final lastDay = DateTime.utc(year, month + 1, 0, 1);
    return lastDay.subtract(Duration(days: lastDay.weekday % DateTime.daysPerWeek));
  }
}

/// How every model reads and writes a timestamp - see [SarajevoTime].
class ApiDateTimeConverter implements JsonConverter<DateTime, String> {
  const ApiDateTimeConverter();

  @override
  DateTime fromJson(String json) => SarajevoTime.fromApi(json);

  @override
  String toJson(DateTime object) => SarajevoTime.toApi(object);
}
