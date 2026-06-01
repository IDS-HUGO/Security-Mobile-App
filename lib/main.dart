import 'package:flutter/material.dart';

import 'core/constants/app_routes.dart';
import 'core/services/fake_gps_guard_service.dart';
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
      home: const FakeGpsGate(),
      routes: {
        AppRoutes.login: (_) => const LoginView(),
        AppRoutes.register: (_) => const RegisterView(),
        AppRoutes.home: (_) => const HomeView(),
      },
    );
  }
}

class FakeGpsGate extends StatefulWidget {
  const FakeGpsGate({super.key});

  @override
  State<FakeGpsGate> createState() => _FakeGpsGateState();
}

class _FakeGpsGateState extends State<FakeGpsGate> {
  final FakeGpsGuardService _guardService = FakeGpsGuardService();
  late Future<FakeGpsCheckResult> _checkFuture;

  @override
  void initState() {
    super.initState();
    _checkFuture = _guardService.checkFakeGps();
  }

  void _retryCheck() {
    setState(() {
      _checkFuture = _guardService.checkFakeGps();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FakeGpsCheckResult>(
      future: _checkFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _StartupStatusView(
            icon: Icons.location_searching,
            title: 'Validando ubicacion',
            message: 'Revisando si el dispositivo usa Fake GPS...',
          );
        }

        final result = snapshot.data ?? FakeGpsCheckResult.error;
        if (result.fakeGpsDetected) {
          return _StartupStatusView(
            icon: Icons.gps_off,
            title: 'Fake GPS detectado',
            message:
                'La aplicacion no puede ejecutarse mientras haya una ubicacion simulada activa.',
            actionLabel: 'Volver a validar',
            onActionPressed: _retryCheck,
          );
        }

        if (result.requiresLocationPermission) {
          return _StartupStatusView(
            icon: Icons.location_disabled,
            title: 'Permiso requerido',
            message:
                'Activa el permiso de ubicacion para comprobar que no usas Fake GPS.',
            actionLabel: 'Intentar de nuevo',
            onActionPressed: _retryCheck,
          );
        }

        return const LoginView();
      },
    );
  }
}

class _StartupStatusView extends StatelessWidget {
  const _StartupStatusView({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onActionPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 72),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                  ),
                  if (actionLabel != null && onActionPressed != null) ...[
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: onActionPressed,
                      child: Text(actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
