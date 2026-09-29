import 'package:flutter_test/flutter_test.dart';
import 'package:pwm_mobile/utils/formatters.dart';
import 'package:pwm_mobile/utils/sarajevo_time.dart';

void main() {
  group('SarajevoTime', () {
    test('reads a summer instant as CEST, UTC+2', () {
      expect(SarajevoTime.fromApi('2026-07-15T05:00:00Z'), DateTime(2026, 7, 15, 7));
    });

    test('reads a winter instant as CET, UTC+1', () {
      expect(SarajevoTime.fromApi('2026-01-15T06:00:00Z'), DateTime(2026, 1, 15, 7));
    });

    test('a value without a Z is still the API\'s UTC, not this device\'s time', () {
      expect(SarajevoTime.fromApi('2026-07-15T05:00:00'), DateTime(2026, 7, 15, 7));
    });

    test('switches to summer time at 01:00 UTC on the last Sunday of March', () {
      // 29 March 2026 is that Sunday.
      expect(SarajevoTime.fromApi('2026-03-29T00:59:00Z'), DateTime(2026, 3, 29, 1, 59));
      expect(SarajevoTime.fromApi('2026-03-29T01:00:00Z'), DateTime(2026, 3, 29, 3));
    });

    test('switches back at 01:00 UTC on the last Sunday of October', () {
      // 25 October 2026 is that Sunday.
      expect(SarajevoTime.fromApi('2026-10-25T00:59:00Z'), DateTime(2026, 10, 25, 2, 59));
      expect(SarajevoTime.fromApi('2026-10-25T01:00:00Z'), DateTime(2026, 10, 25, 2));
    });

    test('sends a Sarajevo wall time as the UTC instant it names', () {
      expect(SarajevoTime.toApi(DateTime(2026, 7, 15, 7)), '2026-07-15T05:00:00.000Z');
      expect(SarajevoTime.toApi(DateTime(2026, 1, 15, 7)), '2026-01-15T06:00:00.000Z');
      // Sarajevo midnight is the day before in UTC - what a date filter sends.
      expect(SarajevoTime.toApi(DateTime(2026, 9, 29)), '2026-09-28T22:00:00.000Z');
    });

    test('round-trips through the API unchanged', () {
      final wall = DateTime(2026, 11, 3, 15, 45, 12);
      expect(SarajevoTime.fromApi(SarajevoTime.toApi(wall)), wall);
    });
  });

  group('formatRelative', () {
    test('reads "just now" for something the API stamped a moment ago', () {
      final stampedNow = SarajevoTime.fromApi(DateTime.now().toUtc().toIso8601String());

      expect(formatRelative(stampedNow), 'just now');
    });
  });
}
