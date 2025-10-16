import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _vehicleIdController = TextEditingController();

  bool _isLoading = false;
  List<Map<String, dynamic>> _hospitals = [];
  String? _selectedHospitalId;

  @override
  void initState() {
    super.initState();
    _fetchHospitals();
  }

  Future<void> _fetchHospitals() async {
    try {
      final data = await ApiService.getHospitals();
      // Ensure we have a List<Map<String, dynamic>>
      setState(() {
        _hospitals = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      print('Error fetching hospitals: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load hospitals'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _register() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _vehicleIdController.text.isEmpty ||
        _selectedHospitalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields and select a hospital'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await ApiService.register(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text.trim(),
      _vehicleIdController.text.trim(),
      _selectedHospitalId!,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration successful! Please wait for admin approval.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context); // Go back to login screen
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register Driver')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextField(_nameController, 'Full Name'),
              const SizedBox(height: 12),
              _buildTextField(_emailController, 'Email', keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _buildTextField(_passwordController, 'Password', obscureText: true),
              const SizedBox(height: 12),
              _buildTextField(_vehicleIdController, 'Vehicle ID'),
              const SizedBox(height: 12),
              _hospitals.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Select Hospital',
                  border: OutlineInputBorder(),
                ),
                value: _selectedHospitalId,
                items: _hospitals.map((hospital) {
                  return DropdownMenuItem<String>(
                    value: hospital['_id'],
                    child: Text(hospital['name']),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedHospitalId = val;
                  });
                },
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                onPressed: _register,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Register', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool obscureText = false, TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      obscureText: obscureText,
      keyboardType: keyboardType,
    );
  }
}
