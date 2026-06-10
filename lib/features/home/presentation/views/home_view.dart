import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/models/app_user.dart';
import '../../../../core/models/session_data.dart';
import '../../../../core/services/fake_auth_repository.dart';
import '../../../../core/services/session_manager.dart';
import '../../../../core/services/firebase_messaging_service.dart';
import '../../../../core/services/supabase_service.dart';

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
    navigator.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
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
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
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
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                user == null
                    ? 'No hay sesión activa.'
                    : 'Correo: ${user.email}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const _SensitiveFieldsCard(),
              const SizedBox(height: 16),
              const _FcmTokenCard(),
              const SizedBox(height: 16),
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
            Text('La sesión se cierra tras $timeoutSeconds s sin interacción.'),
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
            child: Text(label, style: const TextStyle(color: Colors.black54)),
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

class _SensitiveFieldsCard extends StatefulWidget {
  const _SensitiveFieldsCard();

  @override
  State<_SensitiveFieldsCard> createState() => _SensitiveFieldsCardState();
}

class _SensitiveFieldsCardState extends State<_SensitiveFieldsCard> {
  late Future<Map<String, String?>> _sensitiveDataFuture;

  @override
  void initState() {
    super.initState();
    _loadSensitiveData();
  }

  void _loadSensitiveData() {
    setState(() {
      _sensitiveDataFuture = SessionManager.instance.readSensitiveFields();
    });
  }

