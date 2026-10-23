import '../../../core/network/api_client.dart';
import '../domain/creator_analytics.dart';

class CreatorAnalyticsRepository {
  CreatorAnalyticsRepository(this._api);

  final ApiClient _api;

  /// Vues, abonnés, revenus total/mois et top 5 (`GET /creators/me/analytics`,
  /// réservé aux créateurs : 403 pour un compte spectateur).
  Future<CreatorAnalytics> load() async {
    final json = await _api.get('/api/v1/creators/me/analytics');
    return CreatorAnalytics.fromJson(json.asObject);
  }
}
