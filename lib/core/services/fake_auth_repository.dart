import 'dart:convert';
import 'dart:math';

import '../models/app_user.dart';

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

    final AppUser? foundUser = _users.cast<AppUser?>().firstWhere(
          (AppUser? user) =>
              user != null &&
              user.email.toLowerCase() == email.toLowerCase().trim() &&
              user.password == password,
          orElse: () => null,
        );

    if (foundUser == null) {
      throw Exception('Correo o contraseña incorrectos.');
    }

    _currentUser = foundUser;
    _sessionToken = _generateToken();
    return foundUser;
  }

  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    final bool exists = _users.any(
      (AppUser user) => user.email.toLowerCase() == email.toLowerCase().trim(),
    );

    if (exists) {
      throw Exception('Ya existe un usuario con ese correo.');
    }

    final AppUser newUser = AppUser(
      name: name.trim(),
      email: email.trim(),
      password: password,
    );

    _users.add(newUser);
    _currentUser = newUser;
    _sessionToken = _generateToken();
    return newUser;
  }

  void logout() {
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