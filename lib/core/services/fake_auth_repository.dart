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

  AppUser? get currentUser => _currentUser;

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
    return newUser;
  }

  void logout() {
    _currentUser = null;
  }
}