  Future<void> _manualRefill() async {
    final user = FakeAuthRepository.instance.currentUser;
    if (user != null) {
      await SessionManager.instance.saveSensitiveFields(
        username: user.name,
        password: user.password,
        email: user.email,
        token: SessionManager.instance.hasActiveSession
            ? "sess_demo_token_123456"
            : "",
      );
      _loadSensitiveData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Datos sensibles recargados manualmente.'),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inicia sesión para rellenar automáticamente.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.lock_person_outlined, color: Colors.blueAccent),
                    SizedBox(width: 8),
                    Text(
                      'Datos Sensibles (Secure Storage)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _loadSensitiveData,
                  tooltip: 'Actualizar campos',
                ),
              ],
            ),
            const Divider(),
            FutureBuilder<Map<String, String?>>(
              future: _sensitiveDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data ?? {};
                final username = data['username'];
                final password = data['password'];
                final email = data['email'];
                final token = data['session_token'];

                final bool isEmpty =
                    username == null &&
                    password == null &&
                    email == null &&
                    token == null;

                if (isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.cleaning_services_rounded,
                            color: Colors.red,
                            size: 36,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '¡Datos Sensibles Wipados!',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Los 4 campos sensibles han sido borrados de forma segura del almacenamiento del dispositivo.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _manualRefill,
                            icon: const Icon(Icons.restore_rounded),
                            label: const Text('Recargar Datos Demo'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    _InfoRow(label: 'USUARIO', value: username ?? '[Vacío]'),
                    _InfoRow(label: 'CONTRASEÑA', value: password ?? '[Vacío]'),
                    _InfoRow(label: 'CORREO', value: email ?? '[Vacío]'),
                    _InfoRow(
                      label: 'TOKEN DE SESION',
                      value: token != null
                          ? (token.length > 20
                                ? '${token.substring(0, 18)}...'
                                : token)
                          : '[Vacío]',
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

class _FcmTokenCard extends StatelessWidget {
  const _FcmTokenCard();

  void _showSimulatedFcmDialog(BuildContext context) {
    final user = FakeAuthRepository.instance.currentUser;
    final emailController = TextEditingController(
      text: user?.email ?? 'demo@demo.com',
    );
    final wordController = TextEditingController(text: 'aguacate');

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: const [
              Icon(Icons.terminal, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text('Simular Notificación FCM'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Prueba cómo reacciona la app según los parámetros de la notificación:',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: wordController,
                decoration: const InputDecoration(
                  labelText: 'Palabra clave en el mensaje',
                  border: OutlineInputBorder(),
                  helperText: 'Debe contener "aguacate" para detonar',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'target_email (Payload)',
                  border: OutlineInputBorder(),
                  helperText: 'Debe coincidir con tu correo actual',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                final enteredWord = wordController.text.trim().toLowerCase();
                final enteredEmail = emailController.text.trim().toLowerCase();
                final activeUserEmail = user?.email.toLowerCase() ?? '';

                // Realizar la validación idéntica a _shouldTriggerWipe
                const String triggerWord = 'aguacate';
                if (!enteredWord.contains(triggerWord)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.orange.shade800,
                      content: Text(
                        'Simulación: Palabra clave "$enteredWord" incorrecta. Comando IGNORADO.',
                      ),
                    ),
                  );
                  return;
                }

                if (enteredEmail.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.orange.shade800,
                      content: const Text(
                        'Simulación: Falta target_email. Comando IGNORADO.',
                      ),
                    ),
                  );
                  return;
                }

                if (enteredEmail != activeUserEmail) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.orange.shade800,
                      content: Text(
                        'Simulación: El correo "$enteredEmail" no coincide con el usuario activo. Comando IGNORADO.',
                      ),
                    ),
                  );
                  return;
                }

                // Todo coincide, ejecutar wipe
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Colors.green,
                    content: Text(
                      'Simulación: ¡Filtros aprobados! Detonando Wipe Remoto...',
                    ),
                  ),
                );

                // Esperar un momento para ver la notificación
                await Future.delayed(const Duration(milliseconds: 600));
                await SessionManager.instance.remoteWipe();
              },
              child: const Text('Enviar Notificación Simulada'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final supabase = SupabaseService.instance;
    final bool isSupabaseConfigured = supabase.isConfigured;
    final bool isSupabaseInitialized = supabase.isInitialized;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.notifications_active, color: Colors.orangeAccent),
                SizedBox(width: 8),
                Text(
                  'Firebase FCM & Supabase Sync',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const Divider(),

            // Estado de conexión a Supabase
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isSupabaseInitialized
                    ? Colors.green.shade50
                    : (isSupabaseConfigured
                          ? Colors.orange.shade50
                          : Colors.blue.shade50),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSupabaseInitialized
                      ? Colors.green.shade200
                      : (isSupabaseConfigured
                            ? Colors.orange.shade200
                            : Colors.blue.shade200),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSupabaseInitialized
                        ? Icons.cloud_done
                        : (isSupabaseConfigured
                              ? Icons.cloud_queue
                              : Icons.cloud_off),
                    color: isSupabaseInitialized
                        ? Colors.green
                        : (isSupabaseConfigured ? Colors.orange : Colors.blue),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isSupabaseInitialized
                          ? 'Supabase Conectado (FCM sincronizado)'
                          : (isSupabaseConfigured
                                ? 'Supabase inicializando...'
                                : 'Supabase en Modo Local/Simulado'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSupabaseInitialized
                            ? Colors.green.shade900
                            : (isSupabaseConfigured
                                  ? Colors.orange.shade900
                                  : Colors.blue.shade900),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Text(
              'La aplicación detona el Wipe Remoto cuando recibe una notificación FCM dirigida a este usuario que contiene la palabra clave:',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Center(
              child: Chip(
                avatar: const Icon(Icons.key, size: 16, color: Colors.white),
                backgroundColor: Colors.red.shade700,
                label: const Text(
                  'Palabra clave: aguacate',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Token FCM del dispositivo (Sincronizado con Supabase):',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<String?>(
              valueListenable: FirebaseMessagingService.instance.fcmToken,
              builder: (context, token, _) {
                if (token == null) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('Obteniendo FCM Token...'),
                    ),
                  );
                }

                return Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: SelectableText(
                        token,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: token));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Token FCM copiado al portapapeles.',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('Copiar Token'),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                          onPressed: () => _showSimulatedFcmDialog(context),
                          icon: const Icon(
                            Icons.delete_forever_rounded,
                            size: 18,
                          ),
                          label: const Text('Simular Wipe'),
                        ),
                      ],
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
