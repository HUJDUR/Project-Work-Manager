import 'sarajevo_time.dart';

/// The sections a notification list is split into, newest first.
enum NotificationDay {
  today('Today'),
  yesterday('Yesterday'),
  earlier('Earlier');

  const NotificationDay(this.label);

  final String label;
}

/// Which section [createdAt] belongs in, by Sarajevo calendar day - "yesterday"
/// is the day before today, not the last 24 hours.
NotificationDay notificationDayOf(DateTime createdAt, {DateTime? now}) {
  final today = _dateOnly(now ?? SarajevoTime.now());
  final day = _dateOnly(createdAt);

  if (!day.isBefore(today)) return NotificationDay.today;
  if (day == today.subtract(const Duration(days: 1))) return NotificationDay.yesterday;
  return NotificationDay.earlier;
}

/// [rows] under the section each falls in, sections in [NotificationDay] order
/// and rows in the order given; a section with nothing in it is left out.
List<(NotificationDay, List<T>)> groupNotificationsByDay<T>(
  List<T> rows,
  DateTime Function(T row) createdAt, {
  DateTime? now,
}) {
  final grouped = {for (final day in NotificationDay.values) day: <T>[]};

  for (final row in rows) {
    grouped[notificationDayOf(createdAt(row), now: now)]!.add(row);
  }

  return [
    for (final day in NotificationDay.values)
      if (grouped[day]!.isNotEmpty) (day, grouped[day]!),
  ];
}

DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);
