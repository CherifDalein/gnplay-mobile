import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../domain/auth_rules.dart';

/// Compte à rebours avant de pouvoir redemander un code.
///
/// Décompte seconde par seconde ; au retour au premier plan, il se recale sur
/// l'heure réelle (un minuteur peut être suspendu quand l'app est en
/// arrière-plan, et l'utilisateur attendrait pour rien).
class ResendCountdown extends ChangeNotifier with WidgetsBindingObserver {
  Timer? _timer;
  DateTime? _deadline;
  int _remaining = 0;
  bool _observing = false;

  /// Secondes restantes (0 = renvoi possible).
  int get remaining => _remaining;

  bool get isRunning => _remaining > 0;

  /// (Re)démarre le décompte.
  void start([int seconds = otpResendSeconds]) {
    _timer?.cancel();
    _remaining = seconds;
    _deadline = DateTime.now().add(Duration(seconds: seconds));
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _remaining = _remaining > 0 ? _remaining - 1 : 0;
      if (_remaining == 0) _stopTimer();
      notifyListeners();
    });
    notifyListeners();
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final deadline = _deadline;
    if (state != AppLifecycleState.resumed || deadline == null || !isRunning) {
      return;
    }
    final left = (deadline.difference(DateTime.now()).inMilliseconds / 1000)
        .ceil();
    if (left < _remaining) {
      _remaining = left < 0 ? 0 : left;
      if (_remaining == 0) _stopTimer();
      notifyListeners();
    }
  }

  /// `01:00`, `00:45`…
  static String format(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final rest = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$rest';
  }

  @override
  void dispose() {
    _stopTimer();
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
