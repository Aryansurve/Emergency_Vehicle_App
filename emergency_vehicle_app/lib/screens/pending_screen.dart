import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class PendingScreen extends StatefulWidget {
  const PendingScreen({Key? key}) : super(key: key);

  @override
  _PendingScreenState createState() => _PendingScreenState();
}

class _PendingScreenState extends State<PendingScreen> {
  String? _selectedHospital;
  bool _isLoading = false;
  List<String> _hospitals = []; // Hospital names

  @override
  void initState() {
    super.initState();
    _fetchHospitals();
  }

  Future<void> _fetchHospitals() async {
    // Fetch hospitals from backend
    final hospitals = await ApiService.getHospitals();
    setState(() {
      _hospitals = hospitals;
    });
  }

  Future<void> _requestVerification() async {
    if (_selectedHospital == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a hospital')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await ApiService.requestVerification(_selectedHospital!);

    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']),
        backgroundColor: result['success'] ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Pending'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.hourglass_top,
              size: 80,
              color: Colors.blueGrey,
            ),
            const SizedBox(height: 20),
            const Text(
              'Verification Pending',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Your account is awaiting admin approval. You can select a hospital to request access.',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            _hospitals.isEmpty
                ? const CircularProgressIndicator()
                : DropdownButtonFormField<String>(
              value: _selectedHospital,
              hint: const Text('Select Hospital'),
              items: _hospitals.map((hospital) {
                return DropdownMenuItem(
                  value: hospital,
                  child: Text(hospital),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedHospital = value;
                });
              },
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _requestVerification,
              child: const Text('Request Access'),
            ),
          ],
        ),
      ),
    );
  }
}
