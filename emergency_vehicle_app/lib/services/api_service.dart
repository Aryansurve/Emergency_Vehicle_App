import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // --- CONFIGURATION ---
  static const String _baseUrl = "http://192.168.0.127:5000/api/v1";

  // --- HELPER METHODS ---
  static Uri _buildUri(String path) => Uri.parse(_baseUrl + path);

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

  // --- AUTH ENDPOINTS ---
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        _buildUri('/auth/login'),
        headers: await _getHeaders(),
        body: jsonEncode({'email': email, 'password': password}),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', body['token']);
        return {'success': true};
      }
      return {'success': false, 'message': body['message'] ?? 'Login failed'};
    } catch (e) {
      return {'success': false, 'message': 'Server connection failed: $e'};
    }
  }

  // NEW: Separate registration for drivers
  static Future<Map<String, dynamic>> registerDriver(Map<String, String> data) async {
    try {
      final response = await http.post(
        _buildUri('/auth/register/driver'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Server connection failed: $e'};
    }
  }

  // NEW: Separate registration for public users
  static Future<Map<String, dynamic>> registerPublicUser(Map<String, String> data) async {
    try {
      final response = await http.post(
        _buildUri('/auth/register/user'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
      final body = jsonDecode(response.body);
      // Auto-login the public user after registration
      if (body['success'] == true && body['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', body['token']);
      }
      return body;
    } catch (e) {
      return {'success': false, 'message': 'Server connection failed: $e'};
    }
  }

  // --- PUBLIC/GENERAL ENDPOINTS ---
  static Future<List<dynamic>> getHospitals() async {
    try {
      final response = await http.get(_buildUri('/hospitals'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['hospitals'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // --- HOSPITAL ADMIN ENDPOINTS ---
  static Future<List<dynamic>> getPendingDriversForHospital() async {
    try {
      final response = await http.get(
        _buildUri('/hospital-admin/pending-drivers'),
        headers: await _getHeaders(needsAuth: true),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['data'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> approveDriverByHospital(String driverId) async {
    try {
      final response = await http.put(
        _buildUri('/hospital-admin/approve/$driverId'),
        headers: await _getHeaders(needsAuth: true),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Server connection failed: $e'};
    }
  }

  static Future<Map<String, dynamic>> rejectDriverByHospital(String driverId, String reason) async {
    try {
      final response = await http.put(
        _buildUri('/hospital-admin/reject/$driverId'),
        headers: await _getHeaders(needsAuth: true),
        body: jsonEncode({'reason': reason}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Server connection failed: $e'};
    }
  }

  // --- PLATFORM ADMIN ENDPOINTS ---
  static Future<List<dynamic>> getPendingDriversForPlatform() async {
    try {
      final response = await http.get(
        _buildUri('/admin/pending-users'),
        headers: await _getHeaders(needsAuth: true),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['data'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> verifyUserByPlatform(String userId) async {
    try {
      final response = await http.put(
        _buildUri('/admin/verify/$userId'),
        headers: await _getHeaders(needsAuth: true),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Server connection failed: $e'};
    }
  }

  // --- NEW LOGOUT METHOD ---
  static Future<void> logout() async {
    try {
      // Tell the server to blacklist the token. We don't need to handle the response
      // because we are logging out regardless of whether the server call succeeds.
      await http.post(
        _buildUri('/auth/logout'),
        headers: await _getHeaders(needsAuth: true),
      );
    } catch (e) {
      // Log the error but don't prevent the user from logging out
      print('Error during server-side logout: $e');
    } finally {
      // ALWAYS clear the local token and log the user out
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('jwt_token');
    }
  }

  // --- NEW DISPATCH ENDPOINTS (for Platform Admin) ---

  static Future<List<dynamic>> getUnassignedEmergencies() async {
    try {
      final response = await http.get(
        _buildUri('/admin/emergencies/unassigned'),
        headers: await _getHeaders(needsAuth: true),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['data'] ?? [];
      }
      return [];
    } catch (e) {
      print('Error fetching unassigned emergencies: $e');
      return [];
    }
  }

  static Future<List<dynamic>> getAvailableDrivers() async {
    try {
      final response = await http.get(
        _buildUri('/admin/drivers/available'),
        headers: await _getHeaders(needsAuth: true),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['data'] ?? [];
      }
      return [];
    } catch (e) {
      print('Error fetching available drivers: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> assignEmergency(String emergencyId, String driverId) async {
    try {
      final response = await http.put(
        _buildUri('/admin/emergencies/assign'),
        headers: await _getHeaders(needsAuth: true),
        body: jsonEncode({
          'emergencyId': emergencyId,
          'driverId': driverId,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Server connection failed: $e'};
    }
  }

  // --- NEW DRIVER-SPECIFIC ENDPOINTS ---

  static Future<Map<String, dynamic>> getDriverStatus() async {
    try {
      final response = await http.get(
        _buildUri('/driver/status'),
        headers: await _getHeaders(needsAuth: true),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'Failed to fetch status'};
    } catch (e) {
      return {'success': false, 'message': 'Server connection error'};
    }
  }

  static Future<Map<String, dynamic>> updateDriverStatus(String status) async {
    try {
      final response = await http.put(
        _buildUri('/driver/status/update'),
        headers: await _getHeaders(needsAuth: true),
        body: jsonEncode({'status': status}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Server connection error'};
    }
  }
  static Future<Map<String, dynamic>> updateEmergencyStatus(String emergencyId, String status) async {
    try {
      final response = await http.put(
        _buildUri('/driver/emergency/update-status'),
        headers: await _getHeaders(needsAuth: true),
        body: jsonEncode({
          'emergencyId': emergencyId,
          'status': status,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Server connection error'};
    }
  }

  static Future<Map<String, dynamic>> rejectUserByPlatform(String userId, String reason) async {
    try {
      final response = await http.put(
        _buildUri('/admin/reject/$userId'),
        headers: await _getHeaders(needsAuth: true),
        body: jsonEncode({'reason': reason}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Server connection failed: $e'};
    }
  }
  // --- NEW: PUBLIC USER EMERGENCY ENDPOINTS ---

  static Future<Map<String, dynamic>> createEmergency(String location, String details) async {
    try {
      final response = await http.post(
        _buildUri('/public/emergency/create'),
        headers: await _getHeaders(needsAuth: true),
        body: jsonEncode({
          'location': location,
          'details': details,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Server connection failed: $e'};
    }
  }

  static Future<Map<String, dynamic>> trackEmergency(String trackingId) async {
    try {
      final response = await http.get(
        _buildUri('/public/emergency/$trackingId'),
        headers: await _getHeaders(needsAuth: true),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Server connection failed: $e'};
    }
  }

  // ... inside ApiService class

  static Future<Map<String, dynamic>> getDriverProfile() async {
    try {
      final response = await http.get(
        _buildUri('/driver/profile'),
        headers: await _getHeaders(needsAuth: true),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Server connection failed: $e'};
    }
  }

  static Future<Map<String, dynamic>> getActiveEmergency() async {
    try {
      final response = await http.get(
        _buildUri('/driver/active-emergency'),
        headers: await _getHeaders(needsAuth: true),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'Failed to fetch emergency'};
    } catch (e) {
      return {'success': false, 'message': 'Server connection error'};
    }
  }
}