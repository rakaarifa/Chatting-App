import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'auth_wrapper.dart';
import 'auth_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const LifecycleWatcher(child: ChatApp()),
    ),
  );
}

class LifecycleWatcher extends StatefulWidget {
  final Widget child;
  const LifecycleWatcher({super.key, required this.child});
  @override
  State<LifecycleWatcher> createState() => _LifecycleWatcherState();
}

class _LifecycleWatcherState extends State<LifecycleWatcher>
    with WidgetsBindingObserver {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authService.setUserOnlineStatus(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _authService.setUserOnlineStatus(true);
    } else {
      _authService.setUserOnlineStatus(false);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'NeoChat',
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: themeProvider.themeMode,
          home: const AuthWrapper(),
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    var baseTheme = ThemeData(brightness: brightness, useMaterial3: true);

    // Warna Premium
    var primary = const Color(0xFF6366F1); // Indigo Modern
    var surface = brightness == Brightness.light
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF0F172A);
    var card =
        brightness == Brightness.light ? Colors.white : const Color(0xFF1E293B);

    return baseTheme.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        primary: primary,
        surface: surface,
        surfaceContainerHighest: card, // Untuk Card Color
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(baseTheme.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color:
                brightness == Brightness.light ? Colors.black87 : Colors.white),
        iconTheme: IconThemeData(
            color:
                brightness == Brightness.light ? Colors.black87 : Colors.white),
      ),
      scaffoldBackgroundColor: surface,
      cardColor: card,
    );
  }
}
