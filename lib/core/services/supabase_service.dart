import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._internal();
  static final SupabaseService instance = SupabaseService._internal();

  /// Cambiar por la URL real de tu proyecto de Supabase
  static const String supabaseUrl = 'https://wtwzidvnevimyfrlhbz.supabase.co';

  /// Cambiar por la Anon Key real de tu proyecto de Supabase
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind0d3ppZHZuZXZpdm15ZnJsaGJ6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA5OTIyMjEsImV4cCI6MjA5NjU2ODIyMX0.OLqfKJznTKd4QcSMo9PupEK5kJWtt4b-QKfWUySlYNs';

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
      await Supabase.instance.client.rpc('upsert_fcm_token', params: {
        'p_email': emailClean,
        'p_fcm_token': token,
      });
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
      await Supabase.instance.client.rpc('upsert_fcm_token', params: {
        'p_email': emailClean,
        'p_fcm_token': null,
      });
      developer.log('Token FCM removido de Supabase para el usuario: $emailClean');
    } catch (e) {
      developer.log('Error al remover FCM token en Supabase: $e');
    }
  }
}
