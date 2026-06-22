// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

const String supabaseUrl = 'https://wtwzidvnevimyfrlhbz.supabase.co';
const String serviceRoleKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind0d3ppZHZuZXZpdm15ZnJsaGJ6Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MDk5MjIyMSwiZXhwIjoyMDk2NTY4MjIxfQ.UtShtCBFS7yhYyGMAaE1EO7Ai0ajxdE4OOV72IEtTBY';

void printUsage() {
  print('Uso del script de Wipe Remoto:');
  print('  dart run bin/send_wipe.dart --email <correo> --server-key <firebase_server_key> [--word <palabra>]');
  print('');
  print('Parámetros:');
  print('  --email       El correo electrónico del usuario cuyo dispositivo deseas limpiar.');
  print('  --server-key  La clave del servidor de Firebase (Legacy Server Key) disponible en Firebase Console.');
  print('  --word        (Opcional) La palabra clave de activación. Por defecto es "aguacate".');
  print('');
  print('Nota: Para habilitar y obtener la Legacy Server Key:');
  print('  1. Ve a Firebase Console > Configuración del Proyecto > Cloud Messaging.');
  print('  2. Si "Cloud Messaging API (Legacy)" está inhabilitado, haz clic en los tres puntos y ve a Google Cloud Console para habilitarlo.');
  print('  3. Copia la clave de servidor resultante.');
}

Future<void> main(List<String> arguments) async {
  String? targetEmail;
  String? firebaseServerKey;
  String triggerWord = 'aguacate';

  for (int i = 0; i < arguments.length; i++) {
    if (arguments[i] == '--email' && i + 1 < arguments.length) {
      targetEmail = arguments[i + 1].trim().toLowerCase();
    } else if (arguments[i] == '--server-key' && i + 1 < arguments.length) {
      firebaseServerKey = arguments[i + 1].trim();
    } else if (arguments[i] == '--word' && i + 1 < arguments.length) {
      triggerWord = arguments[i + 1].trim().toLowerCase();
    }
  }

  if (targetEmail == null || firebaseServerKey == null) {
    print('Error: Faltan parámetros requeridos.\n');
    printUsage();
    exit(1);
  }

  print('====================================================');
  print('Iniciando Wipe Remoto para el usuario: $targetEmail');
  print('Palabra clave: $triggerWord');
  print('====================================================');

  final client = HttpClient();

  try {
    // 1. Consultar el FCM Token en Supabase usando la API REST y service_role
    final supabaseUri = Uri.parse('$supabaseUrl/rest/v1/user_devices?email=eq.$targetEmail');
    print('Consultando token FCM en Supabase...');
    
    final request = await client.getUrl(supabaseUri);
    request.headers.add('apikey', serviceRoleKey);
    request.headers.add('Authorization', 'Bearer $serviceRoleKey');
    
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode != 200) {
      print('Error al consultar Supabase (Código ${response.statusCode}): $responseBody');
      exit(1);
    }

    final List<dynamic> jsonList = jsonDecode(responseBody) as List<dynamic>;
    if (jsonList.isEmpty) {
      print('Error: No se encontró ningún dispositivo registrado para el correo "$targetEmail" en Supabase.');
      exit(1);
    }

    final deviceData = jsonList.first as Map<String, dynamic>;
    final String? fcmToken = deviceData['fcm_token'] as String?;

    if (fcmToken == null || fcmToken.isEmpty) {
      print('Error: El usuario "$targetEmail" está registrado pero no tiene un token FCM asociado (fcm_token es null o vacío).');
      exit(1);
    }

    print('Token FCM encontrado: ${fcmToken.substring(0, min(25, fcmToken.length))}...');

    // 2. Enviar la notificación push a Firebase FCM usando la API heredada
    print('Enviando notificación FCM...');
    final fcmUri = Uri.parse('https://fcm.googleapis.com/fcm/send');
    final fcmRequest = await client.postUrl(fcmUri);
    
    fcmRequest.headers.contentType = ContentType.json;
    fcmRequest.headers.add('Authorization', 'key=$firebaseServerKey');

    final payload = {
      'to': fcmToken,
      'notification': {
        'title': '⚠️ Comando de Seguridad',
        'body': 'Se ha detonado una limpieza remota de datos ($triggerWord).',
        'sound': 'default',
      },
      'data': {
        'action': 'wipe',
        'word': triggerWord,
        'target_email': targetEmail,
      },
      'priority': 'high',
    };

    fcmRequest.write(jsonEncode(payload));
    final fcmResponse = await fcmRequest.close();
    final fcmResponseBody = await fcmResponse.transform(utf8.decoder).join();

    if (fcmResponse.statusCode == 200) {
      final Map<String, dynamic> fcmResult = jsonDecode(fcmResponseBody) as Map<String, dynamic>;
      if (fcmResult['success'] == 1) {
        print('\n✅ ¡Éxito! Notificación de Wipe Remoto enviada exitosamente al dispositivo.');
        print('Respuesta FCM: $fcmResponseBody');
      } else {
        print('\n❌ Error devuelto por FCM: $fcmResponseBody');
        exit(1);
      }
    } else {
      print('\n❌ Error HTTP al comunicarse con FCM (Código ${fcmResponse.statusCode}): $fcmResponseBody');
      exit(1);
    }

  } catch (e) {
    print('Ocurrió un error inesperado durante el proceso: $e');
    exit(1);
  } finally {
    client.close();
  }
}

int min(int a, int b) => a < b ? a : b;
