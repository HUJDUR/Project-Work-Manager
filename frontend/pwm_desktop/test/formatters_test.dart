import 'package:flutter_test/flutter_test.dart';
import 'package:pwm_desktop/utils/formatters.dart';

void main() {
  group('apiTimeToLocal', () {
    test('reinterprets a zone-less stamp as UTC before converting', () {
      // What the API actually sends: `DateTime.UtcNow` that round-tripped
      // through SQL Server and lost its `Kind`, so `DateTime.parse` reads it
      // back as `Unspecified`/local rather than UTC.
      final fromApi = DateTime.parse('2026-09-22T14:30:00');
      expect(fromApi.isUtc, isFalse);

      final result = apiTimeToLocal(fromApi);

      final expected =
          DateTime.utc(2026, 9, 22, 14, 30).toLocal();
      expect(result, expected);
    });

    test('leaves a properly zoned stamp alone, just converted', () {
      final fromApi = DateTime.parse('2026-09-22T14:30:00Z');
      expect(fromApi.isUtc, isTrue);

      expect(apiTimeToLocal(fromApi), fromApi.toLocal());
    });
  });

  group('formatRelative', () {
    test('reads "just now" right after apiTimeToLocal, not hours off', () {
      // The bug this guards: without apiTimeToLocal, a zone-less stamp for
      // something that happened seconds ago reads as however many hours this
      // machine sits from UTC — "2 h ago" instead of "just now".
      final rightNowFromApi =
          DateTime.now().toUtc().toIso8601String().replaceAll('Z', '');
      final parsed = DateTime.parse(rightNowFromApi);

      expect(formatRelative(apiTimeToLocal(parsed)), 'just now');
    });
  });
}
