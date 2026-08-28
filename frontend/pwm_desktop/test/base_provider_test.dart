import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pwm_desktop/providers/base_provider.dart';
import 'package:pwm_desktop/utils/api_client_exception.dart';

class _TestProvider extends BaseProvider<Object> {
  _TestProvider() : super('Test');
}

/// The bodies `pwm.WebAPI/Filters/ExceptionFilter` actually writes.
http.Response _clientError(String message) => http.Response(
      jsonEncode({
        'message': message,
        'errors': {
          'clientError': [message],
        },
      }),
      400,
    );

http.Response _validationError() => http.Response(
      jsonEncode({
        'message': 'Name is required.',
        'errors': {
          'Name': ['Name is required.'],
          'Weight': ['Weight must be greater than 0.'],
        },
      }),
      400,
    );

void main() {
  group('validateResponse', () {
    final provider = _TestProvider();

    test('passes a successful response through', () {
      expect(() => provider.validateResponse(http.Response('{}', 200)), returnsNormally);
    });

    test('surfaces the message a business rule failure carries', () {
      expect(
        () => provider.validateResponse(_clientError('Project is already delivered.')),
        throwsA(isA<ApiClientException>().having(
            (e) => e.message, 'message', 'Project is already delivered.')),
      );
    });

    test('surfaces the first message of a failed validation run', () {
      expect(
        () => provider.validateResponse(_validationError()),
        throwsA(isA<ApiClientException>()
            .having((e) => e.message, 'message', 'Name is required.')),
      );
    });

    test('falls back to fixed wording when the body carries no message', () {
      expect(
        () => provider.validateResponse(http.Response('', 500)),
        throwsA(isA<ApiClientException>().having(
            (e) => e.message, 'message', 'Server error. Please try again later.')),
      );
    });

    test('asks the user to sign in again on 401', () {
      expect(
        () => provider.validateResponse(http.Response('', 401)),
        throwsA(isA<ApiClientException>().having((e) => e.message, 'message',
            'Your session has expired. Please sign in again.')),
      );
    });
  });
}
