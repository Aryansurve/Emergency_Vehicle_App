import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async'; // Needed for Timer
import '../models/user.dart';
import 'package:animate_do/animate_do.dart';
import 'package:lottie/lottie.dart';
// Import all possible destinations
import 'auth_screen.dart';
import 'login_screen.dart';
import 'map_screen.dart';
import 'pending_screen.dart';
import 'public_home_screen.dart';
import 'hospital_admin_dashboard.dart';
import 'platform_admin_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Start the navigation logic after the animation duration
    Timer(const Duration(milliseconds: 3000), _checkAuthStatus); // Match animation duration
  }

  // --- All your existing logic remains here ---
  Future<void> _checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    // Use context safely after async gap
    if (!mounted) return;

    if (token == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
      return;
    }

    try {
      final user = User.fromToken(token);
      switch (user.role) {
        case 'Driver':
          _navigateDriver(user);
          break;
        case 'PublicUser':
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PublicHomeScreen()));
          break;
        case 'HospitalAdmin':
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HospitalAdminDashboard()));
          break;
        case 'Admin':
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PlatformAdminDashboard()));
          break;
        default:
          _logout();
      }
    } catch (e) {
      _logout();
    }
  }
  void _navigateDriver(User user) {
    if (!mounted) return; // Check mount status again
    switch (user.verificationStatus) {
      case 'Verified':
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MapScreen()));
        break;
      case 'Pending Hospital Approval':
      case 'Pending Platform Approval':
      case 'Rejected':
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => PendingScreen(status: user.verificationStatus)));
        break;
      default:
        _logout();
    }
  }
  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    if(mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthScreen()));
    }
  }

// --- This build method now includes animations ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Changed to white background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. Animated Icon
            Pulse( // Adds a subtle pulse effect
              duration: const Duration(milliseconds: 1500),
              child: ZoomIn( // Icon zooms in
                duration: const Duration(milliseconds: 1000),
                child: Icon(
                  Icons.local_shipping,
                  size: 120, // Slightly larger
                  color: Colors.blueGrey[700], // Darker color for white background
                ),
              ),
            ),
            const SizedBox(height: 20),
            // 2. Animated Title
            FadeInUp(
              duration: const Duration(milliseconds: 800),
              delay: const Duration(milliseconds: 500), // Staggered entry
              child: Text(
                'Emergency Vehicle App',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey[800], // Darker color
                ),
              ),
            ),
            const SizedBox(height: 10),
            // 3. Animated Tagline
            FadeInUp(
              duration: const Duration(milliseconds: 800),
              delay: const Duration(milliseconds: 700), // Staggered entry
              child: Text(
                'Reliable Response, in Real-Time.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 50), // Add space before the indicator
            // 4. Optional: Fade in the progress indicator later
            // 4. Fade in the Lottie animation
            FadeIn(
              delay: const Duration(milliseconds: 1500), // Appears after main animations
              child: SizedBox( // Use a SizedBox to control the animation's size
                width: 200, // Adjust width as needed
                height: 200, // Adjust height as needed
                child: Lottie.asset(
                  'assets/loading.json', // <-- Your Lottie file path
                  repeat: true, // Make it loop
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}