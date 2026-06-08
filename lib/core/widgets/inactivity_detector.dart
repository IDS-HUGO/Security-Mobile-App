import 'package:flutter/material.dart';

/// Envuelve la app y avisa de cualquier interaccion del usuario.
///
/// Usa un [Listener], que observa los eventos de puntero sin consumirlos, por
/// lo que no interfiere con botones, scroll ni otros gestos. La logica de
/// sesion decide si esa actividad reinicia el contador de inactividad.
class InactivityDetector extends StatelessWidget {
  const InactivityDetector({
    super.key,
    required this.onActivity,
    required this.child,
  });

  final VoidCallback onActivity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => onActivity(),
      onPointerMove: (_) => onActivity(),
      onPointerUp: (_) => onActivity(),
      onPointerSignal: (_) => onActivity(),
      child: child,
    );
  }
}
