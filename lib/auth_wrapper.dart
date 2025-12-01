import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';
import 'login_or_register_page.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 1. Jika masih loading cek status login
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Jika ada data user (Berarti sudah login) -> Ke Home
          if (snapshot.hasData) {
            return const HomePage();
          }

          // 3. Jika tidak ada user (Belum login) -> Ke Login/Register
          else {
            return const LoginOrRegisterPage();
          }
        },
      ),
    );
  }
}
