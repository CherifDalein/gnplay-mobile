import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/topup.dart';
import 'creator_dashboard_provider.dart';
import '../../../../core/network/repositories.dart';
import 'creator_wallet_provider.dart';

enum TopupPhase { idle, starting, awaitingPayment, completed, failed }

class TopupState {
  const TopupState({
    this.phase = TopupPhase.idle,
    this.reference,
    this.message,
  });

  final TopupPhase phase;
  final String? reference;
  final String? message;

  bool get isBusy =>
      phase == TopupPhase.starting || phase == TopupPhase.awaitingPayment;
}

final topupControllerProvider =
    StateNotifierProvider.autoDispose<TopupController, TopupState>(
      (ref) => TopupController(ref),
    );

class TopupController extends StateNotifier<TopupState> {
  TopupController(this._ref) : super(const TopupState());

  final Ref _ref;
  Timer? _poller;

  static const _pollInterval = Duration(seconds: 3);
  static const _maxPolls = 100; // ~5 minutes

  Future<void> start(int amount) async {
    state = const TopupState(phase: TopupPhase.starting);
    try {
      final checkout = await _ref
          .read(walletRepositoryProvider)
          .initiateTopup(amount);
      final opened = await launchUrl(
        Uri.parse(checkout.paymentUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        throw const ApiException('Impossible d’ouvrir la page de paiement.');
      }
      state = TopupState(
        phase: TopupPhase.awaitingPayment,
        reference: checkout.reference,
      );
      _startPolling(checkout.reference);
    } catch (error) {
      state = TopupState(phase: TopupPhase.failed, message: '$error');
    }
  }

  /// Vérification immédiate (retour dans l'app après le paiement).
  Future<void> checkNow() async {
    final reference = state.reference;
    if (reference == null || state.phase != TopupPhase.awaitingPayment) {
      return;
    }
    await _poll(reference);
  }

  void _startPolling(String reference) {
    _poller?.cancel();
    var attempts = 0;
    _poller = Timer.periodic(_pollInterval, (timer) async {
      attempts++;
      if (attempts > _maxPolls) {
        timer.cancel();
        if (mounted && state.phase == TopupPhase.awaitingPayment) {
          state = TopupState(
            phase: TopupPhase.failed,
            reference: reference,
            message:
                'Paiement non confirmé. Si vous avez payé, le solde sera crédité sous peu.',
          );
        }
        return;
      }
      await _poll(reference);
    });
  }

  Future<void> _poll(String reference) async {
    try {
      final status = await _ref
          .read(walletRepositoryProvider)
          .getTopupStatus(reference);
      if (!mounted || !status.isFinal) {
        return;
      }
      _poller?.cancel();
      if (status == TopupStatus.completed) {
        _ref.invalidate(creatorDashboardProvider);
        _ref.invalidate(creatorWalletLedgerProvider);
        state = TopupState(phase: TopupPhase.completed, reference: reference);
      } else {
        state = TopupState(
          phase: TopupPhase.failed,
          reference: reference,
          message: 'Le paiement a été refusé ou annulé.',
        );
      }
    } catch (_) {
      // Erreur réseau ponctuelle : la prochaine itération réessaiera.
    }
  }

  void reset() {
    _poller?.cancel();
    state = const TopupState();
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }
}
