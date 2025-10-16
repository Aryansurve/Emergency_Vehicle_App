import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Replace this with your computer's local IP address. 'localhost' will not work on a physical device.
  // Find your IP by running 'ipconfig' (Windows) or 'ifconfig' (macOS/Linux) in your terminal.
  static const String _baseUrl = "http://192.168.0.128:5000/api/v1/auth";

  // Method to handle user login
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$_baseUrl/login');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'email': email,
          'password': password,
        }),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 && responseBody['success'] == true) {
        // Login successful, save the token
        final token = responseBody['token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);

        return {
          'success': true,
          'message': 'Login Successful',
          'token': token
        };
      } else {
        // Login failed, return the error message from the backend
        return {
          'success': false,
          'message': responseBody['message'] ?? 'An unknown error occurred'
        };
      }
    } catch (e) {
      // Handle network or other errors
      print('Error during login: $e');
      return {
        'success': false,
        'message': 'Could not connect to the server.'
      };
    }
  }
}