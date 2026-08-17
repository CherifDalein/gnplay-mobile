import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return const TokenStorage();
});
