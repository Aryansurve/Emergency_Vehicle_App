import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/map_screen.dart';
import 'screens/public_home_screen.dart';
import 'screens/hospital_admin_dashboard.dart';
import 'screens/platform_admin_dashboard.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Emergency Vehicle App',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      // Use SplashScreen as the home to handle all initial routing
      home: const SplashScreen(),
      // You can keep routes for manual navigation if needed
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/driver_map': (context) => const MapScreen(),
        // Note: Pending screen now requires a status, so direct routing is tricky.
        // It's better to let SplashScreen handle it.
        '/public_home': (context) => const PublicHomeScreen(),
        '/hospital_admin': (context) => const HospitalAdminDashboard(),
        '/platform_admin': (context) => const PlatformAdminDashboard(),
      },
    );
  }
}