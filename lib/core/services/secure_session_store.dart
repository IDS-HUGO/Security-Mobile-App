import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/session_data.dart';

/// Encapsula el acceso al almacen encriptado del sistema operativo.
///
/// En Android usa `EncryptedSharedPreferences` (AES) respaldado por el Android
/// Keystore y en iOS usa el Keychain. Aqui se guarda el token de la sesion y
/// las variables de tiempo (timeout configurado y marcas de actividad/cierre).
class SecureSessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;

  // Cada dato se guarda en una clave independiente para que el token y las
  // variables de tiempo sean inspeccionables por separado dentro del almacen.
  static const String _kToken = 'auth_token';
  static const String _kTimeoutSeconds = 'inactivity_timeout_seconds';
  static const String _kStartedAt = 'session_started_at';
  static const String _kLastActivityAt = 'last_activity_at';
  static const String _kClosedAt = 'session_closed_at';
  static const String _kClosedReason = 'session_closed_reason';

  // Campos sensibles requeridos por la práctica
  static const String _kSensitiveUsername = 'sensitive_username';
  static const String _kSensitivePassword = 'sensitive_password';
  static const String _kSensitiveEmail = 'sensitive_email';
  static const String _kSensitiveSessionToken = 'sensitive_session_token';
  static const String _kRemoteWipePending = 'remote_wipe_pending_notification';

  /// Guarda los 4 campos considerados sensibles.
  Future<void> saveSensitiveFields({
    required String username,
    required String password,
    required String email,
    required String token,
  }) async {
    await Future.wait<void>([
      _storage.write(key: _kSensitiveUsername, value: username),
      _storage.write(key: _kSensitivePassword, value: password),
      _storage.write(key: _kSensitiveEmail, value: email),
      _storage.write(key: _kSensitiveSessionToken, value: token),
    ]);
  }

  /// Lee los campos sensibles guardados.
  Future<Map<String, String?>> readSensitiveFields() async {
    final results = await Future.wait([
      _storage.read(key: _kSensitiveUsername),
      _storage.read(key: _kSensitivePassword),
      _storage.read(key: _kSensitiveEmail),
      _storage.read(key: _kSensitiveSessionToken),
    ]);
    return {
      'username': results[0],
      'password': results[1],
      'email': results[2],
      'session_token': results[3],
    };
  }

  /// Escribe la bandera para notificar un wipe en segundo plano.
  Future<void> setRemoteWipePending(bool pending) {
    return _storage.write(
      key: _kRemoteWipePending,
      value: pending ? 'true' : 'false',
    );
  }

  /// Lee la bandera de wipe en segundo plano.
  Future<bool> getRemoteWipePending() async {
    final value = await _storage.read(key: _kRemoteWipePending);
    return value == 'true';
  }

  /// Guarda (o sobrescribe) la sesion completa en el almacen encriptado.
  Future<void> saveSession(SessionData session) async {
    await Future.wait<void>([
      _storage.write(key: _kToken, value: session.token),
      _storage.write(
        key: _kTimeoutSeconds,
        value: session.inactivityTimeout.inSeconds.toString(),
      ),
      _storage.write(
        key: _kStartedAt,
        value: session.startedAt.toIso8601String(),
      ),
      _storage.write(
        key: _kLastActivityAt,
        value: session.lastActivityAt.toIso8601String(),
      ),
      _writeOrDelete(_kClosedAt, session.closedAt?.toIso8601String()),
      _writeOrDelete(_kClosedReason, session.closedReason),
    ]);
  }

  /// Actualiza solo la marca de la ultima interaccion del usuario.
  Future<void> updateLastActivity(DateTime when) {
    return _storage.write(
      key: _kLastActivityAt,
      value: when.toIso8601String(),
    );
  }

  /// Lee la sesion almacenada. Devuelve `null` si no hay token guardado.
  Future<SessionData?> read() async {
    final String? token = await _storage.read(key: _kToken);
    if (token == null || token.isEmpty) {
      return null;
    }

    final int timeoutSeconds =
        int.tryParse(await _storage.read(key: _kTimeoutSeconds) ?? '') ?? 0;
    final DateTime? startedAt =
        DateTime.tryParse(await _storage.read(key: _kStartedAt) ?? '');
    final DateTime? lastActivityAt =
        DateTime.tryParse(await _storage.read(key: _kLastActivityAt) ?? '');
    final DateTime? closedAt =
        DateTime.tryParse(await _storage.read(key: _kClosedAt) ?? '');
    final String? closedReason = await _storage.read(key: _kClosedReason);

    final DateTime resolvedStart = startedAt ?? lastActivityAt ?? closedAt!;
    return SessionData(
      token: token,
      inactivityTimeout: Duration(seconds: timeoutSeconds),
      startedAt: resolvedStart,
      lastActivityAt: lastActivityAt ?? resolvedStart,
      closedAt: closedAt,
      closedReason: closedReason,
    );
  }

  /// Borra por completo la sesion y los datos sensibles del almacen encriptado.
  Future<void> clear() async {
    await Future.wait<void>([
      _storage.delete(key: _kToken),
      _storage.delete(key: _kTimeoutSeconds),
      _storage.delete(key: _kStartedAt),
      _storage.delete(key: _kLastActivityAt),
      _storage.delete(key: _kClosedAt),
      _storage.delete(key: _kClosedReason),
      _storage.delete(key: _kSensitiveUsername),
      _storage.delete(key: _kSensitivePassword),
      _storage.delete(key: _kSensitiveEmail),
      _storage.delete(key: _kSensitiveSessionToken),
    ]);
  }

  Future<void> _writeOrDelete(String key, String? value) {
    if (value == null) {
      return _storage.delete(key: key);
    }
    return _storage.write(key: key, value: value);
  }
}
