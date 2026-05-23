import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

mixin SecureScreenMixin<T extends StatefulWidget> on State<T> {
  static const MethodChannel _channel = MethodChannel('appmobile_security/secure_screen');

  @override
  void initState() {
    super.initState();
    unawaited(_enableSecureMode());
  }

  @override
  void dispose() {
    unawaited(_disableSecureMode());
    super.dispose();
  }

  Future<void> _enableSecureMode() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    await _channel.invokeMethod<void>('enableSecureMode');
  }

  Future<void> _disableSecureMode() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    await _channel.invokeMethod<void>('disableSecureMode');
  }
}