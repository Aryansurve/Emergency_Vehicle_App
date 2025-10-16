// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
//
// class ApiService {
//   static const String _baseUrl = "http://192.168.0.127:5000/api/v1/auth";
//   // Fetch hospital names
//
//
//
//
//   // Fetch hospitals
//   static Future<List<dynamic>> getHospitals() async {
//     final url = Uri.parse("http://192.168.0.127:5000/api/v1/hospitals");
//
//     try {
//       final response = await http.get(url);
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         return data['hospitals'] ?? [];
//       } else {
//         return [];
//       }
//     } catch (e) {
//       print('Error fetching hospitals: $e');
//       return [];
//     }
//   }
//
// // Register user
//   static Future<Map<String, dynamic>> register(
//       String name,
//       String email,
//       String password,
//       String vehicleId,
//       String hospitalId,
//       ) async {
//     final url = Uri.parse('http://192.168.0.127:5000/api/v1/auth/register');
//
//     try {
//       final response = await http.post(
//         url,
//         headers: {'Content-Type': 'application/json; charset=UTF-8'},
//         body: jsonEncode({
//           'name': name,
//           'email': email,
//           'password': password,
//           'vehicleId': vehicleId,
//           'hospitalId': hospitalId,
//         }),
//       );
//
//       final responseBody = jsonDecode(response.body);
//
//       return {
//         'success': response.statusCode == 201,
//         'message': responseBody['message'] ?? 'Registration failed',
//       };
//     } catch (e) {
//       print('Error during registration: $e');
//       return {'success': false, 'message': 'Could not connect to server'};
//     }
//   }
//
//
// // Request verification for selected hospital
//   // Login method
//   static Future<Map<String, dynamic>> login(String email, String password) async {
//     final url = Uri.parse('http://192.168.0.127:5000/api/v1/auth/login');
//
//     try {
//       final response = await http.post(
//         url,
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({'email': email, 'password': password}),
//       );
//
//       final body = jsonDecode(response.body);
//
//       if (response.statusCode == 200 && body['success'] == true) {
//         final token = body['token'];
//         final prefs = await SharedPreferences.getInstance();
//         await prefs.setString('jwt_token', token);
//
//         return {'success': true, 'token': token};
//       } else {
//         return {'success': false, 'message': body['message'] ?? 'Login failed'};
//       }
//     } catch (e) {
//       return {'success': false, 'message': 'Server error: $e'};
//     }
//   }
//
//   // Request verification (select hospital)
//   static Future<Map<String, dynamic>> requestVerification(String hospitalId) async {
//     final prefs = await SharedPreferences.getInstance();
//     final token = prefs.getString('jwt_token');
//
//     final url = Uri.parse("http://192.168.0.127:5000/api/v1/hospitals/request");
//     try {
//       final response = await http.post(
//         url,
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $token'
//         },
//         body: jsonEncode({'hospitalId': hospitalId}),
//       );
//
//       final responseBody = jsonDecode(response.body);
//
//       if (response.statusCode == 200 && responseBody['success'] == true) {
//         return {'success': true, 'message': responseBody['message']};
//       } else {
//         return {'success': false, 'message': responseBody['message'] ?? 'Failed to request verification'};
//       }
//     } catch (e) {
//       print('Error requesting verification: $e');
//       return {'success': false, 'message': 'Could not connect to server.'};
//     }
//   }
// }


import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Base URL configuration
  static const String _baseUrl = "https://emergency-vehicle-app.onrender.com/api/v1";
  //static const String _baseUrl = "http://192.168.0.127:5000/api/v1";


  // API Endpoints
  static const String _authRegister = "/auth/register";
  static const String _authLogin = "/auth/login";
  static const String _hospitalsGet = "/hospitals";
  static const String _hospitalsRequest = "/hospitals/request";

  // Helper method to build complete URL
  static String _buildUrl(String endpoint) {
    return _baseUrl + endpoint;
  }

  // Helper method to get headers with authorization
  static Future<Map<String, String>> _getHeaders({bool needsAuth = false}) async {
    final headers = {'Content-Type': 'application/json; charset=UTF-8'};

    if (needsAuth) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // Fetch hospitals
  static Future<List<dynamic>> getHospitals() async {
    final url = Uri.parse(_buildUrl(_hospitalsGet));

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['hospitals'] ?? [];
      } else {
        print('Error: Server returned ${response.statusCode}');
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
    final url = Uri.parse(_buildUrl(_authRegister));
    final headers = await _getHeaders();

    try {
      final response = await http.post(
        url,
        headers: headers,
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

  // Login method
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse(_buildUrl(_authLogin));
    final headers = await _getHeaders();

    try {
      final response = await http.post(
        url,
        headers: headers,
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
    final url = Uri.parse(_buildUrl(_hospitalsRequest));
    final headers = await _getHeaders(needsAuth: true);

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'hospitalId': hospitalId}),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 && responseBody['success'] == true) {
        return {'success': true, 'message': responseBody['message']};
      } else {
        return {
          'success': false,
          'message': responseBody['message'] ?? 'Failed to request verification'
        };
      }
    } catch (e) {
      print('Error requesting verification: $e');
      return {'success': false, 'message': 'Could not connect to server.'};
    }
  }
}