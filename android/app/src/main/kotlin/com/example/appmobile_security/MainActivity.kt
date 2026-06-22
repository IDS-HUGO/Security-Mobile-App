package com.example.appmobile_security

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val secureScreenChannel = "appmobile_security/secure_screen"
	private val fakeGpsChannel = "appmobile_security/fake_gps"
	private val usbDebuggingChannel = "appmobile_security/usb_debugging"
	private val locationPermissionRequestCode = 3201
	private var pendingFakeGpsResult: MethodChannel.Result? = null

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

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, fakeGpsChannel)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"checkFakeGps" -> checkFakeGps(result)
					else -> result.notImplemented()
				}
			}

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, usbDebuggingChannel)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"isUsbDebuggingEnabled" -> result.success(isUsbDebuggingEnabled())
					"closeApp" -> {
						finishAffinity()
						result.success(null)
					}

					else -> result.notImplemented()
				}
			}
	}

	override fun onRequestPermissionsResult(
		requestCode: Int,
		permissions: Array<out String>,
		grantResults: IntArray,
	) {
		super.onRequestPermissionsResult(requestCode, permissions, grantResults)

		if (requestCode != locationPermissionRequestCode) {
			return
		}

		val result = pendingFakeGpsResult ?: return
		pendingFakeGpsResult = null

		if (hasLocationPermission()) {
			result.success(readFakeGpsStatus())
		} else {
			result.success(
				mapOf(
					"status" to "permission_denied",
					"fakeGpsDetected" to false,
					"message" to "Se necesita permiso de ubicacion para validar Fake GPS.",
				),
			)
		}
	}

	private fun checkFakeGps(result: MethodChannel.Result) {
		if (!hasLocationPermission()) {
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
				pendingFakeGpsResult = result
				requestPermissions(
					arrayOf(
						Manifest.permission.ACCESS_FINE_LOCATION,
						Manifest.permission.ACCESS_COARSE_LOCATION,
					),
					locationPermissionRequestCode,
				)
			} else {
				result.success(readFakeGpsStatus())
			}
			return
		}

		result.success(readFakeGpsStatus())
	}

	private fun hasLocationPermission(): Boolean {
		return if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
			true
		} else {
			checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
				checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
		}
	}

	private fun readFakeGpsStatus(): Map<String, Any> {
		val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager

		return try {
			val providers = locationManager.getProviders(true)
			var hasLocation = false

			for (provider in providers) {
				val location = locationManager.getLastKnownLocation(provider) ?: continue
				hasLocation = true

				if (location.isMockLocation()) {
					return mapOf(
						"status" to "fake_gps_detected",
						"fakeGpsDetected" to true,
						"message" to "La app detecto una ubicacion simulada.",
					)
				}
			}

			if (hasLocation) {
				mapOf(
					"status" to "ok",
					"fakeGpsDetected" to false,
					"message" to "Ubicacion verificada.",
				)
			} else {
				mapOf(
					"status" to "no_location",
					"fakeGpsDetected" to false,
					"message" to "No hay una ubicacion reciente para validar.",
				)
			}
		} catch (_: SecurityException) {
			mapOf(
				"status" to "permission_denied",
				"fakeGpsDetected" to false,
				"message" to "Se necesita permiso de ubicacion para validar Fake GPS.",
			)
		}
	}

	private fun isUsbDebuggingEnabled(): Boolean {
		return Settings.Global.getInt(
			contentResolver,
			Settings.Global.ADB_ENABLED,
			0,
		) == 1
	}

	@Suppress("DEPRECATION")
	private fun Location.isMockLocation(): Boolean {
		return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
			isMock
		} else {
			isFromMockProvider
		}
	}
}
