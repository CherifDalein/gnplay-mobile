import '../../../core/network/api_client.dart';
import '../domain/register_request.dart';
import '../domain/token_response.dart';
import '../domain/user_read.dart';

/// Authentification : connexion, session, inscription avec code OTP et
/// réinitialisation du mot de passe. Le compte lui-même (profil, avatar,
/// passage créateur) est dans `ProfileRepository`.
class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  /// Le backend attend un formulaire OAuth2 (`username` = téléphone).
  Future<TokenResponse> login({
    required String phoneNumber,
    required String password,
  }) async {
    final json = await _api.post(
      '/api/v1/auth/login',
      form: {
        'grant_type': 'password',
        'username': phoneNumber,
        'password': password,
        'scope': '',
      },
      authenticated: false,
    );
    return TokenResponse.fromJson(json.asObject);
  }

  /// Le refresh token est rotatif : l'ancien est révoqué par cet appel.
  Future<TokenResponse> refreshToken({required String refreshToken}) async {
    final json = await _api.post(
      '/api/v1/auth/refresh-token',
      json: {'refresh_token': refreshToken},
      authenticated: false,
    );
    return TokenResponse.fromJson(json.asObject);
  }

  /// [refreshToken] null révoque toutes les sessions de l'utilisateur ;
  /// fourni, ne révoque que cette session (cet appareil).
  Future<void> logout({String? refreshToken}) =>
      _api.post('/api/v1/auth/logout', json: {'refresh_token': refreshToken});

  /// [channel] : `whatsapp` ou `sms` pour forcer le canal d'envoi ; absent,
  /// le serveur choisit (WhatsApp si possible, sinon SMS).
  Future<void> requestRegisterOtp({
    required String phoneNumber,
    String? channel,
  }) => _api.post(
    '/api/v1/auth/request-otp',
    json: {
      'phone_number': phoneNumber,
      'otp_type': 'register',
      'channel': ?channel,
    },
    authenticated: false,
  );

  Future<void> verifyRegisterOtp({
    required String phoneNumber,
    required String code,
  }) => _api.post(
    '/api/v1/auth/verify-otp',
    json: {'phone_number': phoneNumber, 'otp_type': 'register', 'code': code},
    authenticated: false,
  );

  Future<UserRead> register(RegisterRequest request) async {
    final json = await _api.post(
      '/api/v1/auth/register',
      json: request.toJson(),
      authenticated: false,
    );
    return UserRead.fromJson(json.asObject);
  }

  /// [channel] : voir [requestRegisterOtp].
  Future<void> requestPasswordReset({
    required String phoneNumber,
    String? channel,
  }) => _api.post(
    '/api/v1/auth/request-password-reset',
    json: {
      'phone_number': phoneNumber,
      'otp_type': 'reset_password',
      'channel': ?channel,
    },
    authenticated: false,
  );

  Future<void> resetPassword({
    required String phoneNumber,
    required String code,
    required String newPassword,
  }) => _api.post(
    '/api/v1/auth/reset-password',
    json: {
      'phone_number': phoneNumber,
      'otp_type': 'reset_password',
      'code': code,
      'new_password': newPassword,
    },
    authenticated: false,
  );
}
