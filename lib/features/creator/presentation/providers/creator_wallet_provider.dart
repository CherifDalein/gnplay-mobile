import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/repositories.dart';
import '../../domain/wallet_ledger_entry.dart';

final creatorWalletLedgerProvider =
    FutureProvider.autoDispose<List<WalletLedgerEntry>>((ref) {
      return ref.watch(walletRepositoryProvider).loadLedger();
    });
