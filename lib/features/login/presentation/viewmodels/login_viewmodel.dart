import 'package:flutter/material.dart';

import '../../../../core/models/app_user.dart';
import '../../../../core/services/fake_auth_repository.dart';
import '../../../../core/utils/validators.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel({FakeAuthRepository? repository})
      : _repository = repository ?? FakeAuthRepository.instance;

  final FakeAuthRepository _repository;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;

  String? validateEmail(String? value) => Validators.email(value);

  String? validatePassword(String? value) => Validators.password(value);

  Future<AppUser?> submit() async {
    final FormState? formState = formKey.currentState;
    if (formState == null || !formState.validate()) {
      return null;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final AppUser user = await _repository.login(
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
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}