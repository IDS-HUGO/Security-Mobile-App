import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class UsbDebuggingGuardService {
  static const MethodChannel _channel = MethodChannel(
    'appmobile_security/usb_debugging',
  );

  Future<bool> shouldBlockApp() async {
    if (kDebugMode) {
      return false;
    }

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }

    try {
      final bool? isUsbDebuggingEnabled = await _channel.invokeMethod<bool>(
        'isUsbDebuggingEnabled',
      );
      return isUsbDebuggingEnabled ?? false;
    } on PlatformException catch (error) {
      debugPrint('Error al validar Depuracion USB: ${error.message}');
      return true;
    } on MissingPluginException catch (error) {
      debugPrint('Canal nativo no disponible: $error');
      return true;
    }
  }

  Future<void> closeApp() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _channel.invokeMethod<void>('closeApp');
        return;
      }
    } on PlatformException catch (error) {
      debugPrint('No se pudo cerrar desde Android nativo: ${error.message}');
    } on MissingPluginException catch (error) {
      debugPrint('Canal nativo no disponible al cerrar: $error');
    }

    await SystemNavigator.pop();
  }
}
