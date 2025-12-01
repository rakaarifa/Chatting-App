import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'components/my_button.dart';
import 'components/my_textfield.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  final void Function()? onTap; // <-- INI KUNCINYA
  const LoginPage({super.key, this.onTap}); // <-- INI HARUS ADA

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty)
      return;
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Login Gagal: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: color.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.primaryContainer.withOpacity(0.5),
                ),
                child: Icon(Icons.chat_bubble_rounded,
                    size: 60, color: color.primary),
              ),
              const SizedBox(height: 30),
              Text("Selamat Datang",
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: color.onSurface)),
              Text("Masuk ke akun anda",
                  style:
                      TextStyle(fontSize: 16, color: color.onSurfaceVariant)),
              const SizedBox(height: 40),
              MyTextField(
                  controller: _emailController,
                  hintText: "Email",
                  obscureText: false,
                  prefixIcon: Icons.email_outlined),
              const SizedBox(height: 16),
              MyTextField(
                  controller: _passwordController,
                  hintText: "Password",
                  obscureText: true,
                  prefixIcon: Icons.lock_outline),
              const SizedBox(height: 30),
              MyButton(text: "MASUK", onTap: _login, isLoading: _isLoading),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Belum punya akun? ",
                      style: TextStyle(color: color.onSurfaceVariant)),
                  GestureDetector(
                    // Panggil fungsi onTap di sini
                    onTap: widget.onTap,
                    child: Text("Daftar disini",
                        style: TextStyle(
                            color: color.primary, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
