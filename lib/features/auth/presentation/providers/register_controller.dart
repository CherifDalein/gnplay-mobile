import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/locale/countries.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/repositories.dart';
import '../../data/auth_repository.dart';
import '../../domain/code_request_outcome.dart';
import '../../domain/register_request.dart';
import '../widgets/auth_error_text.dart';
import 'auth_controller.dart';

enum RegisterStep { account, code }

/// Résultat de la création du compte.
enum RegisterOutcome {
  /// Compte créé et connecté : le routeur prend le relais.
  done,

  /// Compte créé mais la connexion automatique a échoué.
  loginFailed,

  /// Code refusé ou création refusée (erreur dans l'état).
  failed,
}

class RegisterFlowState {
  const RegisterFlowState({
    this.step = RegisterStep.account,
    this.busy = false,
    this.error,
    this.codeSentTo,
    this.verifiedPhone,
  });

  final RegisterStep step;
  final bool busy;
  final Object? error;

  /// Numéro (E.164) auquel un code a été envoyé.
  final String? codeSentTo;

  /// Numéro dont le code a déjà été accepté par `verify-otp`. Le code est
  /// consommé à ce moment-là : si `register` échoue ensuite, il ne faut ni le
  /// revérifier (le serveur répondrait « OTP invalide ») ni le redemander.
  final String? verifiedPhone;

  RegisterFlowState copyWith({
    RegisterStep? step,
    bool? busy,
    Object? error,
    bool clearError = false,
    String? codeSentTo,
    String? verifiedPhone,
    bool clearVerified = false,
  }) {
    return RegisterFlowState(
      step: step ?? this.step,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
      codeSentTo: codeSentTo ?? this.codeSentTo,
      verifiedPhone: clearVerified
          ? null
          : (verifiedPhone ?? this.verifiedPhone),
    );
  }
}

final registerControllerProvider =
    StateNotifierProvider.autoDispose<RegisterController, RegisterFlowState>(
      (ref) => RegisterController(ref, ref.watch(authRepositoryProvider)),
    );

/// Déroulé de l'inscription : envoi du code → vérification → création du
/// compte → connexion. L'état (étape, numéro vérifié) survit au retour à
/// l'étape « informations », ce qui permet de corriger le numéro ou de
/// réessayer sans refaire tout le parcours.
class RegisterController extends StateNotifier<RegisterFlowState> {
  RegisterController(this._ref, this._repository)
    : super(const RegisterFlowState());

  final Ref _ref;
  final AuthRepository _repository;

  void _update(RegisterFlowState Function(RegisterFlowState) change) {
    if (mounted) state = change(state);
  }

  /// Demande un code par WhatsApp/SMS ([channel] null : choix du serveur).
  Future<CodeRequestOutcome> sendCode(String phone, {String? channel}) async {
    _update((s) => s.copyWith(busy: true, clearError: true));
    try {
      await _repository.requestRegisterOtp(
        phoneNumber: phone,
        channel: channel,
      );
      _update(
        (s) =>
            s.copyWith(busy: false, step: RegisterStep.code, codeSentTo: phone),
      );
      return CodeRequestOutcome.sent;
    } catch (error) {
      if (isCodeCooldownError(error)) {
        // Un code vient d'être envoyé à ce numéro : il reste valable, on
        // laisse l'utilisateur le saisir plutôt que de le bloquer.
        _update(
          (s) => s.copyWith(
            busy: false,
            error: error,
            step: RegisterStep.code,
            codeSentTo: phone,
          ),
        );
        return CodeRequestOutcome.rateLimited;
      }
      _update((s) => s.copyWith(busy: false, error: error));
      // Limite par IP : pas d'avancée à l'étape du code, mais le compte à
      // rebours repart quand même pour éviter de marteler le serveur.
      return error is ApiException && error.kind == ApiErrorKind.rateLimited
          ? CodeRequestOutcome.rateLimited
          : CodeRequestOutcome.failed;
    }
  }

  /// Retour à l'étape « informations » (corriger le nom ou le numéro).
  void backToAccount() =>
      _update((s) => s.copyWith(step: RegisterStep.account, clearError: true));

  /// Réaffiche l'étape du code sans nouvel envoi (code déjà envoyé à ce
  /// numéro, ou numéro déjà vérifié).
  void showCodeStep(String phone) => _update(
    (s) => s.copyWith(
      step: RegisterStep.code,
      codeSentTo: phone,
      clearError: true,
    ),
  );

  /// Vérifie le code (sauf si le numéro l'est déjà), crée le compte puis
  /// connecte l'utilisateur.
  Future<RegisterOutcome> submit({
    required String fullName,
    required AppCountry country,
    required String phone,
    required String password,
    required String code,
  }) async {
    _update((s) => s.copyWith(busy: true, clearError: true));
    try {
      if (state.verifiedPhone != phone) {
        await _repository.verifyRegisterOtp(phoneNumber: phone, code: code);
        _update((s) => s.copyWith(verifiedPhone: phone));
      }
      await _repository.register(
        RegisterRequest(
          fullName: fullName,
          phoneNumber: phone,
          countryIso2: country.iso2,
          password: password,
        ),
      );
    } catch (error) {
      // Le serveur ne retrouve plus de code validé : il faut en redemander un.
      final lostVerification =
          error is ApiException && error.serverSays('valider votre num');
      _update(
        (s) => s.copyWith(
          busy: false,
          error: error,
          clearVerified: lostVerification,
        ),
      );
      return RegisterOutcome.failed;
    }

    try {
      await _ref
          .read(authControllerProvider.notifier)
          .login(phoneNumber: phone, password: password);
      _update((s) => s.copyWith(busy: false));
      return RegisterOutcome.done;
    } catch (_) {
      _update((s) => s.copyWith(busy: false));
      return RegisterOutcome.loginFailed;
    }
  }
}
