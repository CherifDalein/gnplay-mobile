class ApiConfig {
  static const _rawBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://gnplay-api.nextgenz.tech/',
  );

  /// Sans slash final : la plupart des appels concatènent directement
  /// `'${ApiConfig.baseUrl}/api/v1/...'`, un slash final ici produirait un
  /// chemin `//api/v1/...` (deux segments distincts pour un routeur HTTP
  /// strict, silencieusement masqué seulement si un proxy en amont fusionne
  /// les doubles slashes).
  static String get baseUrl => _rawBaseUrl.endsWith('/')
      ? _rawBaseUrl.substring(0, _rawBaseUrl.length - 1)
      : _rawBaseUrl;
}
