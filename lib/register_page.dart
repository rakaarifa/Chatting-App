import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'components/my_button.dart';
import 'components/my_textfield.dart';

class RegisterPage extends StatefulWidget {
  final void Function()? onTap;
  const RegisterPage({super.key, this.onTap});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isLoading = false;

  void _register() async {
    if (_passCtrl.text != _confirmCtrl.text) return;
    setState(() => _isLoading = true);
    try {
      await AuthService().signUpWithEmailPassword(
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
      body: Stack(
        children: [
          Positioned(
              top: -50,
              right: -50,
              child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                    BoxShadow(
                        color: color.primary.withOpacity(0.3), blurRadius: 100)
                  ]))), // FIXED BLUR RADIUS
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text("Create Account",
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
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
                  const SizedBox(height: 16),
                  MyTextField(
                      controller: _confirmCtrl,
                      hintText: "Confirm Password",
                      obscureText: true,
                      prefixIcon: Icons.lock),
                  const SizedBox(height: 24),
                  MyButton(
                      text: "REGISTER",
                      onTap: _register,
                      isLoading: _isLoading),
                  const SizedBox(height: 20),
                  GestureDetector(
                      onTap: widget.onTap,
                      child: const Text("Already have an account? Login",
                          style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
