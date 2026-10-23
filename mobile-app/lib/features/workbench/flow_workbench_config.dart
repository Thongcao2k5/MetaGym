abstract final class FlowWorkbenchConfig {
  static const enabled =
      String.fromEnvironment('APP_ENV', defaultValue: 'emulator') !=
      'production';
}
