import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/session_data.dart';
import '../models/app_user.dart';
import 'fake_auth_repository.dart';
import 'inactivity_monitor.dart';
import 'secure_session_store.dart';
import 'supabase_service.dart';
import 'firebase_messaging_service.dart';

/// Motivo y momento del cierre de una sesion.
class SessionExpiry {
  const SessionExpiry({required this.reason, required this.at});

  final String reason;
  final DateTime at;

  bool get byInactivity => reason == 'inactivity';
}

/// Coordina el ciclo de vida de la sesion autenticada:
///
///  * genera/lee el token desde [FakeAuthRepository];
///  * arranca el [InactivityMonitor] y lo reinicia con cada interaccion;
///  * persiste el token y las variables de tiempo en el almacen encriptado
///    ([SecureSessionStore]) al iniciar y al cerrar la sesion;
///  * al detectar inactividad, cierra la sesion y notifica a la UI por medio
///    de [expiry] para que pueda navegar al login.
class SessionManager {
  SessionManager._internal();

  static final SessionManager instance = SessionManager._internal();

  /// Ventana de inactividad. Para la practica son 15 segundos.
  static const Duration inactivityTimeout = Duration(seconds: 15);

  /// Cada cuanto, como maximo, se persiste la marca de ultima actividad.
  static const Duration _activityPersistInterval = Duration(seconds: 5);

  final SecureSessionStore _store = SecureSessionStore();
  final FakeAuthRepository _auth = FakeAuthRepository.instance;

  /// Tiempo restante antes del cierre por inactividad (para la UI).
  final ValueNotifier<Duration> remaining = ValueNotifier<Duration>(
    Duration.zero,
  );

  /// Ultimo evento de expiracion. La UI lo observa para reaccionar y luego
  /// lo limpia (`expiry.value = null`).
  final ValueNotifier<SessionExpiry?> expiry =
      ValueNotifier<SessionExpiry?>(null);

  /// Evento de Wipe Remoto. La UI lo observa para forzar la navegación al Login.
  final ValueNotifier<bool> remoteWipeEvent = ValueNotifier<bool>(false);

  InactivityMonitor? _monitor;
  String? _token;
  DateTime? _startedAt;
  DateTime _lastActivityAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastPersistedActivityAt = DateTime.fromMillisecondsSinceEpoch(0);

  bool get hasActiveSession => _monitor != null;

  /// Inicia la sesion tras un login/registro exitoso: persiste el token y las
  /// variables de tiempo en el almacen encriptado y arranca el contador.
  Future<void> startSession() async {
    final DateTime now = DateTime.now();
    _token = _auth.currentToken;
    _startedAt = now;
    _lastActivityAt = now;
    _lastPersistedActivityAt = now;

    await _store.saveSession(
      SessionData(
        token: _token ?? '',
        inactivityTimeout: inactivityTimeout,
        startedAt: now,
        lastActivityAt: now,
      ),
    );

    // Asignación automática de los 4 campos sensibles en el Secure Storage
    final AppUser? user = _auth.currentUser;
    if (user != null) {
      await _store.saveSensitiveFields(
        username: user.name,
        password: user.password,
        email: user.email,
        token: _token ?? '',
      );

      // Sincronizar el Token FCM con Supabase
      final String? fcmToken = FirebaseMessagingService.instance.fcmToken.value;
      await SupabaseService.instance.syncFcmToken(user.email, fcmToken);
    }

    _monitor?.dispose();
    _monitor = InactivityMonitor(
      timeout: inactivityTimeout,
      onTimeout: _handleInactivityTimeout,
      onTick: (Duration value) => remaining.value = value,
    )..start();
  }

  /// Limpia los datos de sesión y campos sensibles (Wipe Remoto).
  Future<void> remoteWipe() async {
    _stopMonitor();

    // Obtener el correo del usuario antes de limpiar el Secure Storage para desvincular el token en Supabase
    final Map<String, String?> sensitiveFields = await _store.readSensitiveFields();
    final String? userEmail = sensitiveFields['email'] ?? _auth.currentUser?.email;
    if (userEmail != null) {
      await SupabaseService.instance.clearFcmToken(userEmail);
    }

    _auth.logout();
    _token = null;
    _startedAt = null;
    remaining.value = Duration.zero;

    // Borrar todo el Secure Storage (incluyendo campos sensibles)
    await _store.clear();

    // Emitir evento para la interfaz
    remoteWipeEvent.value = true;
  }

  /// Verifica si ocurrió un wipe en segundo plano y limpia la bandera.
  Future<bool> checkAndClearPendingRemoteWipe() async {
    final pending = await _store.getRemoteWipePending();
    if (pending) {
      await _store.setRemoteWipePending(false);
    }
    return pending;
  }

  /// Expone los campos sensibles del almacenamiento.
  Future<Map<String, String?>> readSensitiveFields() => _store.readSensitiveFields();

  /// Permite re-guardar o asignar manualmente campos sensibles (para pruebas).
  Future<void> saveSensitiveFields({
    required String username,
    required String password,
    required String email,
    required String token,
  }) async {
    await _store.saveSensitiveFields(
      username: username,
      password: password,
      email: email,
      token: token,
    );
  }

  /// Registra una interaccion del usuario: reinicia el contador y, de forma
  /// espaciada, actualiza la marca de ultima actividad en el almacen.
  void recordActivity() {
    final InactivityMonitor? monitor = _monitor;
    if (monitor == null) {
      return;
    }

    final DateTime now = DateTime.now();
    _lastActivityAt = now;
    monitor.reset();

    if (now.difference(_lastPersistedActivityAt) >= _activityPersistInterval) {
      _lastPersistedActivityAt = now;
      // No se espera la escritura para no bloquear el hilo de la interaccion.
      unawaited(_store.updateLastActivity(now));
    }
  }

  /// Cierra la sesion de forma manual (boton de salir): detiene el contador,
  /// limpia la autenticacion y borra la sesion del almacen encriptado.
  Future<void> endSessionManually() async {
    _stopMonitor();

    // Desvincular el token FCM en Supabase antes de borrar datos
    final Map<String, String?> sensitiveFields = await _store.readSensitiveFields();
    final String? userEmail = sensitiveFields['email'] ?? _auth.currentUser?.email;
    if (userEmail != null) {
      await SupabaseService.instance.clearFcmToken(userEmail);
    }

    _auth.logout();
    _token = null;
    _startedAt = null;
    remaining.value = Duration.zero;
    await _store.clear();
  }

  /// Devuelve la sesion guardada en el almacen encriptado (para mostrarla).
  Future<SessionData?> readStoredSession() => _store.read();

  Future<void> _handleInactivityTimeout() async {
    final DateTime closedAt = DateTime.now();
    final DateTime startedAt = _startedAt ?? closedAt;

    _stopMonitor();
    remaining.value = Duration.zero;

    // Requisito: al considerar al usuario inactivo, se cierra la sesion y se
    // guarda el token junto con las variables de tiempo en el almacen
    // encriptado (incluyendo cuando y por que se cerro).
    await _store.saveSession(
      SessionData(
        token: _token ?? _auth.currentToken ?? '',
        inactivityTimeout: inactivityTimeout,
        startedAt: startedAt,
        lastActivityAt: _lastActivityAt,
        closedAt: closedAt,
        closedReason: 'inactivity',
      ),
    );

    _auth.logout();
    _token = null;
    _startedAt = null;

    expiry.value = SessionExpiry(reason: 'inactivity', at: closedAt);
  }

  void _stopMonitor() {
    _monitor?.dispose();
    _monitor = null;
  }
}
