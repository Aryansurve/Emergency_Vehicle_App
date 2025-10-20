import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../services/api_service.dart';
import 'splash_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _selectedSegment = 0; // 0 for Driver, 1 for Public User

// AFTER (Correct - changes color AND switches the page)
// BEFORE (Incorrect)
// AFTER (Correct)
  void _onSegmentChanged(int? index) {
    setState(() {
      _selectedSegment = index!;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.black),
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              Column(
                children: <Widget>[
                  FadeInUp(
                    duration: const Duration(milliseconds: 1000),
                    child: const Text("Sign up", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 20),
                  FadeInUp(
                    duration: const Duration(milliseconds: 1200),
                    child: Text("Create an account, it's free", style: TextStyle(fontSize: 15, color: Colors.grey[700])),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
              // Custom Segmented Control
              FadeInUp(
                duration: const Duration(milliseconds: 1300),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _buildSegment("Driver", 0)),
                      Expanded(child: _buildSegment("Public User", 1)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- THIS IS THE FIX ---
              // We replace the PageView with an AnimatedSwitcher.
              // This allows the SingleChildScrollView to correctly calculate the form's height.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: _selectedSegment == 0
                    ? const DriverRegisterForm(key: ValueKey('DriverForm'))
                    : const PublicUserRegisterForm(key: ValueKey('PublicUserForm')),
              ),
              // --- END OF FIX ---

              const SizedBox(height: 20), // Add some spacing
              FadeInUp(
                duration: const Duration(milliseconds: 1500),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context), // Go back to login
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Already have an account?"),
                      Text(" Login", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30), // Spacing for when keyboard is up
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegment(String text, int index) {
    return GestureDetector(
      onTap: () => _onSegmentChanged(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _selectedSegment == index ? Colors.blueGrey : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: _selectedSegment == index ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// WIDGET FOR DRIVER REGISTRATION
// -----------------------------------------------------------------------------
class DriverRegisterForm extends StatefulWidget {
  const DriverRegisterForm({Key? key}) : super(key: key);
  @override
  _DriverRegisterFormState createState() => _DriverRegisterFormState();
}

class _DriverRegisterFormState extends State<DriverRegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _vehicleIdController = TextEditingController();
  String? _selectedHospitalId;
  bool _isLoading = false;
  List<dynamic> _hospitals = [];

  @override
  void initState() {
    super.initState();
    _fetchHospitals();
  }

  Future<void> _fetchHospitals() async {
    final hospitals = await ApiService.getHospitals();
    if (mounted) setState(() => _hospitals = hospitals);
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final result = await ApiService.registerDriver({
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'password': _passwordController.text.trim(),
      'vehicleId': _vehicleIdController.text.trim(),
      'hospitalId': _selectedHospitalId!,
    });
    if (mounted) setState(() => _isLoading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'An error occurred')));
    if (result['success'] == true) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          FadeInUp(duration: const Duration(milliseconds: 1400), child: makeInput(label: "Full Name", controller: _nameController)),
          FadeInUp(duration: const Duration(milliseconds: 1500), child: makeInput(label: "Email", controller: _emailController)),
          FadeInUp(duration: const Duration(milliseconds: 1600), child: makeInput(label: "Password", controller: _passwordController, obscureText: true)),
          FadeInUp(duration: const Duration(milliseconds: 1700), child: makeInput(label: "Vehicle ID", controller: _vehicleIdController)),
          FadeInUp(
            duration: const Duration(milliseconds: 1800),
            child: DropdownButtonFormField<String>(
              isExpanded: true, // <-- ADD THIS LINE
              decoration: const InputDecoration(
                labelText: 'Select Hospital',
                contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                border: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
              ),
              value: _selectedHospitalId,
              items: _hospitals.map((h) => DropdownMenuItem<String>(value: h['_id'], child: Text(h['name']))).toList(),
              onChanged: (val) => setState(() => _selectedHospitalId = val),
              validator: (v) => v == null ? 'Please select a hospital' : null,
            ),
          ),
          const SizedBox(height: 20),
          FadeInUp(
            duration: const Duration(milliseconds: 1900),
            child: _isLoading
                ? const CircularProgressIndicator()
                : MaterialButton(
              minWidth: double.infinity,
              height: 60,
              onPressed: _register,
              color: Colors.blueGrey,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              child: const Text("Register as Driver", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// WIDGET FOR PUBLIC USER REGISTRATION
// -----------------------------------------------------------------------------
class PublicUserRegisterForm extends StatefulWidget {
  const PublicUserRegisterForm({Key? key}) : super(key: key);
  @override
  _PublicUserRegisterFormState createState() => _PublicUserRegisterFormState();
}

class _PublicUserRegisterFormState extends State<PublicUserRegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final result = await ApiService.registerPublicUser({
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'password': _passwordController.text.trim(),
    });
    if (mounted) setState(() => _isLoading = false);
    if (!mounted) return;
    if (result['success'] == true) {
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const SplashScreen()), (route) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'An error occurred')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          FadeInUp(duration: const Duration(milliseconds: 1400), child: makeInput(label: "Full Name", controller: _nameController)),
          FadeInUp(duration: const Duration(milliseconds: 1500), child: makeInput(label: "Email", controller: _emailController)),
          FadeInUp(duration: const Duration(milliseconds: 1600), child: makeInput(label: "Password", controller: _passwordController, obscureText: true)),
          const SizedBox(height: 30),
          FadeInUp(
            duration: const Duration(milliseconds: 1700),
            child: _isLoading
                ? const CircularProgressIndicator()
                : MaterialButton(
              minWidth: double.infinity,
              height: 60,
              onPressed: _register,
              color: Colors.blueGrey,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              child: const Text("Create My Account", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// Helper function for styling text fields
Widget makeInput({required String label, bool obscureText = false, required TextEditingController controller}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Colors.black87)),
      const SizedBox(height: 5),
      TextFormField(
        controller: controller,
        obscureText: obscureText,
        validator: (val) => val!.isEmpty ? 'This field is required' : null,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade400)),
          border: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade400)),
        ),
      ),
      const SizedBox(height: 20),
    ],
  );
}