import 'package:flutter/material.dart';
import 'package:sponsorenlauf_app/pages/login_page.dart';
import 'package:sponsorenlauf_app/pages/register_page.dart';

class LoginOrRegister extends StatefulWidget {
  // NEU: Definiert den "Straßennamen" für diese Seite
  static const routeName = '/login_or_register';

  const LoginOrRegister({super.key});

  @override
  State<LoginOrRegister> createState() => _LoginOrRegisterState();
}

class _LoginOrRegisterState extends State<LoginOrRegister> {
  bool showLoginPage = true;

  void togglePages() {
    setState(() {
      showLoginPage = !showLoginPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (showLoginPage) {
      return LoginPage(showRegisterPage: togglePages);
    } else {
      return RegisterPage(showLoginPage: togglePages);
    }
  }
}