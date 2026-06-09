import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'core/constants/app_routes.dart';
import 'core/services/fake_gps_guard_service.dart';
import 'core/services/session_manager.dart';
import 'core/services/firebase_messaging_service.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/inactivity_detector.dart';
import 'features/home/presentation/views/home_view.dart';
import 'features/login/presentation/views/login_view.dart';
import 'features/register/presentation/views/register_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicialización de Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Inicialización del Servicio de Mensajería (FCM)
  await FirebaseMessagingService.instance.initialize();

  // Inicialización del Servicio de Supabase
  await SupabaseService.instance.initialize();
  
  runApp(const AppMobileSecurity());
}

class AppMobileSecurity extends StatefulWidget {
  const AppMobileSecurity({super.key});

  @override
  State<AppMobileSecurity> createState() => _AppMobileSecurityState();
}

class _AppMobileSecurityState extends State<AppMobileSecurity> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final SessionManager _session = SessionManager.instance;

  @override
  void initState() {
    super.initState();
    _session.expiry.addListener(_onSessionExpired);
    _session.remoteWipeEvent.addListener(_onRemoteWipe);
    
    // Verificar si ocurrió un wipe en segundo plano
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingRemoteWipe();
    });
  }

  @override
  void dispose() {
    _session.expiry.removeListener(_onSessionExpired);
    _session.remoteWipeEvent.removeListener(_onRemoteWipe);
    super.dispose();
  }

  /// Reacciona cuando la sesion expira por inactividad: regresa al login y
  /// avisa al usuario. La sesion ya fue cerrada y persistida por el manager.
  void _onSessionExpired() {
    final SessionExpiry? expiry = _session.expiry.value;
    if (expiry == null) {
      return;
    }
    _session.expiry.value = null; // consume el evento

    _navigatorKey.currentState?.pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
    _messengerKey.currentState
      ?..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Tu sesión se cerró por inactividad.'),
        ),
      );
  }

  /// Reacciona ante un evento de Wipe Remoto recibido en primer plano.
  void _onRemoteWipe() {
    if (_session.remoteWipeEvent.value) {
      _session.remoteWipeEvent.value = false; // consume el evento
      
      // Forzar redirección inmediata al Login
      _navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.login,
        (route) => false,
      );

      // Mostrar diálogo de advertencia e información
      _showWipeDialog(
        'Limpieza Remota (Wipe Remoto)',
        'Se recibió una orden por Firebase (FCM) para tu usuario. '
        'Se han eliminado de forma segura los siguientes campos sensibles del almacenamiento:\n\n'
        '• Usuario\n'
        '• Contraseña\n'
        '• Correo Electrónico\n'
        '• Token de Sesión',
      );
    }
  }

  /// Verifica si hay una notificación de wipe en segundo plano pendiente y la maneja.
  Future<void> _checkPendingRemoteWipe() async {
    final pending = await _session.checkAndClearPendingRemoteWipe();
    if (pending) {
      _navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.login,
        (route) => false,
      );
      _showWipeDialog(
        'Limpieza Remota en Segundo Plano',
        'Se ejecutó una orden de limpieza remota (Wipe Remoto) mientras la aplicación estaba cerrada o en segundo plano.\n\n'
        'Todos tus datos sensibles del almacenamiento seguro han sido borrados de forma segura.',
      );
    }
  }

  /// Muestra un diálogo de advertencia no descartable.
  void _showWipeDialog(String title, String message) {
    final BuildContext? context = _navigatorKey.currentContext;
    if (context == null) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text(
                'Wipe Remoto Activo',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(message),
            ],
          ),
          actions: <Widget>[
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              child: const Text('Entendido'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'App Mobile Security',
      theme: AppTheme.lightTheme,
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      // El detector envuelve todas las rutas; solo reinicia el contador cuando
      // hay una sesion activa (de lo contrario recordActivity es un no-op).
      builder: (context, child) {
        return InactivityDetector(
          onActivity: _session.recordActivity,
          child: child ?? const SizedBox.shrink(),
        );
      },
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
