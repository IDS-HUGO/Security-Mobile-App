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

  /// Borra por completo la sesion del almacen encriptado.
  Future<void> clear() async {
    await Future.wait<void>([
      _storage.delete(key: _kToken),
      _storage.delete(key: _kTimeoutSeconds),
      _storage.delete(key: _kStartedAt),
      _storage.delete(key: _kLastActivityAt),
      _storage.delete(key: _kClosedAt),
      _storage.delete(key: _kClosedReason),
    ]);
  }

  Future<void> _writeOrDelete(String key, String? value) {
    if (value == null) {
      return _storage.delete(key: key);
    }
    return _storage.write(key: key, value: value);
  }
}
