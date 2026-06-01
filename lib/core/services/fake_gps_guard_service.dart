import 'package:flutter/services.dart';

class FakeGpsCheckResult {
  const FakeGpsCheckResult({
    required this.status,
    required this.fakeGpsDetected,
    required this.message,
  });

  final String status;
  final bool fakeGpsDetected;
  final String message;

  bool get requiresLocationPermission => status == 'permission_denied';

  factory FakeGpsCheckResult.fromMap(Map<dynamic, dynamic> map) {
    return FakeGpsCheckResult(
      status: map['status'] as String? ?? 'unknown',
      fakeGpsDetected: map['fakeGpsDetected'] as bool? ?? false,
      message: map['message'] as String? ?? 'No se pudo validar Fake GPS.',
    );
  }

  static const unsupported = FakeGpsCheckResult(
    status: 'unsupported',
    fakeGpsDetected: false,
    message: 'La validacion de Fake GPS solo esta disponible en Android.',
  );

  static const error = FakeGpsCheckResult(
    status: 'error',
    fakeGpsDetected: false,
    message: 'No se pudo completar la validacion de Fake GPS.',
  );
}

class FakeGpsGuardService {
  static const MethodChannel _channel = MethodChannel(
    'appmobile_security/fake_gps',
  );

  Future<FakeGpsCheckResult> checkFakeGps() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'checkFakeGps',
      );

      if (result == null) {
        return FakeGpsCheckResult.error;
      }

      return FakeGpsCheckResult.fromMap(result);
    } on MissingPluginException {
      return FakeGpsCheckResult.unsupported;
    } on PlatformException catch (error) {
      return FakeGpsCheckResult(
        status: error.code,
        fakeGpsDetected: false,
        message: error.message ?? FakeGpsCheckResult.error.message,
      );
    }
  }
}
