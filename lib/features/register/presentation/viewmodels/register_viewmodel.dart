import 'package:flutter/material.dart';

import '../../../../core/models/app_user.dart';
import '../../../../core/services/fake_auth_repository.dart';
import '../../../../core/utils/validators.dart';

class RegisterViewModel extends ChangeNotifier {
  RegisterViewModel({FakeAuthRepository? repository})
      : _repository = repository ?? FakeAuthRepository.instance;

  final FakeAuthRepository _repository;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;

  String? validateName(String? value) => Validators.requiredField(value, 'tu nombre');

  String? validateEmail(String? value) => Validators.email(value);

  String? validatePassword(String? value) => Validators.password(value);

  String? validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirma tu contraseña.';
    }

    if (value != passwordController.text) {
      return 'Las contraseñas no coinciden.';
    }

    return null;
  }

  Future<AppUser?> submit() async {
    final FormState? formState = formKey.currentState;
    if (formState == null || !formState.validate()) {
      return null;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final AppUser user = await _repository.register(
        name: nameController.text,
        email: emailController.text,
        password: passwordController.text,
      );
      return user;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}