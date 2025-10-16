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
  String? _selectedHospitalId;
  bool _isLoading = false;
  List<Map<String, dynamic>> _hospitals = []; // Use list of maps for backend data

  @override
  void initState() {
    super.initState();
    _fetchHospitals();
  }

  Future<void> _fetchHospitals() async {
    try {
      final hospitals = await ApiService.getHospitals();
      setState(() {
        // Convert to List<Map<String, dynamic>>
        _hospitals = List<Map<String, dynamic>>.from(hospitals);
      });
    } catch (e) {
      print('Error fetching hospitals: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load hospitals'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _requestVerification() async {
    if (_selectedHospitalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a hospital')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await ApiService.requestVerification(_selectedHospitalId!);

    setState(() => _isLoading = false);

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
              value: _selectedHospitalId,
              hint: const Text('Select Hospital'),
              items: _hospitals.map((hospital) {
                return DropdownMenuItem<String>(
                  value: hospital['_id'], // send ID to backend
                  child: Text(hospital['name']),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedHospitalId = value;
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
