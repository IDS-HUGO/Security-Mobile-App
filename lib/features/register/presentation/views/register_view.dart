import 'package:flutter/material.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/services/session_manager.dart';
import '../../../../core/widgets/app_action_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/utils/secure_screen_mixin.dart';
import '../viewmodels/register_viewmodel.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> with SecureScreenMixin<RegisterView> {
  late final RegisterViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = RegisterViewModel();
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
          appBar: AppBar(title: const Text('Registro')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: viewModel.formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    const Text(
                      'Crea una cuenta de prueba',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    AppTextField(
                      controller: viewModel.nameController,
                      label: 'Nombre completo',
                      icon: Icons.person_outline,
                      validator: viewModel.validateName,
                    ),
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: viewModel.confirmPasswordController,
                      label: 'Confirmar contraseña',
                      icon: Icons.lock_reset_outlined,
                      obscureText: true,
                      validator: viewModel.validateConfirmPassword,
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
                      label: 'Registrar',
                      isLoading: viewModel.isLoading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Ya tengo cuenta, volver al login'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}