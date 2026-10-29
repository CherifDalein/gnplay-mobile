import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Sondage périodique qu'on allume et qu'on éteint selon une condition.
///
/// L'écran appelle [sync] chaque fois que la condition peut avoir changé
/// (nouvelles données, écran masqué ou de retour) : le minuteur n'existe que
/// tant que [sync] reçoit `true`, il ne tourne jamais « pour rien ».
class RefreshPoller {
  RefreshPoller({required this.interval, required this.onTick});

  final Duration interval;
  final VoidCallback onTick;
  Timer? _timer;

  bool get isRunning => _timer != null;

  void sync(bool shouldRun) {
    if (shouldRun) {
      _timer ??= Timer.periodic(interval, (_) => onTick());
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void dispose() => sync(false);
}

/// Suit la visibilité réelle d'un écran.
///
/// Un onglet du `StatefulShellRoute` reste monté quand on en change, et un
/// écran reste monté sous celui qu'on pousse par-dessus : seul `TickerMode`
/// signale qu'ils sont masqués ou redeviennent visibles.
mixin ScreenVisibility<T extends StatefulWidget> on State<T> {
  ValueListenable<bool>? _visibility;
  bool _wasVisible = true;

  /// L'écran est actuellement visible.
  bool get isScreenVisible => _visibility?.value ?? true;

  /// Appelé quand la visibilité change. Peut survenir pendant la construction
  /// de l'arbre : ne pas modifier de provider directement, différer d'un cadre.
  void onScreenVisibilityChanged(bool visible);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = TickerMode.getNotifier(context);
    if (!identical(notifier, _visibility)) {
      _visibility?.removeListener(_visibilityChanged);
      _visibility = notifier..addListener(_visibilityChanged);
      _wasVisible = notifier.value;
    }
  }

  @override
  void dispose() {
    _visibility?.removeListener(_visibilityChanged);
    super.dispose();
  }

  void _visibilityChanged() {
    final visible = _visibility?.value ?? true;
    if (visible == _wasVisible) return;
    _wasVisible = visible;
    onScreenVisibilityChanged(visible);
  }
}
