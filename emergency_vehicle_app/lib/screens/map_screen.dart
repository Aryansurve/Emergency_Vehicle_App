import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:geocoding/geocoding.dart';

import 'package:geolocator/geolocator.dart';

import 'package:http/http.dart' as http;

import 'dart:convert';

import 'dart:async';

import 'login_screen.dart';

import 'profile_screen.dart'; // Import the new profile screen

import '../services/api_service.dart'; // Make sure ApiService is imported

import 'package:socket_io_client/socket_io_client.dart' as IO;



class MapScreen extends StatefulWidget {

  const MapScreen({Key? key}) : super(key: key);



  @override

  State<MapScreen> createState() => _MapScreenState();

}



class _MapScreenState extends State<MapScreen> {



// --- ADD NEW SOCKET.IO STATE ---

  IO.Socket? _socket;

  Timer? _locationBroadcastTimer;



// --- STATE MANAGEMENT ---

  String _driverStatus = 'Offline';
  Map<String, dynamic>? _activeEmergency;
  bool _isDashboardLoading = true;
  Timer? _pollingTimer;
  bool _showManualRouteInput = false; // <-- NEW: Controls the UI view



// --- MAP & ROUTE STATE ---
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isPlanningRoute = false; // Controls which top bar UI to show
  LatLng? _sourceLocation;
  LatLng? _destinationLocation;
  bool _isRouteLoading = false;
  int _navigationStage = 0; // 0: Idle, 1: Navigating to patient, 2: Navigating to hospital
  Map<String, dynamic>? _assignedHospital;
  bool _isNavigating = false; // Tracks if navigation mode is active
  String? _errorMessage;
  String? _distance;
  String? _duration;

// Default camera position

  static const CameraPosition _initialPosition = CameraPosition(

    target: LatLng(19.2183, 72.9781), // Airoli, Maharashtra

    zoom: 12,

  );
  static const String _googleApiKey = 'AIzaSyCEZnD1f1rKoClsuqTCadrURkI75Z9VPVk';


  @override
  void initState() {

    super.initState();

    _loadInitialData();

    _checkLocationPermission();

    _initSocket(); // <-- Add this call

    _fetchAssignedHospital(); // <-- ADD THIS CALL

  }

  @override
  void dispose() {

    _pollingTimer?.cancel();
    _positionStreamSubscription?.cancel(); // <-- ADD THIS LINE
    _locationBroadcastTimer?.cancel(); // <-- Stop the new timer

    _socket?.disconnect(); // <-- Disconnect the socket

    _sourceController.dispose();

    _destinationController.dispose();

    _mapController?.dispose();

    super.dispose();

  }



