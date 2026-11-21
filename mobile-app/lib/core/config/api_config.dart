enum AppEnvironment { local, emulator, production }

class ApiConfig {
  const ApiConfig._({required this.environment, required this.baseUrl});

  final AppEnvironment environment;
  final Uri baseUrl;

  factory ApiConfig.fromEnvironment() {
    return ApiConfig.fromValues(
      environment: const String.fromEnvironment(
        'APP_ENV',
        defaultValue: 'local',
      ),
      baseUrlOverride: const String.fromEnvironment('API_BASE_URL'),
    );
  }

  factory ApiConfig.fromValues({
    required String environment,
    String baseUrlOverride = '',
  }) {
    final appEnvironment = switch (environment.trim().toLowerCase()) {
      'local' => AppEnvironment.local,
      'emulator' => AppEnvironment.emulator,
      'production' => AppEnvironment.production,
      _ => throw ArgumentError.value(
        environment,
        'environment',
        'Chỉ hỗ trợ local, emulator hoặc production.',
      ),
    };

    final override = baseUrlOverride.trim();
    final defaultUrl = switch (appEnvironment) {
      AppEnvironment.local => 'http://127.0.0.1:3000/api/v1',
      AppEnvironment.emulator => 'http://10.0.2.2:3000/api/v1',
      AppEnvironment.production => '',
    };
    final value = override.isEmpty ? defaultUrl : override;
    final uri = Uri.tryParse(value.replaceAll(RegExp(r'/+$'), ''));

    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw ArgumentError.value(
        baseUrlOverride,
        'baseUrlOverride',
        'API_BASE_URL phải là URL tuyệt đối.',
      );
    }
    if (appEnvironment == AppEnvironment.production && uri.scheme != 'https') {
      throw ArgumentError.value(
        baseUrlOverride,
        'baseUrlOverride',
        'Production bắt buộc dùng HTTPS.',
      );
    }

    return ApiConfig._(environment: appEnvironment, baseUrl: uri);
  }
}
