package com.example.appmobile_security

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val secureScreenChannel = "appmobile_security/secure_screen"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, secureScreenChannel)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"enableSecureMode" -> {
						window.setFlags(
							WindowManager.LayoutParams.FLAG_SECURE,
							WindowManager.LayoutParams.FLAG_SECURE,
						)
						result.success(null)
					}

					"disableSecureMode" -> {
						window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
						result.success(null)
					}

					else -> result.notImplemented()
				}
			}
	}
}
