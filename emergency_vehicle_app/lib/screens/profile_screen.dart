import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>> _driverProfile;

  @override
  void initState() {
    super.initState();
    _driverProfile = ApiService.getDriverProfile();
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _driverProfile,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.data!['success']) {
            return const Center(child: Text('Failed to load profile.'));
          }

          final driver = snapshot.data!['data'];
          final hospital = driver['hospitalId'];

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildProfileTile(Icons.person, 'Name', driver['name']),
              _buildProfileTile(Icons.email, 'Email', driver['email']),
              _buildProfileTile(Icons.local_shipping, 'Vehicle ID', driver['vehicleId']),
              if (hospital != null)
                _buildProfileTile(Icons.local_hospital, 'Hospital', hospital['name']),
              const Divider(height: 40),
              ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                onPressed: _logout,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileTile(IconData icon, String title, String subtitle) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).primaryColor),
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}