import 'dart:developer' as developer;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'secure_session_store.dart';
import 'session_manager.dart';
import 'supabase_service.dart';
import 'fake_auth_repository.dart';

/// Valida si el mensaje recibido debe detonar un Wipe Remoto.
/// Verifica la palabra clave "aguacate" y que el destinatario sea el correcto.
bool _shouldTriggerWipe(RemoteMessage message, String? currentUserEmail) {
  final data = message.data;
  const String triggerWord = 'aguacate';
  bool hasTriggerWord = false;

  // 1. Buscar la palabra clave en el Data Payload
  final keysToCheck = ['trigger_word', 'word', 'message', 'action'];
  for (final key in keysToCheck) {
    if (data.containsKey(key) &&
        data[key].toString().toLowerCase().contains(triggerWord)) {
      hasTriggerWord = true;
      break;
    }
  }

  // 2. Buscar la palabra clave en el Notification Payload
  final notification = message.notification;
  if (notification != null) {
    if (notification.title?.toLowerCase().contains(triggerWord) ?? false) {
      hasTriggerWord = true;
    }
    if (notification.body?.toLowerCase().contains(triggerWord) ?? false) {
      hasTriggerWord = true;
    }
  }

  if (!hasTriggerWord) {
    developer.log('Wipe FCM ignorado: no contiene la palabra clave "$triggerWord".');
    return false;
  }

  // 3. Validar si está dirigido a un usuario específico
  final targetEmail = data['target_email'];
  if (targetEmail != null && targetEmail.toString().isNotEmpty) {
    if (currentUserEmail == null ||
        currentUserEmail.toLowerCase() != targetEmail.toString().toLowerCase().trim()) {
      developer.log(
        'Wipe FCM ignorado: el usuario de destino ($targetEmail) no coincide con el logueado ($currentUserEmail).',
      );
      return false;
    }
  }

  return true;
}

/// Handler para mensajes de FCM en segundo plano o cuando la aplicación está cerrada.
/// Debe ser una función global/top-level y estar decorada con @pragma('vm:entry-point').
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Inicializar Firebase para este isolate de segundo plano
  await Firebase.initializeApp();
  
  developer.log('Mensaje de FCM recibido en segundo plano: ${message.data}');
  
  final store = SecureSessionStore();
  final sensitiveFields = await store.readSensitiveFields();
  final userEmail = sensitiveFields['email'];
  
  if (_shouldTriggerWipe(message, userEmail)) {
    // Limpiar el token de Supabase en segundo plano si es posible
    if (userEmail != null) {
      // Intentar inicializar Supabase para limpiar el token
      await SupabaseService.instance.initialize();
      await SupabaseService.instance.clearFcmToken(userEmail);
    }

    // Realizar limpieza de datos localmente
    await store.clear();
    // Dejar la bandera para que la UI notifique al usuario en el siguiente inicio/resumen
    await store.setRemoteWipePending(true);
    developer.log('Wipe Remoto completado con éxito en segundo plano.');
  }
}

class FirebaseMessagingService {
  FirebaseMessagingService._internal();
  static final FirebaseMessagingService instance = FirebaseMessagingService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final ValueNotifier<String?> fcmToken = ValueNotifier<String?>(null);

  /// Inicializa Firebase Messaging y registra los callbacks
  Future<void> initialize() async {
    // Solicitar permisos de notificación (requerido para iOS y Android 13+)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    developer.log('Permisos de notificación: ${settings.authorizationStatus}');

    // Configurar el handler de segundo plano
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Obtener el token FCM actual
    try {
      final token = await _messaging.getToken();
      fcmToken.value = token;
      developer.log('Token FCM Inicializado: $token');
    } catch (e) {
      developer.log('Error al obtener el Token FCM: $e');
    }

    // Escuchar actualizaciones del token
    _messaging.onTokenRefresh.listen((token) {
      fcmToken.value = token;
      developer.log('Token FCM Renovado: $token');
      // Sincronizar con Supabase si hay un usuario activo
      final user = FakeAuthRepository.instance.currentUser;
      if (user != null) {
        SupabaseService.instance.syncFcmToken(user.email, token);
      }
    });

    // Configurar handler de mensajes en primer plano (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      developer.log('Mensaje de FCM recibido en primer plano: ${message.data}');
      
      final fields = await SessionManager.instance.readSensitiveFields();
      final userEmail = fields['email'];
      
      if (_shouldTriggerWipe(message, userEmail)) {
        developer.log('Detonando Wipe Remoto en primer plano...');
        await SessionManager.instance.remoteWipe();
      }
    });
  }
}

