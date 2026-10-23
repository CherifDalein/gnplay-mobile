import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/repositories.dart';
import '../../data/auth_repository.dart';
import '../../domain/code_request_outcome.dart';
import '../widgets/auth_error_text.dart';

enum ForgotPasswordStep { phone, reset }

class ForgotPasswordState {
  const ForgotPasswordState({
    this.step = ForgotPasswordStep.phone,
    this.busy = false,
    this.error,
    this.codeSentTo,
  });

  final ForgotPasswordStep step;
  final bool busy;
  final Object? error;

  /// Numéro (E.164) auquel un code a été envoyé.
  final String? codeSentTo;

  ForgotPasswordState copyWith({
    ForgotPasswordStep? step,
    bool? busy,
    Object? error,
    bool clearError = false,
    String? codeSentTo,
  }) {
    return ForgotPasswordState(
      step: step ?? this.step,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
      codeSentTo: codeSentTo ?? this.codeSentTo,
    );
  }
}

final forgotPasswordControllerProvider =
    StateNotifierProvider.autoDispose<
      ForgotPasswordController,
      ForgotPasswordState
    >((ref) => ForgotPasswordController(ref.watch(authRepositoryProvider)));

class ForgotPasswordController extends StateNotifier<ForgotPasswordState> {
  ForgotPasswordController(this._repository)
    : super(const ForgotPasswordState());

  final AuthRepository _repository;

  void _update(ForgotPasswordState Function(ForgotPasswordState) change) {
    if (mounted) state = change(state);
  }

  /// Demande un code ([channel] null : choix du serveur).
  Future<CodeRequestOutcome> sendCode(String phone, {String? channel}) async {
    _update((s) => s.copyWith(busy: true, clearError: true));
    try {
      await _repository.requestPasswordReset(
        phoneNumber: phone,
        channel: channel,
      );
      _update(
        (s) => s.copyWith(
          busy: false,
          step: ForgotPasswordStep.reset,
          codeSentTo: phone,
        ),
      );
      return CodeRequestOutcome.sent;
    } catch (error) {
      if (isCodeCooldownError(error)) {
        // Un code vient d'être envoyé : il reste valable, on passe à sa saisie.
        _update(
          (s) => s.copyWith(
            busy: false,
            error: error,
            step: ForgotPasswordStep.reset,
            codeSentTo: phone,
          ),
        );
        return CodeRequestOutcome.rateLimited;
      }
      _update((s) => s.copyWith(busy: false, error: error));
      return error is ApiException && error.kind == ApiErrorKind.rateLimited
          ? CodeRequestOutcome.rateLimited
          : CodeRequestOutcome.failed;
    }
  }

  void backToPhone() => _update(
    (s) => s.copyWith(step: ForgotPasswordStep.phone, clearError: true),
  );

  void showResetStep() => _update(
    (s) => s.copyWith(step: ForgotPasswordStep.reset, clearError: true),
  );

  /// Change le mot de passe ; false si le serveur refuse (erreur dans l'état).
  Future<bool> confirm({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    _update((s) => s.copyWith(busy: true, clearError: true));
    try {
      await _repository.resetPassword(
        phoneNumber: phone,
        code: code,
        newPassword: newPassword,
      );
      _update((s) => s.copyWith(busy: false));
      return true;
    } catch (error) {
      _update((s) => s.copyWith(busy: false, error: error));
      return false;
    }
  }
}
