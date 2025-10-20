import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../services/api_service.dart'; // Import the ApiService

class PendingScreen extends StatelessWidget {
  final String status;

  const PendingScreen({Key? key, required this.status}) : super(key: key);

  Map<String, dynamic> _getStatusDetails() {
    switch (status) {
      case 'Pending Hospital Approval':
        return {
          'icon': Icons.business,
          'title': 'Pending Hospital Approval',
          'message': 'Your application has been submitted and is awaiting review from your hospital administrator.',
          'color': Colors.orange,
        };
      case 'Pending Platform Approval':
        return {
          'icon': Icons.verified_user,
          'title': 'Pending Final Approval',
          'message': 'Your hospital has approved your application. It is now awaiting final verification by the platform administrator.',
          'color': Colors.blue,
        };
      case 'Rejected':
        return {
          'icon': Icons.cancel,
          'title': 'Application Rejected',
          'message': 'Unfortunately, your application was not approved. Please contact your administrator for more details.',
          'color': Colors.red,
        };
      default:
        return {
          'icon': Icons.hourglass_empty,
          'title': 'Status Unknown',
          'message': 'Your account status is undetermined. Please log out and try again.',
          'color': Colors.grey,
        };
    }
  }

  // --- UPDATED LOGOUT FUNCTION ---
  Future<void> _logout(BuildContext context) async {
    // Call the secure, server-side logout
    await ApiService.logout();

    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = _getStatusDetails();

    return Scaffold(
      appBar: AppBar(
        title: Text(details['title']),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context), // This call is now secure
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(details['icon'], size: 80, color: details['color']),
              const SizedBox(height: 20),
              Text(
                details['title'],
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                details['message'],
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              if (status != 'Rejected') const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}