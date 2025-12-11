import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'components/my_button.dart';
import 'components/my_textfield.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  final void Function()? onTap;
  const LoginPage({super.key, this.onTap});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final AuthService _auth = AuthService();
  bool _isLoading = false;

  void _login() async {
    setState(() => _isLoading = true);
    try {
      await _auth.signInWithEmailPassword(
          _emailCtrl.text.trim(), _passCtrl.text.trim());
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mark_chat_unread_rounded,
                  size: 80, color: color.primary),
              const SizedBox(height: 20),
              const Text("Welcome Back!",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              MyTextField(
                  controller: _emailCtrl,
                  hintText: "Email",
                  obscureText: false,
                  prefixIcon: Icons.email),
              const SizedBox(height: 16),
              MyTextField(
                  controller: _passCtrl,
                  hintText: "Password",
                  obscureText: true,
                  prefixIcon: Icons.lock),
              const SizedBox(height: 24),
              MyButton(text: "MASUK", onTap: _login, isLoading: _isLoading),
              const SizedBox(height: 20),
              GestureDetector(
                  onTap: widget.onTap,
                  child: Text("Belum punya akun? Daftar disini",
                      style: TextStyle(
                          color: color.primary, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
      ),
    );
  }
}
