import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../models/user.dart';
import 'login_screen.dart';
import 'map_screen.dart';
import 'pending_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Wait for a couple of seconds to show the splash screen
    await Future.delayed(const Duration(seconds: 2));

    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    if (!mounted) return; // Ensure the widget is still in the tree

    if (token != null) {
      try {
        final user = User.fromToken(token);

        if (user.verificationStatus == 'Verified') {
          // User is verified, go to MapScreen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MapScreen()),
          );
        } else if (user.verificationStatus == 'Pending') {
          // User is pending verification
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const PendingScreen()),
          );
        } else {
          // User is rejected or unknown status → force login
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      } catch (e) {
        // Token is invalid or expired → go to login
        print('Token decoding error: $e');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } else {
      // No token found → go to login
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.blueGrey,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping, size: 80, color: Colors.white),
            SizedBox(height: 20),
            Text(
              'Emergency Vehicle App',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