  Future<void> _fetchAssignedHospital() async {
    final profileResult = await ApiService.getDriverProfile();
    if (profileResult['success'] == true && profileResult['data'] != null) {
      if (mounted) {
        setState(() {
          _assignedHospital = profileResult['data']['hospitalId'];
          // You might need to add error handling if hospitalId is null
          print("Assigned hospital data: $_assignedHospital");
        });
      }
    } else {
      print("Could not fetch driver profile to get assigned hospital.");
    }
  }
  String? _getUserIdFromToken(String token) {

    try {

      final payload = json.decode(utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))));

      return payload['id'];

    } catch (e) {

      return null;

    }

  }
  void _initSocket() async {

    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString('jwt_token');

    final userId = (token != null) ? _getUserIdFromToken(token) : null;



    if (userId == null) return;



    _socket = IO.io('http://192.168.0.127:5000', <String, dynamic>{

      'transports': ['websocket'],

      'autoConnect': true,

    });



    _socket!.connect();



    _socket!.onConnect((_) {

      print('🔌 Driver connected to socket server');

      _socket!.emit('driverOnline', userId);

    });



// **INSTANT MISSION LISTENER**

    _socket!.on('newMission', (data) {

      if (mounted && data is Map) {

        print('✅ New mission received instantly!');

        setState(() {

          _activeEmergency = Map<String, dynamic>.from(data);

          if (_activeEmergency != null) {

            _calculateMissionRoute();

          }

        });

      }

    });

  }
  void _startLocationBroadcast() {

    _locationBroadcastTimer?.cancel();

    _locationBroadcastTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {

      if (!mounted) return timer.cancel();

      try {

        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

        _socket?.emit('updateLocation', {

          'latitude': position.latitude,

          'longitude': position.longitude,

          'trackingId': _activeEmergency?['trackingId'],

        });

      } catch (e) {

        print("Could not get or send location: $e");

      }

    });

  }
  Future<void> _loadInitialData() async {

    await _fetchDriverStatus();

    if (mounted) setState(() => _isDashboardLoading = false);

  }
  Future<void> _fetchDriverStatus() async {

    final result = await ApiService.getDriverStatus();

    if (result['success'] == true && result['data'] != null && mounted) {

      setState(() => _driverStatus = result['data']['driverStatus']);

    }

  }
  void _pollForEmergency() {

    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {

      if (!mounted) return timer.cancel();

      if (_activeEmergency == null) {

        final result = await ApiService.getActiveEmergency();

        if (result['success'] == true && result['data'] != null && mounted) {

          setState(() {

            _activeEmergency = result['data'];

// --- NEW: AUTOMATICALLY CALCULATE ROUTE ON NEW MISSION ---

            if (_activeEmergency != null) {

              _calculateMissionRoute();

            }

          });

        }

      }

    });

  }
  Future<void> _handleUpdateEmergencyStatus(String newStatus) async {

    if (_activeEmergency == null) return;



    final emergencyId = _activeEmergency!['_id'];

    final result = await ApiService.updateEmergencyStatus(emergencyId, newStatus);



    if (result['success'] == true && mounted) {

// If the mission is over, clear it locally and refetch driver status

      if (newStatus == 'Resolved' || newStatus == 'Cancelled') {

        setState(() => _activeEmergency = null);

        _fetchDriverStatus(); // Driver status is now 'Available' on the server

      } else {

// Otherwise, just update the local emergency data with the latest from the server

        setState(() => _activeEmergency = result['data']);

      }

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text(result['message']), backgroundColor: Colors.green),

      );

    } else {

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text(result['message'] ?? 'An error occurred'), backgroundColor: Colors.red),

      );

    }

  }
  Future<void> _toggleAvailability(bool isAvailable) async {

    final newStatus = isAvailable ? 'Available' : 'Offline';

    final result = await ApiService.updateDriverStatus(newStatus);

    if (result['success'] == true && mounted) {

      setState(() => _driverStatus = newStatus);

      if (newStatus == 'Available') {

        _startLocationBroadcast();

      } else {

        _locationBroadcastTimer?.cancel();

      }

    }

  }
  Future<void> _logout() async {

    print("--- Logout Initiated ---"); // Debug Start

    try {

      print("Calling ApiService.logout..."); // Debug Before API Call

      await ApiService.logout(); // Calls the backend to blacklist token AND removes local token

      print("ApiService.logout completed."); // Debug After API Call

    } catch (e) {

      print("!!! ERROR during ApiService.logout: $e"); // Debug API Error

    }



// Crucially check if the widget is still mounted AFTER the await

    if (mounted) {

      print("Widget is mounted. Navigating to LoginScreen..."); // Debug Before Navigation

// Ensure LoginScreen is imported at the top of the file

// import 'login_screen.dart';

      Navigator.of(context).pushAndRemoveUntil(

        MaterialPageRoute(builder: (_) => const LoginScreen()), // Navigate

            (route) => false, // Clear history

      );

    } else {

      print("Logout attempted but widget was already unmounted."); // Debug Unmounted

    }

    print("--- Logout Function Finished ---"); // Debug End

  } Future<void> _calculateMissionRoute() async {

    if (_activeEmergency == null) return;



    setState(() {

      _isRouteLoading = true;

      _errorMessage = null;

      _markers.clear();

      _polylines.clear();

    });



    try {

// 1. Get driver's current location for the source

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      _sourceLocation = LatLng(position.latitude, position.longitude);



// 2. Get destination from the emergency data

      String destinationAddress = _activeEmergency!['location'];

      List<Location> destLocations = await locationFromAddress(destinationAddress);

      _destinationLocation = LatLng(destLocations[0].latitude, destLocations[0].longitude);



// 3. Call the existing API function to get the route and draw it

      await _getRouteFromRoutesAPI();



    } catch (e) {

      if (mounted) setState(() => _errorMessage = 'Error calculating mission route: $e');

    } finally {

      if (mounted) setState(() => _isRouteLoading = false);

    }

  }
  Future<void> _checkLocationPermission() async {

    bool serviceEnabled;

    LocationPermission permission;



// Check if location services are enabled

    serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {

      setState(() {

        _errorMessage = 'Location services are disabled. Please enable them.';

      });

      return;

    }



// Check location permission

    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {

      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {

        setState(() {

          _errorMessage = 'Location permissions are denied';

        });

        return;

      }

    }



    if (permission == LocationPermission.deniedForever) {

      setState(() {

        _errorMessage = 'Location permissions are permanently denied';

      });

      return;

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

      'origin': {'location': {'latLng': {'latitude': _sourceLocation!.latitude, 'longitude': _sourceLocation!.longitude}}},

      'destination': {'location': {'latLng': {'latitude': _destinationLocation!.latitude, 'longitude': _destinationLocation!.longitude}}},

      'travelMode': 'DRIVE',

      'routingPreference': 'TRAFFIC_AWARE',

    });



    final response = await http.post(url, headers: headers, body: body);



    if (response.statusCode == 200) {

      final data = jsonDecode(response.body);

      if (data['routes'] != null && data['routes'].isNotEmpty) {

        final route = data['routes'][0];



// Distance and Duration

        final distanceMeters = route['distanceMeters'];

        _distance = distanceMeters != null ? '${(distanceMeters / 1000).toStringAsFixed(2)} km' : null;



        final durationStr = route['duration'];

        if (durationStr != null) {

          int seconds = int.parse(durationStr.replaceAll('s', ''));

          _duration = '${(seconds / 60).round()} min';

        }



// Polyline

        String encodedPolyline = route['polyline']['encodedPolyline'];

        List<LatLng> polylineCoordinates = _decodePolyline(encodedPolyline);



        setState(() {

          _polylines.add(Polyline(polylineId: const PolylineId('route'), color: Colors.blue, width: 5, points: polylineCoordinates));

          _markers.add(Marker(markerId: const MarkerId('source'), position: _sourceLocation!, infoWindow: InfoWindow(title: 'Source')));

          _markers.add(Marker(markerId: const MarkerId('destination'), position: _destinationLocation!, infoWindow: InfoWindow(title: 'Destination')));

        });



// Animate camera to show the full route

        if (_sourceLocation != null && _destinationLocation != null) {

// Determine the bounds of the route

          LatLng southwest = LatLng(

            _sourceLocation!.latitude < _destinationLocation!.latitude

                ? _sourceLocation!.latitude

                : _destinationLocation!.latitude,

            _sourceLocation!.longitude < _destinationLocation!.longitude

                ? _sourceLocation!.longitude

                : _destinationLocation!.longitude,

          );

          LatLng northeast = LatLng(

            _sourceLocation!.latitude > _destinationLocation!.latitude

                ? _sourceLocation!.latitude

                : _destinationLocation!.latitude,

            _sourceLocation!.longitude > _destinationLocation!.longitude

                ? _sourceLocation!.longitude

                : _destinationLocation!.longitude,

          );



// Animate the camera to fit these bounds with some padding

          _mapController?.animateCamera(

            CameraUpdate.newLatLngBounds(

              LatLngBounds(southwest: southwest, northeast: northeast),

              80.0, // This padding ensures the markers aren't at the very edge of the screen

            ),

          );

        }

      }

    } else {

      throw Exception('Failed to get route from API');

    }

  }
  List<LatLng> _decodePolyline(String encoded) {

    List<LatLng> points = [];

    int index = 0, len = encoded.length;

    int lat = 0, lng = 0;

    while (index < len) {

      int b, shift = 0, result = 0;

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
  Future<void> _getManualRoute() async {

    String sourceInput = _sourceController.text.trim();

    String destinationInput = _destinationController.text.trim();



    print("--- Starting Manual Route ---");

    print("Source Input: '$sourceInput'");

    print("Destination Input: '$destinationInput'");

    print("Is Route Planning UI Active? $_isPlanningRoute"); // Check the correct variable



    if (destinationInput.isEmpty) {

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a destination.')));

      return;

    }



    setState(() { /* ... reset loading state ... */ });



    try {

      bool useCurrentLocationAsSource = false;



// --- CORRECTED SOURCE LOGIC ---

// Check if the route planning UI is active AND the source field has text

      if (_isPlanningRoute && sourceInput.isNotEmpty) { // <-- USE _isPlanningRoute HERE

        print("Attempting to geocode source: '$sourceInput'");

        List<Location> sourceLocs = await locationFromAddress(sourceInput);

        if (sourceLocs.isEmpty) throw Exception("Could not geocode source address");

        _sourceLocation = LatLng(sourceLocs.first.latitude, sourceLocs.first.longitude);

        print("Source Geocoded: $_sourceLocation");

      } else {

        print("Using current GPS location as source.");

        useCurrentLocationAsSource = true;

        Position currentPos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

        _sourceLocation = LatLng(currentPos.latitude, currentPos.longitude);

        print("Current Location Fetched: $_sourceLocation");

// Only update text field if route planning UI was NOT active

        if (!_isPlanningRoute && mounted) {

          _sourceController.text = "My Current Location";

        }

      }

// --- END OF CORRECTED SOURCE LOGIC ---



      print("Attempting to geocode destination: '$destinationInput'");

      List<Location> destLocs = await locationFromAddress(destinationInput);

      if (destLocs.isEmpty) throw Exception("Could not geocode destination address");

      _destinationLocation = LatLng(destLocs.first.latitude, destLocs.first.longitude);

      print("Destination Geocoded: $_destinationLocation");



      print("Calling Google Routes API...");

      await _getRouteFromRoutesAPI();

      print("Route API call finished.");



// Update source text only if GPS was used AND route planning UI was NOT active

      if (useCurrentLocationAsSource && !_isPlanningRoute && mounted) { // <-- USE _isPlanningRoute HERE

        _sourceController.text = "My Current Location";

        print("Set source text field to 'My Current Location'");

      }



    } catch(e) { /* ... error handling ... */ }

    finally { /* ... reset loading state ... */ }

  } Future<void> _goToCurrentLocation() async {

    try {

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      _mapController?.animateCamera(

        CameraUpdate.newLatLngZoom(

          LatLng(position.latitude, position.longitude),

          15.0, // Zoom level

        ),

      );

    } catch (e) {

      print("Error getting current location: $e");

      if(mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

            const SnackBar(content: Text('Could not get current location.'))

        );

      }

    }

  }
  void _startNavigation() {
    print("Start Navigation (Stage 1: To Patient)");
    print("Destination: $_destinationLocation");

    if (_destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Destination not set.')),
      );
      return;
    }

    // Cancel any previous GPS subscription
    _positionStreamSubscription?.cancel();

    setState(() {
      _isNavigating = true;
      _navigationStage = 1; // Stage 1: Navigating to patient
      _isPlanningRoute = false; // Hide planning UI if it was open
    });

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update roughly every 10 meters
      ),
    ).listen((Position position) {
      LatLng currentLatLng = LatLng(position.latitude, position.longitude);

      // Animate camera to follow driver
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: currentLatLng,
            zoom: 17.0,
            bearing: position.heading,
            tilt: 50.0,
          ),
        ),
      );

      // --- ARRIVAL DETECTION ---
      // Check only when navigating to the patient (stage 1)
      if (_navigationStage == 1 && _destinationLocation != null) {
        double distanceInMeters = Geolocator.distanceBetween(
          currentLatLng.latitude,
          currentLatLng.longitude,
          _destinationLocation!.latitude,
          _destinationLocation!.longitude,
        );

        // Check if driver is within 50 meters of the destination
        if (distanceInMeters < 50) {
          print("✅ Arrived at patient location!");
          _positionStreamSubscription?.cancel(); // Stop tracking temporarily
          _positionStreamSubscription = null;

          // Update state BEFORE showing dialog
          setState(() => _isNavigating = false); // Temporarily stop navigation state
          _showHospitalChoiceDialog(currentLatLng); // Show popup to choose hospital
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigating to patient location...')),
    );
  }
