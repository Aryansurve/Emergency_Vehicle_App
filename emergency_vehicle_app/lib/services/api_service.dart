import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _baseUrl = "http://192.168.0.128:5000/api/v1/auth";
  // Fetch hospital names
  static Future<List<String>> getHospitals() async {
    final url = Uri.parse('http://192.168.0.128:5000/api/v1/hospitals');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data.map((h) => h['name']));
      }
      return [];
    } catch (e) {
      print('Error fetching hospitals: $e');
      return [];
    }
  }

// Request verification for selected hospital
  // Login method
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$_baseUrl/login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 && responseBody['success'] == true) {
        final token = responseBody['token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);

        return {
          'success': true,
          'message': 'Login Successful',
          'token': token
        };
      } else {
        return {
          'success': false,
          'message': responseBody['message'] ?? 'An unknown error occurred'
        };
      }
    } catch (e) {
      print('Error during login: $e');
      return {'success': false, 'message': 'Could not connect to the server.'};
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
