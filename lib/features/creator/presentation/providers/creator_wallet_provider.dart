import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/wallet_ledger_entry.dart';
import 'creator_repository_provider.dart';

final creatorWalletLedgerProvider =
    FutureProvider.autoDispose<List<WalletLedgerEntry>>((ref) async {
      return ref.watch(creatorRepositoryProvider).loadWalletLedger();
    });
