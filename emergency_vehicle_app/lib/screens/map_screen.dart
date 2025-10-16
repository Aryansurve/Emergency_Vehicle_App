// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'login_screen.dart';
//
// class MapScreen extends StatelessWidget {
//   const MapScreen({Key? key}) : super(key: key);
//
//   // Reusable logout function
//   Future<void> _logout(BuildContext context) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove('jwt_token');
//
//     if (!context.mounted) return;
//
//     // Navigate back to the login screen, removing all previous routes
//     Navigator.of(context).pushAndRemoveUntil(
//       MaterialPageRoute(builder: (_) => const LoginScreen()),
//           (Route<dynamic> route) => false,
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Dashboard'),
//         automaticallyImplyLeading: false, // Removes the back button
//         actions: [
//           // Logout Button
//           IconButton(
//             icon: const Icon(Icons.logout),
//             onPressed: () => _logout(context),
//             tooltip: 'Logout',
//           ),
//         ],
//       ),
//       body: Column(
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         children: [
//           Container(
//             padding: const EdgeInsets.all(16),
//             color: Colors.green[600],
//             child: const Text(
//               'Account Verified. Full access granted.',
//               style: TextStyle(color: Colors.white, fontSize: 16),
//               textAlign: TextAlign.center,
//             ),
//           ),
//           Expanded(
//             child: Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   const Icon(Icons.map_sharp, size: 100, color: Colors.green),
//                   const SizedBox(height: 20),
//                   const Text(
//                     'Map Functionality Here',
//                     style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//                   ),
//                   Padding(
//                     padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 10.0),
//                     child: Text(
//                       'This is where you would integrate the Google Maps widget for route prioritization.',
//                       textAlign: TextAlign.center,
//                       style: TextStyle(fontSize: 16, color: Colors.grey[700]),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'login_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _sourceLocation;
  LatLng? _destinationLocation;
  bool _isLoading = false;
  String? _errorMessage;
  String? _distance;
  String? _duration;

  // Default camera position
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(19.2183, 72.9781), // Airoli, Maharashtra
    zoom: 12,
  );

  // Replace with your actual Google Maps API Key
  static const String _googleApiKey = 'AIzaSyCEZnD1f1rKoClsuqTCadrURkI75Z9VPVk';

  @override
  void dispose() {
    _sourceController.dispose();
    _destinationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (Route<dynamic> route) => false,
    );
  }

  Future<void> _getRoute() async {
    if (_sourceController.text.isEmpty || _destinationController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both source and destination';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _markers.clear();
      _polylines.clear();
      _distance = null;
      _duration = null;
    });

    try {
      // Geocode source address
      List<Location> sourceLocations = await locationFromAddress(_sourceController.text);
      _sourceLocation = LatLng(sourceLocations[0].latitude, sourceLocations[0].longitude);

      // Geocode destination address
      List<Location> destLocations = await locationFromAddress(_destinationController.text);
      _destinationLocation = LatLng(destLocations[0].latitude, destLocations[0].longitude);

      // Add markers
      _markers.add(
        Marker(
          markerId: const MarkerId('source'),
          position: _sourceLocation!,
          infoWindow: InfoWindow(title: 'Source', snippet: _sourceController.text),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );

      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLocation!,
          infoWindow: InfoWindow(title: 'Destination', snippet: _destinationController.text),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );

      // Get route using Routes API (new)
      await _getRouteFromRoutesAPI();

      // Adjust camera to show both markers
      if (_sourceLocation != null && _destinationLocation != null) {
        LatLngBounds bounds = LatLngBounds(
          southwest: LatLng(
            _sourceLocation!.latitude < _destinationLocation!.latitude
                ? _sourceLocation!.latitude
                : _destinationLocation!.latitude,
            _sourceLocation!.longitude < _destinationLocation!.longitude
                ? _sourceLocation!.longitude
                : _destinationLocation!.longitude,
          ),
          northeast: LatLng(
            _sourceLocation!.latitude > _destinationLocation!.latitude
                ? _sourceLocation!.latitude
                : _destinationLocation!.latitude,
            _sourceLocation!.longitude > _destinationLocation!.longitude
                ? _sourceLocation!.longitude
                : _destinationLocation!.longitude,
          ),
        );

        _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getRouteFromRoutesAPI() async {
    final url = Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes');

    final headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': _googleApiKey,
      'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline',
    };

    final body = jsonEncode({
      'origin': {
        'location': {
          'latLng': {
            'latitude': _sourceLocation!.latitude,
            'longitude': _sourceLocation!.longitude,
          }
        }
      },
      'destination': {
        'location': {
          'latLng': {
            'latitude': _destinationLocation!.latitude,
            'longitude': _destinationLocation!.longitude,
          }
        }
      },
      'travelMode': 'DRIVE',
      'routingPreference': 'TRAFFIC_AWARE',
      'computeAlternativeRoutes': false,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];

          // Get distance and duration
          if (route['distanceMeters'] != null) {
            double distanceKm = route['distanceMeters'] / 1000;
            _distance = '${distanceKm.toStringAsFixed(2)} km';
          }

          if (route['duration'] != null) {
            String durationStr = route['duration'];
            // Remove 's' from duration string (e.g., "3600s" -> "3600")
            int seconds = int.parse(durationStr.replaceAll('s', ''));
            int minutes = (seconds / 60).round();
            _duration = '$minutes min';
          }

          // Decode polyline
          String encodedPolyline = route['polyline']['encodedPolyline'];
          List<LatLng> polylineCoordinates = _decodePolyline(encodedPolyline);

          setState(() {
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('route'),
                color: Colors.blue,
                width: 5,
                points: polylineCoordinates,
              ),
            );
          });
        } else {
          setState(() {
            _errorMessage = 'No route found';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Error getting route: ${response.statusCode}\n${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: ${e.toString()}';
      });
    }
  }

  // Decode polyline from encoded string
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green[600],
            child: const Text(
              'Account Verified. Full access granted.',
              style: TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _sourceController,
                  decoration: InputDecoration(
                    labelText: 'Source',
                    hintText: 'Enter source location',
                    prefixIcon: const Icon(Icons.location_on, color: Colors.green),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _destinationController,
                  decoration: InputDecoration(
                    labelText: 'Destination',
                    hintText: 'Enter destination location',
                    prefixIcon: const Icon(Icons.flag, color: Colors.red),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _getRoute,
                    icon: _isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Icon(Icons.directions),
                    label: Text(_isLoading ? 'Finding Route...' : 'Get Shortest Route'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (_distance != null || _duration != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_distance != null) ...[
                          const Icon(Icons.straighten, size: 16, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(_distance!, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 16),
                        ],
                        if (_duration != null) ...[
                          const Icon(Icons.access_time, size: 16, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(_duration!, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: _initialPosition,
              markers: _markers,
              polylines: _polylines,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              mapType: MapType.normal,
              zoomControlsEnabled: true,
            ),
          ),
        ],
      ),
    );
  }
}