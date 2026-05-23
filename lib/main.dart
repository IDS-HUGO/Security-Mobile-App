import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/home/presentation/views/home_view.dart';
import 'features/login/presentation/views/login_view.dart';
import 'features/register/presentation/views/register_view.dart';

void main() {
  runApp(const AppMobileSecurity());
}

class AppMobileSecurity extends StatelessWidget {
  const AppMobileSecurity({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'App Mobile Security',
      theme: AppTheme.lightTheme,
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginView(),
        '/register': (_) => const RegisterView(),
        '/home': (_) => const HomeView(),
      },
    );
  }
}