// --- ADD FUNCTION 1: Show Hospital Choice ---
  Future<void> _showHospitalChoiceDialog(LatLng currentPosition) async {
    // Vibration import needed: import 'package:vibration/vibration.dart';



    // --- Simulate Finding Nearest Hospital ---
    LatLng nearestHospitalCoords = const LatLng(19.0760, 72.8777); // Placeholder
    String nearestHospitalName = "Simulated Nearest Hospital";
    // --- End Simulation ---

    String assignedHospitalName = _assignedHospital?['name'] ?? "Assigned Hospital";
    // TODO: Get actual coordinates for the assigned hospital from _assignedHospital map
    // For now, using a placeholder
    LatLng assignedHospitalCoords = const LatLng(19.0600, 72.8900); // Placeholder

    // Ensure context is valid before showing dialog
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Patient Picked Up'),
          content: const Text('Choose destination hospital:'),
          actions: <Widget>[
            TextButton(
              child: Text('Nearest: $nearestHospitalName'),
              onPressed: () {
                Navigator.of(context).pop();
                _startNavigationToHospital(currentPosition, nearestHospitalCoords, nearestHospitalName);
              },
            ),
            TextButton(
              child: Text('Assigned: $assignedHospitalName'),
              onPressed: () {
                Navigator.of(context).pop();
                _startNavigationToHospital(currentPosition, assignedHospitalCoords, assignedHospitalName);
              },
            ),
          ],
        );
      },
    );
  }

