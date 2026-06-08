/// Datos de la sesion que se guardan en el almacen encriptado.
///
/// Contiene el token de autenticacion y las variables de tiempo que permiten
/// auditar cuando inicio la sesion, cuando fue la ultima interaccion y, si
/// aplica, cuando y por que se cerro (por ejemplo, por inactividad).
class SessionData {
  const SessionData({
    required this.token,
    required this.inactivityTimeout,
    required this.startedAt,
    required this.lastActivityAt,
    this.closedAt,
    this.closedReason,
  });

  /// Token de la sesion autenticada.
  final String token;

  /// Ventana de inactividad permitida antes de cerrar la sesion.
  final Duration inactivityTimeout;

  /// Momento en que se abrio la sesion.
  final DateTime startedAt;

  /// Ultima interaccion registrada del usuario.
  final DateTime lastActivityAt;

  /// Momento en que se cerro la sesion (null mientras siga activa).
  final DateTime? closedAt;

  /// Motivo del cierre, por ejemplo `inactivity` o `manual`.
  final String? closedReason;

  bool get wasClosedByInactivity => closedReason == 'inactivity';

  SessionData copyWith({
    String? token,
    Duration? inactivityTimeout,
    DateTime? startedAt,
    DateTime? lastActivityAt,
    DateTime? closedAt,
    String? closedReason,
  }) {
    return SessionData(
      token: token ?? this.token,
      inactivityTimeout: inactivityTimeout ?? this.inactivityTimeout,
      startedAt: startedAt ?? this.startedAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      closedAt: closedAt ?? this.closedAt,
      closedReason: closedReason ?? this.closedReason,
    );
  }
}
