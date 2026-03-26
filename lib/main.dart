import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/room_provider.dart';
import 'providers/expense_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/owner/owner_home_screen.dart';
import 'screens/member/member_home_screen.dart';
import 'screens/admin/admin_home_screen.dart';
import 'theme.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RoomProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
      ],
      child: const RoomMessApp(),
    ),
  );
}

class RoomMessApp extends StatelessWidget {
  const RoomMessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RoomMess',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AuthProvider>().loadUser();
  }

  @override
  Widget build(BuildContext context) {
    return const AuthGate();
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.loading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading RoomMess...'),
            ],
          ),
        ),
      );
    }

    if (!auth.isAuthenticated) return const LoginScreen();

    final user = auth.user!;
    if (user.isOwner) return const OwnerHomeScreen();
    if (user.isMember) return const MemberHomeScreen();
    if (user.isAdmin) return const AdminHomeScreen();

    return const LoginScreen();
  }
}