// --- ADD FUNCTION 2: Start Navigation to Hospital ---
  Future<void> _startNavigationToHospital(LatLng startPosition, LatLng hospitalCoords, String hospitalName) async {
    print("Starting Navigation (Stage 2: To Hospital - $hospitalName)");




    setState(() {
      _isRouteLoading = true;
      _errorMessage = null;
      _polylines.clear();
      _markers.clear();
      _distance = null;
      _duration = null;
      _sourceLocation = startPosition; // Patient location is new source
      _destinationLocation = hospitalCoords; // Hospital is new destination
    });

    try {
      await _getRouteFromRoutesAPI(); // Calculate the hospital route
      _startFollowingStreamForHospital(); // Start GPS tracking for 2nd leg
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Could not calculate route to hospital.");
    } finally {
      if (mounted) setState(() => _isRouteLoading = false);
    }
  }

// --- ADD FUNCTION 3: Start GPS Following for Hospital Leg ---
  void _startFollowingStreamForHospital() {
    _positionStreamSubscription?.cancel();

    setState(() {
      _isNavigating = true; // Re-enter navigation state
      _navigationStage = 2; // Stage 2: To hospital
    });

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((Position position) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 17.0,
            bearing: position.heading,
            tilt: 50.0,
          ),
        ),
      );
      // Optional: Add arrival detection for the hospital here
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigating to hospital...')),
    );
  }
  void _stopNavigation() {
    print("Stop Navigation button pressed!");
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    setState(() {
      _isNavigating = false;
      _navigationStage = 0; // Reset stage to Idle
      // Optionally clear route visuals if you want
      // _polylines.clear();
      // _markers.clear();
      // _distance = null;
      // _duration = null;
    });

    // Reset camera to default view
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(_initialPosition),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigation stopped.')),
    );
  }

