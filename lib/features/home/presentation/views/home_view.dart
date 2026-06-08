import 'package:flutter/material.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/models/app_user.dart';
import '../../../../core/models/session_data.dart';
import '../../../../core/services/fake_auth_repository.dart';
import '../../../../core/services/session_manager.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late Future<SessionData?> _storedSession;

  @override
  void initState() {
    super.initState();
    _storedSession = SessionManager.instance.readStoredSession();
  }

  Future<void> _logout() async {
    final NavigatorState navigator = Navigator.of(context);
    await SessionManager.instance.endSessionManually();
    navigator.pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

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
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              const Icon(Icons.verified_user_outlined, size: 80),
              const SizedBox(height: 16),
              Text(
                user == null ? 'Bienvenido' : 'Hola, ${user.name}',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                user == null ? 'No hay sesión activa.' : 'Correo: ${user.email}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const _InactivityCountdownCard(),
              const SizedBox(height: 16),
              _SecureStorageCard(storedSession: _storedSession),
            ],
          ),
        ),
      ),
    );
  }
}

/// Muestra en vivo el tiempo restante antes del cierre por inactividad.
class _InactivityCountdownCard extends StatelessWidget {
  const _InactivityCountdownCard();

  @override
  Widget build(BuildContext context) {
    final int timeoutSeconds = SessionManager.inactivityTimeout.inSeconds;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.timer_outlined),
                SizedBox(width: 8),
                Text(
                  'Cierre por inactividad',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'La sesión se cierra tras $timeoutSeconds s sin interacción.',
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<Duration>(
              valueListenable: SessionManager.instance.remaining,
              builder: (context, remaining, _) {
                final int seconds = remaining.inSeconds;
                final bool urgent = seconds <= 5;
                return Row(
                  children: [
                    const Text('Tiempo restante: '),
                    Text(
                      '$seconds s',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: urgent
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Lee y muestra lo que quedo guardado en el almacen encriptado, para
/// evidenciar que el token y las variables de tiempo se persisten y leen.
class _SecureStorageCard extends StatelessWidget {
  const _SecureStorageCard({required this.storedSession});

  final Future<SessionData?> storedSession;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.lock_outline),
                SizedBox(width: 8),
                Text(
                  'Almacén encriptado',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<SessionData?>(
              future: storedSession,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final SessionData? session = snapshot.data;
                if (session == null) {
                  return const Text('No hay sesión almacenada.');
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(label: 'Token', value: _maskToken(session.token)),
                    _InfoRow(
                      label: 'Timeout',
                      value: '${session.inactivityTimeout.inSeconds} s',
                    ),
                    _InfoRow(
                      label: 'Inicio',
                      value: _formatTime(session.startedAt),
                    ),
                    _InfoRow(
                      label: 'Última actividad',
                      value: _formatTime(session.lastActivityAt),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _maskToken(String token) {
    if (token.length <= 14) {
      return token;
    }
    return '${token.substring(0, 14)}…';
  }

  String _formatTime(DateTime time) {
    final DateTime local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
