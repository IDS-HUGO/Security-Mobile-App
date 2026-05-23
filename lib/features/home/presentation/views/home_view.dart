import 'package:flutter/material.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/models/app_user.dart';
import '../../../../core/services/fake_auth_repository.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final Object? arguments = ModalRoute.of(context)?.settings.arguments;
    final AppUser? user = arguments is AppUser
        ? arguments
        : FakeAuthRepository.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            onPressed: () {
              FakeAuthRepository.instance.logout();
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.login,
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_user_outlined, size: 80),
              const SizedBox(height: 16),
              Text(
                user == null ? 'Bienvenido' : 'Hola, ${user.name}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                user == null
                    ? 'No hay sesión activa.'
                    : 'Correo: ${user.email}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const Text(
                'Esta pantalla usa datos simulados para probar el flujo de autenticación.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}