// --- MAIN BUILD METHOD (with the duplicate removed) ---

  @override

  Widget build(BuildContext context) {

    return Scaffold(

// The body is now a Stack

      body: Stack(

        children: [

// LAYER 1: The Google Map

          GoogleMap(

            initialCameraPosition: _initialPosition,

            markers: _markers,

            polylines: _polylines,

            onMapCreated: (controller) => _mapController = controller,

            myLocationEnabled: true,

            myLocationButtonEnabled: false,

            trafficEnabled: true,

            zoomControlsEnabled: false,

            padding: EdgeInsets.only(bottom: 100, top: 100),

          ),



// LAYER 2: The UI elements

          if (_isDashboardLoading)

            const Center(child: CircularProgressIndicator())

          else if (_activeEmergency != null)

            SafeArea(child: _buildMissionView())

          else

            _buildStandbyUI(), // This includes the search bar, FABs, etc.



// --- NEW: LAYER 3 - START NAVIGATION BUTTON ---

// Show this button only when a route is displayed and not on a mission

          if (_polylines.isNotEmpty && _activeEmergency == null)

            Positioned(

              bottom: 120, // Adjust position to be above the availability card

              left: 0,

              right: 0,

              child: Center(

                child: Padding(

                  padding: const EdgeInsets.symmetric(horizontal: 50.0),

                  child: ElevatedButton.icon(

                    icon: const Icon(Icons.navigation_rounded),

                    label: const Text("Start Navigation"),

                    style: ElevatedButton.styleFrom(

                      backgroundColor: Colors.blue, // Navigation color

                      foregroundColor: Colors.white,

                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),

                      shape: RoundedRectangleBorder(

                        borderRadius: BorderRadius.circular(30.0),

                      ),

                    ),

                    onPressed: _startNavigation, // Call the navigation function

                  ),

                ),

              ),

            ),
          // --- UPDATED: LAYER 3 - NAVIGATION CONTROL BUTTON ---
          if (_polylines.isNotEmpty && _activeEmergency == null)
            Positioned(
              bottom: 120, // Adjust position as needed
              left: 0,
              right: 0,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 50.0),
                  child: ElevatedButton.icon(
                    // Change icon, label, color, and action based on _isNavigating state
                    icon: Icon(_isNavigating ? Icons.stop_circle_outlined : Icons.navigation_rounded),
                    label: Text(_isNavigating ? "Stop Navigation" : "Start Navigation"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isNavigating ? Colors.red : Colors.blue, // Red for stop, Blue for start
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                    ),
                    // Call appropriate function based on state
                    onPressed: _isNavigating ? _stopNavigation : _startNavigation,
                  ),
                ),
              ),
            ),
