import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';

void main() {
  group('ApiConfig', () {
    test('uses loopback URL for local development', () {
      final config = ApiConfig.fromValues(environment: 'local');

      expect(config.environment, AppEnvironment.local);
      expect(config.baseUrl, Uri.parse('http://127.0.0.1:3000/api/v1'));
    });

    test('uses Android host URL for emulator development', () {
      final config = ApiConfig.fromValues(environment: 'emulator');

      expect(config.environment, AppEnvironment.emulator);
      expect(config.baseUrl, Uri.parse('http://10.0.2.2:3000/api/v1'));
    });

    test('requires an explicit HTTPS URL in production', () {
      expect(
        () => ApiConfig.fromValues(environment: 'production'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => ApiConfig.fromValues(
          environment: 'production',
          baseUrlOverride: 'http://api.example.test/api/v1',
        ),
        throwsA(isA<ArgumentError>()),
      );

      final config = ApiConfig.fromValues(
        environment: 'production',
        baseUrlOverride: 'https://api.metagym.example/api/v1/',
      );

      expect(config.environment, AppEnvironment.production);
      expect(config.baseUrl, Uri.parse('https://api.metagym.example/api/v1'));
    });

    test('rejects an unsupported environment', () {
      expect(
        () => ApiConfig.fromValues(environment: 'staging'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
