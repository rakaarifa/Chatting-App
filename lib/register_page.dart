import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'components/my_button.dart';
import 'components/my_textfield.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  final void Function()? onTap; // <-- INI KUNCINYA
  const RegisterPage({super.key, this.onTap}); // <-- INI HARUS ADA

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _emailC = TextEditingController();
  final TextEditingController _passC = TextEditingController();
  final TextEditingController _confirmC = TextEditingController();
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  Future<void> _register() async {
    if (_passC.text != _confirmC.text) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Password tidak cocok!")));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _authService.signUpWithEmailPassword(
          _emailC.text.trim(), _passC.text.trim());
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
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
                    color: color.tertiaryContainer.withOpacity(0.5)),
                child: Icon(Icons.person_add_rounded,
                    size: 60, color: color.tertiary),
              ),
              const SizedBox(height: 30),
              Text("Buat Akun Baru",
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: color.onSurface)),
              Text("Mulai obrolan seru sekarang",
                  style:
                      TextStyle(fontSize: 16, color: color.onSurfaceVariant)),
              const SizedBox(height: 40),
              MyTextField(
                  controller: _emailC,
                  hintText: "Email",
                  obscureText: false,
                  prefixIcon: Icons.email_outlined),
              const SizedBox(height: 16),
              MyTextField(
                  controller: _passC,
                  hintText: "Password",
                  obscureText: true,
                  prefixIcon: Icons.lock_outline),
              const SizedBox(height: 16),
              MyTextField(
                  controller: _confirmC,
                  hintText: "Konfirmasi Password",
                  obscureText: true,
                  prefixIcon: Icons.lock_reset),
              const SizedBox(height: 30),
              MyButton(text: "DAFTAR", onTap: _register, isLoading: _isLoading),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Sudah punya akun? ",
                      style: TextStyle(color: color.onSurfaceVariant)),
                  GestureDetector(
                    // Panggil fungsi onTap di sini
                    onTap: widget.onTap,
                    child: Text("Login sekarang",
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
