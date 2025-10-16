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
        // We have a token, decode it to find out the user's status
        final user = User.fromToken(token);

        if (user.verificationStatus == 'Verified') {
          // User is verified, go to the main map screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MapScreen()),
          );
        } else {
          // User is 'Pending' or 'Rejected', go to the pending screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const PendingScreen()),
          );
        }
      } catch (e) {
        // Token is invalid or expired, go to login
        print('Token decoding error: $e');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } else {
      // No token found, user needs to log in
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