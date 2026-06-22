import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_user.dart';
import 'supabase_service.dart';

class FakeAuthRepository {
  FakeAuthRepository._internal();

  static final FakeAuthRepository instance = FakeAuthRepository._internal();

  final List<AppUser> _users = <AppUser>[
    const AppUser(
      name: 'Usuario Demo',
      email: 'demo@demo.com',
      password: '123456',
    ),
  ];

  AppUser? _currentUser;
  String? _sessionToken;

  AppUser? get currentUser => _currentUser;

  /// Token de la sesion autenticada actual (null si no hay sesion).
  String? get currentToken => _sessionToken;

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final String emailClean = email.toLowerCase().trim();

    // Intentar autenticación real con Supabase si está disponible
    if (SupabaseService.instance.isInitialized) {
      try {
        final AuthResponse response = await Supabase.instance.client.auth.signInWithPassword(
          email: emailClean,
          password: password,
        );
        if (response.user != null) {
          final String name = response.user!.userMetadata?['name'] ?? 'Usuario Supabase';
          final AppUser user = AppUser(
            name: name,
            email: response.user!.email ?? emailClean,
            password: password,
          );
          _currentUser = user;
          _sessionToken = response.session?.accessToken ?? _generateToken();
          developer.log('Inicio de sesión exitoso en Supabase para: $emailClean');
          return user;
        }
      } catch (e) {
        developer.log('Error login Supabase (se intentará fallback local): $e');
      }
    }

    // Fallback local/simulado
    final AppUser? foundUser = _users.cast<AppUser?>().firstWhere(
          (AppUser? user) =>
              user != null &&
              user.email.toLowerCase() == emailClean &&
              user.password == password,
          orElse: () => null,
        );

    if (foundUser == null) {
      throw Exception('Correo o contraseña incorrectos.');
    }

    _currentUser = foundUser;
    _sessionToken = _generateToken();
    developer.log('Inicio de sesión local exitoso para: $emailClean');
    return foundUser;
  }

  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final String emailClean = email.toLowerCase().trim();
    final String nameClean = name.trim();

    // Intentar registro en Supabase si está disponible
    if (SupabaseService.instance.isInitialized) {
      try {
        final AuthResponse response = await Supabase.instance.client.auth.signUp(
          email: emailClean,
          password: password,
          data: {'name': nameClean},
        );
        if (response.user != null) {
          final AppUser newUser = AppUser(
            name: nameClean,
            email: response.user!.email ?? emailClean,
            password: password,
          );
          _users.add(newUser);
          _currentUser = newUser;
          _sessionToken = response.session?.accessToken ?? _generateToken();
          developer.log('Registro exitoso en Supabase para: $emailClean');
          return newUser;
        }
      } catch (e) {
        developer.log('Error registro Supabase (se intentará fallback local): $e');
      }
    }

    // Registro local/simulado
    final bool exists = _users.any(
      (AppUser user) => user.email.toLowerCase() == emailClean,
    );

    if (exists) {
      throw Exception('Ya existe un usuario con ese correo.');
    }

    final AppUser newUser = AppUser(
      name: nameClean,
      email: emailClean,
      password: password,
    );

    _users.add(newUser);
    _currentUser = newUser;
    _sessionToken = _generateToken();
    developer.log('Registro local exitoso para: $emailClean');
    return newUser;
  }

  void logout() {
    // Si Supabase está inicializado, cerramos sesión de forma asíncrona
    if (SupabaseService.instance.isInitialized) {
      try {
        Supabase.instance.client.auth.signOut();
      } catch (e) {
        developer.log('Error al cerrar sesión en Supabase: $e');
      }
    }
    _currentUser = null;
    _sessionToken = null;
  }

  /// Genera un token de sesion simulado pero criptograficamente aleatorio.
  String _generateToken() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return 'sess_${base64Url.encode(bytes).replaceAll('=', '')}';
  }
}