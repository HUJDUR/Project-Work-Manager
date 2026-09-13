import 'package:intl/intl.dart';

final _dayMonth = DateFormat('d MMM');
final _timeOfDay = DateFormat('HH:mm');
final _whole = NumberFormat('#,##0');

/// Hours as the shop reads a shift — `7h 30m`, the form every mobile mockup
/// uses. The desktop says `7.5 h` instead, because its tables total whole days.
String formatClockHours(double hours) {
  final totalMinutes = (hours * 60).round();
  return '${totalMinutes ~/ 60}h ${(totalMinutes % 60).toString().padLeft(2, '0')}m';
}

String formatCount(num value) => _whole.format(value);

String formatDate(DateTime date) => _dayMonth.format(date);

String formatTime(DateTime date) => _timeOfDay.format(date);
