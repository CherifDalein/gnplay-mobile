import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/domain/user_read.dart';

/// Compte de l'utilisateur connecté.
class ProfileRepository {
  ProfileRepository(this._api);

  final ApiClient _api;

  Future<UserRead> me() async {
    final json = await _api.get('/api/v1/users/me');
    return UserRead.fromJson(json.asObject);
  }

  Future<UserRead> update({
    String? fullName,
    String? pageName,
    String? bio,
  }) async {
    final json = await _api.patch(
      '/api/v1/users/me',
      json: {
        if (fullName != null) 'full_name': fullName,
        if (pageName != null) 'page_name': pageName,
        if (bio != null) 'bio': bio,
      },
    );
    return UserRead.fromJson(json.asObject);
  }

  /// Envoie la photo de profil et renvoie son URL publique.
  Future<String> uploadProfilePicture(String filePath) async {
    final json = (await _api.postFile(
      '/api/v1/users/me/profile-picture',
      field: 'file',
      filePath: filePath,
    )).asObject;
    final url = json['profile_picture_url'];
    if (url is String && url.isNotEmpty) return url;
    throw const ApiException(
      'Réponse inattendue du serveur.',
      kind: ApiErrorKind.unexpected,
    );
  }

  Future<UserRead> becomeCreator() async {
    final json = await _api.post('/api/v1/users/me/become-creator');
    return UserRead.fromJson(json.asObject);
  }
}
