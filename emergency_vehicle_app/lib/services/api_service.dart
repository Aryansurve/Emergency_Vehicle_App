import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _baseUrl = "http://192.168.0.128:5000/api/v1/auth";
  // Fetch hospital names




  // Fetch hospitals
  static Future<List<dynamic>> getHospitals() async {
    final url = Uri.parse("http://192.168.0.128:5000/api/v1/hospitals");

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['hospitals'] ?? [];
      } else {
        return [];
      }
    } catch (e) {
      print('Error fetching hospitals: $e');
      return [];
    }
  }

// Register user
  static Future<Map<String, dynamic>> register(
      String name,
      String email,
      String password,
      String vehicleId,
      String hospitalId,
      ) async {
    final url = Uri.parse('http://192.168.0.128:5000/api/v1/auth/register');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'vehicleId': vehicleId,
          'hospitalId': hospitalId,
        }),
      );

      final responseBody = jsonDecode(response.body);

      return {
        'success': response.statusCode == 201,
        'message': responseBody['message'] ?? 'Registration failed',
      };
    } catch (e) {
      print('Error during registration: $e');
      return {'success': false, 'message': 'Could not connect to server'};
    }
  }


// Request verification for selected hospital
  // Login method
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('http://192.168.0.128:5000/api/v1/auth/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        final token = body['token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);

        return {'success': true, 'token': token};
      } else {
        return {'success': false, 'message': body['message'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Server error: $e'};
    }
  }

  // Request verification (select hospital)
  static Future<Map<String, dynamic>> requestVerification(String hospitalId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final url = Uri.parse("http://192.168.0.128:5000/api/v1/hospitals/request");
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({'hospitalId': hospitalId}),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 && responseBody['success'] == true) {
        return {'success': true, 'message': responseBody['message']};
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Failed to request verification'};
      }
    } catch (e) {
      print('Error requesting verification: $e');
      return {'success': false, 'message': 'Could not connect to server.'};
    }
  }
}
