enum AppEnvironment {
  dev,
  prod;

  static AppEnvironment parse(String value) {
    return switch (value.trim().toLowerCase()) {
      'prod' || 'production' => AppEnvironment.prod,
      _ => AppEnvironment.dev,
    };
  }
}

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.appName,
    required this.apiBaseUrl,
    required this.cloudModelId,
    required this.localModelRegistryName,
    required this.enableDiagnostics,
    required this.clerkPublishableKey,
  });

  final AppEnvironment environment;
  final String appName;
  final String apiBaseUrl;
  final String cloudModelId;
  final String localModelRegistryName;
  final bool enableDiagnostics;
  final String clerkPublishableKey;

  bool get isProduction => environment == AppEnvironment.prod;
  bool get clerkEnabled => clerkPublishableKey.trim().isNotEmpty;

  factory AppConfig.fromEnvironment() {
    const rawEnvironment = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'dev',
    );
    final environment = AppEnvironment.parse(rawEnvironment);

    return switch (environment) {
      AppEnvironment.dev => AppConfig.dev(),
      AppEnvironment.prod => AppConfig.prod(),
    };
  }

  factory AppConfig.dev() {
    return const AppConfig(
      environment: AppEnvironment.dev,
      appName: 'Wareeny Dev',
      apiBaseUrl: String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://localhost:8000',
      ),
      cloudModelId: String.fromEnvironment(
        'CLOUD_MODEL_ID',
        defaultValue: 'gemma4:e4b',
      ),
      localModelRegistryName: String.fromEnvironment(
        'LOCAL_MODEL_REGISTRY',
        defaultValue: 'wareeny-local-models-dev',
      ),
      enableDiagnostics: bool.fromEnvironment(
        'ENABLE_DIAGNOSTICS',
        defaultValue: true,
      ),
      clerkPublishableKey: String.fromEnvironment('CLERK_PUBLISHABLE_KEY'),
    );
  }

  factory AppConfig.prod() {
    return const AppConfig(
      environment: AppEnvironment.prod,
      appName: 'Wareeny',
      apiBaseUrl: String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'https://api.wareeny.app',
      ),
      cloudModelId: String.fromEnvironment(
        'CLOUD_MODEL_ID',
        defaultValue: 'gemma4:e4b',
      ),
      localModelRegistryName: String.fromEnvironment(
        'LOCAL_MODEL_REGISTRY',
        defaultValue: 'wareeny-local-models',
      ),
      enableDiagnostics: bool.fromEnvironment('ENABLE_DIAGNOSTICS'),
      clerkPublishableKey: String.fromEnvironment('CLERK_PUBLISHABLE_KEY'),
    );
  }
}
