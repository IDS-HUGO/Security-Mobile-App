import 'dart:async';

import 'package:flutter/foundation.dart';

/// Cuenta regresiva de inactividad.
///
/// Cada interaccion del usuario debe llamar a [reset]. Si transcurre
/// [timeout] sin reinicios, se invoca [onTimeout]. Mientras corre, notifica
/// el tiempo restante mediante [onTick] (en cada paso de [tick]) para que la
/// interfaz pueda mostrar la cuenta en vivo.
///
/// Esta implementacion es dirigida unicamente por un [Timer] periodico (no usa
/// el reloj del sistema), por lo que es deterministica y facil de probar.
class InactivityMonitor {
  InactivityMonitor({
    required this.timeout,
    required this.onTimeout,
    this.onTick,
    this.tick = const Duration(seconds: 1),
  });

  /// Ventana de inactividad permitida.
  final Duration timeout;

  /// Se ejecuta cuando se agota el tiempo sin interaccion.
  final Future<void> Function() onTimeout;

  /// Reporta el tiempo restante (para la UI).
  final ValueChanged<Duration>? onTick;

  /// Resolucion de la cuenta regresiva.
  final Duration tick;

  Timer? _ticker;
  Duration _remaining = Duration.zero;
  bool _disposed = false;

  /// Inicia (o reinicia) la cuenta regresiva.
  void start() => reset();

  /// Reinicia la cuenta regresiva tras una interaccion del usuario.
  void reset() {
    if (_disposed) {
      return;
    }

    _remaining = timeout;
    onTick?.call(_remaining);
    _ticker ??= Timer.periodic(tick, (_) => _onTick());
  }

  void _onTick() {
    _remaining -= tick;

    if (_remaining <= Duration.zero) {
      _remaining = Duration.zero;
      onTick?.call(_remaining);
      _stopTicker();
      onTimeout();
      return;
    }

    onTick?.call(_remaining);
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  /// Detiene el timer y libera los recursos.
  void dispose() {
    _disposed = true;
    _stopTicker();
  }
}