// --- END OF START NAVIGATION BUTTON ---

        ],

      ),

    );

  }
  Widget _buildSearchBar() {

    return TextField(

// controller: _searchController, // You'll need to declare _searchController if you want search functionality

      decoration: InputDecoration(

        hintText: 'Search here',

        border: InputBorder.none,

        prefixIcon: const Icon(Icons.search),

        suffixIcon: Row(

          mainAxisSize: MainAxisSize.min,

          children: [

// Placeholder icons - add functionality later if needed

// const Icon(Icons.mic),

// const SizedBox(width: 8),

// --- PROFILE BUTTON ---

            PopupMenuButton<String>(

              onSelected: (value) {

                if (value == 'profile') {

                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())); // Assumes ProfileScreen exists

                } else if (value == 'logout') {

                  _logout();

                }

              },

              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[

                const PopupMenuItem<String>(value: 'profile', child: Text('My Profile')),

                const PopupMenuItem<String>(value: 'logout', child: Text('Logout')),

              ],

              child: const CircleAvatar(

                radius: 15,

                child: Icon(Icons.person, size: 18), // Or display user initials/image

              ),

            ),

            const SizedBox(width: 12), // Padding for the profile icon

          ],

        ),

        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),

      ),

      onTap: () {

// You could potentially switch to a dedicated search screen here

        print("Search tapped");

      },

    );

  }
  Widget _buildRoutePlanningBar() {

    return Column(

      mainAxisSize: MainAxisSize.min, // Keeps column compact

      children: [

// --- SOURCE TEXTFIELD ---

        TextField( // Source TextField

          controller: _sourceController,

          decoration: InputDecoration(

              hintText: 'Choose starting point, or click map',

              border: InputBorder.none,

              prefixIcon: const Icon(Icons.my_location, color: Colors.blue), // <-- This is the icon to remove

              suffixIcon: IconButton(

                icon: const Icon(Icons.close),

                onPressed: () => setState(() => _isPlanningRoute = false),

              )

          ),

        ),



        const Divider(height: 1, thickness: 1),



// --- DESTINATION TEXTFIELD + BUTTON ---

        Row(

          children: [

            Expanded(

              child: TextField(

                controller: _destinationController,

                decoration: const InputDecoration(

                  hintText: 'Choose destination',

                  border: InputBorder.none,

                  prefixIcon: Icon(Icons.flag, color: Colors.red),

                ),

                onSubmitted: (_) => _getManualRoute(), // Trigger route search

              ),

            ),



// --- "GO" BUTTON OR LOADING INDICATOR ---

            _isRouteLoading

                ? const Padding(

              padding: EdgeInsets.all(8.0),

              child: SizedBox(

                width: 24,

                height: 24,

                child: CircularProgressIndicator(strokeWidth: 3),

              ),

            )

                : IconButton(

              icon: const Icon(Icons.send, color: Colors.green),

              tooltip: 'Find Route',

              onPressed: _getManualRoute,

            ),

          ],

        ),

      ],

    );

  }
  Widget _buildMissionView() {

    final emergency = _activeEmergency!;

    final status = emergency['status'];



    return Padding(

      padding: const EdgeInsets.all(16.0),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [

          Text('ACTIVE MISSION', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red[700])),

          const Divider(thickness: 1.5),

          const SizedBox(height: 8),

          _buildInfoRow(Icons.location_on, 'Location:', emergency['location']),

          _buildInfoRow(Icons.description, 'Details:', emergency['details']),

          _buildInfoRow(Icons.warning_amber, 'Status:', status, isStatus: true),

          const Spacer(),

// These buttons appear based on the current mission status

          if (status == 'Assigned' || status == 'En Route')

            _buildActionButton(

              'Mark as On Scene',

              Icons.local_hospital,

              Colors.orange,

                  () => _handleUpdateEmergencyStatus('On Scene'),

            ),

          if (status == 'On Scene')

            _buildActionButton(

              'Resolve Mission',

              Icons.check_circle,

              Colors.green,

                  () => _handleUpdateEmergencyStatus('Resolved'),

            ),

        ],

      ),

    );

  }
  Widget _buildStandbyUI() {

    return SafeArea(

      child: Column(

        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Pushes elements to top and bottom

        children: [

// Top Search/Route Bar Area

          Padding(

            padding: const EdgeInsets.all(12.0),

            child: Card(

              elevation: 8,

              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),

// This switches between the search bar and the route planning inputs

              child: _isPlanningRoute ? _buildRoutePlanningBar() : _buildSearchBar(),

            ),

          ),



// FABs on the bottom right

          Align(

            alignment: Alignment.bottomRight, // Position bottom-right

            child: Padding(

              padding: const EdgeInsets.only(right: 16.0, bottom: 16.0),

              child: Column(

                mainAxisSize: MainAxisSize.min, // Keep column compact

                children: [

                  FloatingActionButton(

                    heroTag: 'directions_fab',

                    mini: true,

                    backgroundColor: Colors.white,

                    tooltip: 'Plan Route',

                    child: Icon(Icons.directions, color: Theme.of(context).primaryColor),

                    onPressed: () => setState(() => _isPlanningRoute = true),

                  ),

                  const SizedBox(height: 10),

                  FloatingActionButton(

                    heroTag: 'location_fab',

                    tooltip: 'My Location',

                    child: const Icon(Icons.my_location),

                    onPressed: _goToCurrentLocation,

                  ),

                ],

              ),

            ),

          ),



// Availability Toggle Card at the very bottom

          _buildAvailabilityCard(),

        ],

      ),

    );

  }
  Widget _buildAvailabilityCard() {

    return Card(

      margin: const EdgeInsets.all(12),

      elevation: 4, // Add some shadow

      child: ListTile(

        title: const Text('My Availability'),

        subtitle: Text('You are currently $_driverStatus'),

        trailing: Switch(

          value: _driverStatus == 'Available',

          onChanged: _toggleAvailability,

        ),

      ),

    );

  }
  Widget _buildInfoRow(IconData icon, String label, String value, {bool isStatus = false}) {

    return Padding(

      padding: const EdgeInsets.symmetric(vertical: 4.0),

      child: Row(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Icon(icon, color: Colors.grey[600], size: 20),

          const SizedBox(width: 8),

          Text('$label ', style: const TextStyle(fontWeight: FontWeight.bold)),

          Expanded(

            child: Text(

              value,

              style: isStatus

                  ? TextStyle(fontStyle: FontStyle.italic, color: Colors.blue[700])

                  : null,

            ),

          ),

        ],

      ),

    );

  }
  Widget _buildActionButton(String text, IconData icon, Color color, VoidCallback onPressed) {

    return ElevatedButton.icon(

      icon: Icon(icon),

      label: Text(text, style: const TextStyle(fontSize: 16)),

      onPressed: onPressed,

      style: ElevatedButton.styleFrom(

        backgroundColor: color,

        padding: const EdgeInsets.symmetric(vertical: 12),

      ),

    );

  }



}