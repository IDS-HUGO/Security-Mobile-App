import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._internal();
  static final SupabaseService instance = SupabaseService._internal();

  /// Cambiar por la URL real de tu proyecto de Supabase
  static const String supabaseUrl = 'https://tu-proyecto.supabase.co';

  /// Cambiar por la Anon Key real de tu proyecto de Supabase
  static const String supabaseAnonKey = 'tu-anon-key-de-supabase';

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Verifica si el usuario ha configurado las credenciales reales
  bool get isConfigured {
    return supabaseUrl != 'https://tu-proyecto.supabase.co' &&
        supabaseAnonKey != 'tu-anon-key-de-supabase' &&
        supabaseUrl.isNotEmpty &&
        supabaseAnonKey.isNotEmpty;
  }

  /// Inicializa el cliente de Supabase
  Future<void> initialize() async {
    if (!isConfigured) {
      developer.log('Supabase no está configurado. Utilizando modo simulado.');
      return;
    }

    try {
      await Supabase.initialize(
        url: supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: supabaseAnonKey,
      );
      _initialized = true;
      developer.log('Supabase inicializado exitosamente.');
    } catch (e) {
      _initialized = false;
      developer.log('Error al inicializar Supabase: $e');
    }
  }

  /// Registra o actualiza el FCM Token del usuario activo en la base de datos de Supabase
  Future<void> syncFcmToken(String email, String? token) async {
    if (!_initialized) {
      developer.log(
        'Sincronización Supabase (Simulada): Guardando token FCM para "$email" -> $token',
      );
      return;
    }

    try {
      final emailClean = email.toLowerCase().trim();
      await Supabase.instance.client.from('user_devices').upsert({
        'email': emailClean,
        'fcm_token': token,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'email');
      developer.log('Token FCM sincronizado con Supabase para el usuario: $emailClean');
    } catch (e) {
      developer.log('Error al sincronizar FCM token en Supabase: $e');
    }
  }

  /// Borra el Token FCM de Supabase para un usuario al cerrar sesión o hacer wipe
  Future<void> clearFcmToken(String email) async {
    if (!_initialized) {
      developer.log(
        'Sincronización Supabase (Simulada): Limpiando token FCM para "$email"',
      );
      return;
    }

    try {
      final emailClean = email.toLowerCase().trim();
      await Supabase.instance.client
          .from('user_devices')
          .update({'fcm_token': null})
          .eq('email', emailClean);
      developer.log('Token FCM removido de Supabase para el usuario: $emailClean');
    } catch (e) {
      developer.log('Error al remover FCM token en Supabase: $e');
    }
  }
}
