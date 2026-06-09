import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/services/session_manager.dart';
import '../../../../core/widgets/app_action_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/utils/secure_screen_mixin.dart';
import '../viewmodels/login_viewmodel.dart';
import '../../../../core/services/firebase_messaging_service.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> with SecureScreenMixin<LoginView> {
  late final LoginViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = LoginViewModel();
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = await viewModel.submit();
    if (!mounted) {
      return;
    }

    if (user == null) {
      return;
    }

    // Arranca la sesion: genera/persiste el token y las variables de tiempo en
    // el almacen encriptado y enciende el contador de inactividad.
    await SessionManager.instance.startSession();
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacementNamed(
      AppRoutes.home,
      arguments: user,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: viewModel.formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 24),
                        const Icon(Icons.shield_outlined, size: 72),
                        const SizedBox(height: 16),
                        const Text(
                          'Inicia sesión',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Prueba el acceso con datos simulados.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        AppTextField(
                          controller: viewModel.emailController,
                          label: 'Correo electrónico',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: viewModel.validateEmail,
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          controller: viewModel.passwordController,
                          label: 'Contraseña',
                          icon: Icons.lock_outline,
                          obscureText: true,
                          validator: viewModel.validatePassword,
                        ),
                        if (viewModel.errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            viewModel.errorMessage!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 24),
                        AppActionButton(
                          label: 'Entrar',
                          isLoading: viewModel.isLoading,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pushNamed(AppRoutes.register);
                          },
                          child: const Text('No tengo cuenta, registrarme'),
                        ),
                        const SizedBox(height: 16),
                        const _DemoCredentialsCard(),
                        const SizedBox(height: 16),
                        const _LoginFcmTokenCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DemoCredentialsCard extends StatelessWidget {
  const _DemoCredentialsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Datos simulados',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Correo: demo@demo.com'),
            Text('Clave: 123456'),
          ],
        ),
      ),
    );
  }
}

class _LoginFcmTokenCard extends StatelessWidget {
  const _LoginFcmTokenCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.key, size: 18, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'FCM Token (Para pruebas de Wipe)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const Divider(),
            ValueListenableBuilder<String?>(
              valueListenable: FirebaseMessagingService.instance.fcmToken,
              builder: (context, token, _) {
                if (token == null) {
                  return const Text(
                    'Cargando Token FCM...',
                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                  );
                }

                return Column(
                  children: [
                    Text(
                      token,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: token));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Token FCM copiado al portapapeles.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text(
                          'Copiar Token',
                          style: TextStyle(fontSize: 12),
                        ),
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