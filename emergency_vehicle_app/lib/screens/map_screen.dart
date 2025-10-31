import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart'; // For formatting ETA time
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

  final Set<int> _preemptionApiSent = {};

// --- STATE MANAGEMENT ---

  // --- ADD THESE NEW SIMULATION VARIABLES ---
  Timer? _simulationTimer;
  int _simulationIndex = 0;
  int _lastPassedSignalIndex = -1;
  List<Marker> _sortedSignalMarkers = [];
  BitmapDescriptor _signalIconGreen = BitmapDescriptor.defaultMarker;
  BitmapDescriptor _signalIconRed = BitmapDescriptor.defaultMarker;
  // --- END OF NEW VARIABLES ---

  final Set<Marker> _trafficSignalMarkers = {}; // <-- NEW: For signals
  BitmapDescriptor _trafficSignalIcon = BitmapDescriptor.defaultMarker; // <-- NEW: For custom icon
  BitmapDescriptor _userArrowIcon = BitmapDescriptor.defaultMarker; // <-- ADD THIS LINE
  String _driverStatus = 'Offline';
  Map<String, dynamic>? _activeEmergency;
  bool _isDashboardLoading = true;
  Timer? _pollingTimer;
  bool _showManualRouteInput = false; // <-- NEW: Controls the UI view



// --- MAP & ROUTE STATE ---
  final Map<String, BitmapDescriptor> _maneuverIcons = {}; // <-- This one stays
  final Map<String, String> _maneuverIconPaths = {}; // <-- ADD THIS NEW MAP

  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  List<LatLng> _routePolylinePoints = []; // <-- NEW: To store all points for filtering
  final Set<Polyline> _polylines = {};
  int _durationInSeconds = 0; // <-- NEW: To calculate ETA
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
  List<Map<String, dynamic>> _navigationSteps = []; // <-- NEW: To store maneuver steps
// Default camera position
  Map<String, dynamic>? _currentNavStep; // <-- NEW: To display the current instruction


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
    _loadCustomIcons();
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

// --- ADD THIS NEW FUNCTION ---
  // In _MapScreenState class

// In lib/screens/map_screen.dart
// REPLACE your _loadCustomIcons function with this

  Future<void> _loadCustomIcons() async {
    try {
      // Define asset paths
      const String turnLeftPath = 'assets/icons/turn-left.png';
      const String turnRightPath = 'assets/icons/turn-right.png';
      const String straightPath = 'assets/icons/straight.png';
      const String unknownPath = 'assets/icons/dot.png';
      // Note: I am removing the custom 'traffic-light.png' since we are using the default red/green markers
      // const String signalIconPath = 'assets/icons/traffic-light.png';

      // --- ADD THIS BLOCK ---
      // We are *not* loading the custom arrow, so this block is also removed.
      // const String arrowIconPath = 'assets/icons/navigation_arrow.png';
      // _userArrowIcon = await BitmapDescriptor.fromAssetImage( ... );
      // --- END OF BLOCK ---

      // 1. Load for Map Markers (BitmapDescriptor)
      _maneuverIcons['TURN_LEFT'] = await BitmapDescriptor.fromAssetImage(
          const ImageConfiguration(size: Size(64, 64)), turnLeftPath);
      _maneuverIcons['TURN_RIGHT'] = await BitmapDescriptor.fromAssetImage(
          const ImageConfiguration(size: Size(64, 64)), turnRightPath);
      _maneuverIcons['STRAIGHT'] = await BitmapDescriptor.fromAssetImage(
          const ImageConfiguration(size: Size(64, 64)), straightPath);
      _maneuverIcons['UNKNOWN'] = await BitmapDescriptor.fromAssetImage(
          const ImageConfiguration(size: Size(48, 48)), unknownPath);

      // --- This is all we need for the signal icons ---
      _signalIconRed = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      _signalIconGreen = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      _trafficSignalIcon = _signalIconRed; // Default to red
      // --- End ---

      // --- This is all we need for the user icon ---
      _userArrowIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
      // --- End ---

      // 2. Load for UI Card (String paths)
      _maneuverIconPaths['TURN_LEFT'] = turnLeftPath;
      _maneuverIconPaths['TURN_RIGHT'] = turnRightPath;
      _maneuverIconPaths['STRAIGHT'] = straightPath;
      _maneuverIconPaths['UNKNOWN'] = unknownPath;

      print("✅ Custom maneuver icons and paths loaded.");
    } catch (e) {
      print("⚠️ Error loading custom icons: $e. Make sure assets are in pubspec.yaml");
    }
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
// In lib/screens/map_screen.dart
// Add this function inside your _MapScreenState class

  Future<List<LatLng>> _getOverpassSignalsInBounds(LatLngBounds bounds) async {
    // This is the simple query for all signals in a box
    const String _overpassUrl = "https://overpass-api.de/api/interpreter";
    final south = bounds.southwest.latitude;
    final west = bounds.southwest.longitude;
    final north = bounds.northeast.latitude;
    final east = bounds.northeast.longitude;

    final String query = """
      [out:json][timeout:60];
      (
        node["highway"="traffic_signals"]($south,$west,$north,$east);
      );
      out body;
      >;
      out skel qt;
    """;

    print("Querying Overpass API (60s timeout)..."); // <-- I've added a new log

    try {
      final response = await http.post(
        Uri.parse(_overpassUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'data=$query',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List elements = data['elements'] ?? [];
        final List<LatLng> signals = [];

        for (var element in elements) {
          if (element['type'] == 'node') {
            signals.add(LatLng(element['lat'], element['lon']));
          }
        }

        print("✅ Found ${signals.length} total signals in bounds.");
        return signals;
      } else {
        print("⚠️ Overpass API error: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Error connecting to Overpass API: $e");
      return [];
    }
  }
// In lib/screens/map_screen.dart
// REPLACE THIS FUNCTION

  Future<void> _getRouteFromRoutesAPI() async {
    final url = Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes');
    final headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': _googleApiKey,
      'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.legs.steps.navigationInstruction,routes.legs.steps.startLocation.latLng,routes.travelAdvisory.speedReadingIntervals',
    };

    final body = jsonEncode({
      'origin': {'location': {'latLng': {'latitude': _sourceLocation!.latitude, 'longitude': _sourceLocation!.longitude}}},
      'destination': {'location': {'latLng': {'latitude': _destinationLocation!.latitude, 'longitude': _destinationLocation!.longitude}}},
      'travelMode': 'DRIVE',
      'routingPreference': 'TRAFFIC_AWARE',
      'computeAlternativeRoutes': false,
      'languageCode': 'en-US',
      'units': 'METRIC',
    });

    setState(() {
      _polylines.clear();
      _markers.clear();
      _trafficSignalMarkers.clear();
      _navigationSteps.clear();
      _routePolylinePoints.clear();
      _errorMessage = null;
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['routes'] != null && data['routes'].isNotEmpty) {
        final route = data['routes'][0];

        // ... (Parsing logic for distance, duration, steps, polyline) ...
        final distanceMeters = route['distanceMeters'];
        _distance = distanceMeters != null ? '${(distanceMeters / 1000).toStringAsFixed(1)} km' : null;
        final durationStr = route['duration'];
        if (durationStr != null) {
          _durationInSeconds = int.parse(durationStr.replaceAll('s', ''));
          _duration = '${(_durationInSeconds / 60).round()} min';
        }
        String encodedPolyline = route['polyline']['encodedPolyline'];
        _routePolylinePoints = _decodePolyline(encodedPolyline);
        if (route['legs'] != null && route['legs'].isNotEmpty) {
          final steps = route['legs'][0]['steps'] as List;
          List<Map<String, dynamic>> newSteps = [];
          for (var step in steps) {
            final instructionData = step['navigationInstruction'];
            final locationData = step['startLocation']['latLng'];
            if (instructionData != null && locationData != null) {
              newSteps.add({
                'maneuver': instructionData['maneuver'] ?? 'UNKNOWN',
                'instructions': instructionData['instructions'] ?? 'Continue',
                'latLng': LatLng(locationData['latitude'], locationData['longitude']),
              });
            }
          }
          _navigationSteps = newSteps;
          print("✅ Loaded ${_navigationSteps.length} navigation steps.");
        }
        final Set<Polyline> newPolylines = {};
        if (route['travelAdvisory'] != null && route['travelAdvisory']['speedReadingIntervals'] != null) {
          final intervals = route['travelAdvisory']['speedReadingIntervals'] as List;
          for (var interval in intervals) {
            final speed = interval['speed'];
            final color = _getColorForSpeed(speed);
            final int startIndex = interval['startPolylinePointIndex'] ?? 0;
            final int endIndex = interval['endPolylinePointIndex'] ?? _routePolylinePoints.length - 1;
            final List<LatLng> segmentPoints = _routePolylinePoints.sublist(startIndex, endIndex + 1);
            newPolylines.add(
                Polyline(
                  polylineId: PolylineId('route_segment_$startIndex'),
                  points: segmentPoints,
                  color: color,
                  width: 7,
                  startCap: Cap.roundCap,
                  endCap: Cap.roundCap,
                )
            );
          }
        } else {
          newPolylines.add(
              Polyline(
                polylineId: const PolylineId('route'),
                points: _routePolylinePoints,
                color: Colors.blue,
                width: 7,
              )
          );
        }
        setState(() {
          _polylines.addAll(newPolylines);
          _markers.add(Marker(markerId: const MarkerId('source'), position: _sourceLocation!, infoWindow: InfoWindow(title: 'Source')));
          _markers.add(Marker(markerId: const MarkerId('destination'), position: _destinationLocation!, infoWindow: InfoWindow(title: 'Destination')));
        });

        // --- Animate Camera & Fetch Signals ---
        if (_sourceLocation != null && _destinationLocation != null) {
          LatLng southwest = LatLng(
            _sourceLocation!.latitude < _destinationLocation!.latitude ? _sourceLocation!.latitude : _destinationLocation!.latitude,
            _sourceLocation!.longitude < _destinationLocation!.longitude ? _sourceLocation!.longitude : _destinationLocation!.longitude,
          );
          LatLng northeast = LatLng(
            _sourceLocation!.latitude > _destinationLocation!.latitude ? _sourceLocation!.latitude : _destinationLocation!.latitude,
            _sourceLocation!.longitude > _destinationLocation!.longitude ? _sourceLocation!.longitude : _destinationLocation!.longitude,
          );
          final LatLngBounds routeBounds = LatLngBounds(southwest: southwest, northeast: northeast);

          _mapController?.animateCamera(CameraUpdate.newLatLngBounds(routeBounds, 80.0));

          // --- !! THIS IS THE NEW LOGIC !! ---
          // --- !! THIS IS THE FIX !! ---
          // We pass BOTH the bounds (for the API) AND the full route points (for filtering)
          if (_routePolylinePoints.isNotEmpty) {
            _fetchAndPlotTrafficSignals(routeBounds, _routePolylinePoints);
          }
          // --- END OF NEW LOGIC ---
        }
      }
    } else {
      final errorBody = jsonDecode(response.body);
      setState(() {
        _errorMessage = errorBody['error']['message'] ?? 'Failed to get route from API';
      });
      print("Error from Routes API: ${response.body}");
      throw Exception('Failed to get route from API: ${response.body}');
    }
  }

  Future<void> _fetchAndPlotTrafficSignals(LatLngBounds bounds, List<LatLng> routePoints) async {

    // --- STEP 1: Get ALL signals in the box ---
    List<LatLng> allSignals = await _getOverpassSignalsInBounds(bounds);
    if (allSignals.isEmpty || routePoints.isEmpty) {
      print("No signals found in bounds or route is empty.");
      return;
    }

    // --- STEP 2: Filter signals to get only those on the route ---
    final List<LatLng> filteredSignals = [];
    const double tolerance = 20.0;
    for (var signal in allSignals) {
      bool isOnRoute = false;
      for (var point in routePoints) {
        final double distance = Geolocator.distanceBetween(
          signal.latitude, signal.longitude,
          point.latitude, point.longitude,
        );
        if (distance <= tolerance) {
          isOnRoute = true;
          break;
        }
      }
      if (isOnRoute) {
        filteredSignals.add(signal);
      }
    }
    print("✅ Filtered complete. Found ${filteredSignals.length} signals ON THE ROUTE.");

    // --- !! NEW !! STEP 3: Cluster the filtered signals ---
    // We group signals that are within 50m of each other into one junction
    List<LatLng> junctionCentroids = _clusterSignals(filteredSignals, 50.0);

    // --- STEP 4: Sort the new JUNCTIONS by distance ---
    List<Map<String, dynamic>> signalsWithDistance = [];
    for (var junction in junctionCentroids) {
      double distance = Geolocator.distanceBetween(
        _sourceLocation!.latitude, _sourceLocation!.longitude,
        junction.latitude, junction.longitude,
      );
      signalsWithDistance.add({'signal': junction, 'distance': distance});
    }
    signalsWithDistance.sort((a, b) => a['distance'].compareTo(b['distance']));

    // --- STEP 5: Create sorted list and plot the JUNCTIONS ---
    _sortedSignalMarkers.clear();
    _trafficSignalMarkers.clear();

    Set<Marker> newSignalMarkers = {};
    for (int i = 0; i < signalsWithDistance.length; i++) {
      final junction = signalsWithDistance[i]['signal'] as LatLng;
      final marker = Marker(
        markerId: MarkerId('signal_$i'), // Keep ID format: signal_0, signal_1...
        position: junction,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed), // Default to RED
        infoWindow: const InfoWindow(title: 'Traffic Junction'),
        anchor: const Offset(0.5, 0.5),
      );
      _sortedSignalMarkers.add(marker); // Add to sorted LIST
      newSignalMarkers.add(marker);      // Add to SET for plotting
    }

    setState(() {
      _trafficSignalMarkers.addAll(newSignalMarkers);
    });
  }



  // In lib/screens/map_screen.dart
// ADD THESE FOUR NEW FUNCTIONS

  // 1. THIS IS CALLED BY THE "Start Simulation" BUTTON
  void _startNavigationSimulation() {
    print("--- STARTING NAVIGATION SIMULATION ---");
    if (_routePolylinePoints.isEmpty) return;

    // Reset all simulation state
    _simulationIndex = 0;
    _lastPassedSignalIndex = -1;
    _simulationTimer?.cancel();

    setState(() {
      _markers.clear(); // Clear source/dest markers
      _isNavigating = true; // This will show the top/bottom nav cards
      _isPlanningRoute = false;
    });

    // Zoom to start
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(_sourceLocation!, 17.0),
    ).then((_) {
      // Start the timer that moves the arrow
      _simulationTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
        _onSimulationTick();
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Starting simulation...')),
    );
  }

  // 2. THIS IS THE "HEARTBEAT" OF THE SIMULATION
  void _onSimulationTick() {
    // Stop if we've reached the end of the route
    if (_simulationIndex >= _routePolylinePoints.length - 1) {
      _simulationTimer?.cancel();
      _stopNavigation(); // Use your existing stop function to clean up
      print("--- SIMULATION FINISHED ---");
      return;
    }

    // Get current and next position to calculate bearing
    LatLng currentPos = _routePolylinePoints[_simulationIndex];
    LatLng nextPos = _routePolylinePoints[_simulationIndex + 1];

    // Calculate bearing (rotation)
    double bearing = Geolocator.bearingBetween(
      currentPos.latitude, currentPos.longitude,
      nextPos.latitude, nextPos.longitude,
    );

    // Update the map (arrow position, camera, and signals)
    setState(() {
      // Animate camera to follow the fake arrow
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: currentPos,
            zoom: 17.0,
            bearing: bearing,
            tilt: 50.0,
          ),
        ),
      );

      // Move the arrow
      _markers.removeWhere((m) => m.markerId.value == 'user_location');
      _markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: currentPos,
          // --- THIS IS THE FIX ---
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure), // Use a built-in blue marker
          // --- END OF FIX ---
          rotation: bearing,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          zIndex: 2,
        ),
      );

      // --- RUN THE PREEMPTION LOGIC ---
      _updatePreemptionLogic(currentPos);
    });

    // Move to the next point on the polyline
    _simulationIndex++;
  }

  // 3. THIS IS THE CORE PREEMPTION LOGIC
// In lib/screens/map_screen.dart
// REPLACE this function
// In lib/screens/map_screen.dart
// ADD THIS NEW HELPER FUNCTION

  List<LatLng> _clusterSignals(List<LatLng> signals, double clusterRadius) {
    List<LatLng> junctionCentroids = [];
    Set<int> processedIndices = {};

    print("Clustering ${signals.length} signals...");

    for (int i = 0; i < signals.length; i++) {
      if (processedIndices.contains(i)) continue;

      List<LatLng> currentCluster = [signals[i]];
      processedIndices.add(i);

      double avgLat = signals[i].latitude;
      double avgLng = signals[i].longitude;

      // Find all other signals in this cluster
      for (int j = i + 1; j < signals.length; j++) {
        if (processedIndices.contains(j)) continue;

        double distance = Geolocator.distanceBetween(
          signals[i].latitude, signals[i].longitude,
          signals[j].latitude, signals[j].longitude,
        );

        if (distance < clusterRadius) {
          currentCluster.add(signals[j]);
          processedIndices.add(j);
          avgLat += signals[j].latitude;
          avgLng += signals[j].longitude;
        }
      }

      // Calculate the center of the cluster (the junction)
      avgLat /= currentCluster.length;
      avgLng /= currentCluster.length;
      junctionCentroids.add(LatLng(avgLat, avgLng));
    }

    print("Clustered into ${junctionCentroids.length} junctions.");
    return junctionCentroids;
  }


// REPLACE this entire function

  void _updatePreemptionLogic(LatLng currentPos) {
    if (_sortedSignalMarkers.isEmpty) return;

    // --- A. Always keep the next two signals green ---
    int s1_idx = _lastPassedSignalIndex + 1;
    _updateSignalIcon(s1_idx, BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen));

    int s2_idx = _lastPassedSignalIndex + 2;
    _updateSignalIcon(s2_idx, BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen));

    // --- B. Check if we have *passed* the current green signal (s1) ---
    if (s1_idx < _sortedSignalMarkers.length) {
      Marker currentGreenSignal = _sortedSignalMarkers[s1_idx];
      double distanceToCurrent = Geolocator.distanceBetween(
        currentPos.latitude, currentPos.longitude,
        currentGreenSignal.position.latitude, currentGreenSignal.position.longitude,
      );

      // If we are very close to the *current* green signal, it means we are passing it.
      if (distanceToCurrent < 50) {
        print("--- PASSING Signal $s1_idx ---");

        // Turn the *previous* signal (the one we've already passed) back to RED.
        if (_lastPassedSignalIndex >= 0) {
          _updateSignalIcon(_lastPassedSignalIndex, BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed));
        }

        // Increment our counter. Now, s1 becomes the "last passed" signal.
        _lastPassedSignalIndex = s1_idx;
      }
    }
  }

  // 4. THIS IS A HELPER TO UPDATE A MARKER'S ICON
  void _updateSignalIcon(int index, BitmapDescriptor icon) {
    if (index >= _sortedSignalMarkers.length) return; // Out of bounds

    String markerId = 'signal_$index';

    // Find the old marker in the main Set
    Marker? oldMarker = _trafficSignalMarkers
        .firstWhere((m) => m.markerId.value == markerId, orElse: () => _sortedSignalMarkers[index]);

    // Only update if the icon is different (avoids flicker)
    if (oldMarker.icon == icon) return;

    // Create the updated marker
    Marker newMarker = oldMarker.copyWith(
      iconParam: icon,
    );

    // Update both our lists
    _sortedSignalMarkers[index] = newMarker; // Update the sorted list
    _trafficSignalMarkers.removeWhere((m) => m.markerId.value == markerId); // Update the Set
    _trafficSignalMarkers.add(newMarker);
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

  Color _getColorForSpeed(String speed) {
    switch (speed) {
      case 'SLOW':
        return Colors.orange;
      case 'TRAFFIC_JAM':
        return Colors.red;
      case 'NORMAL':
      default:
        return Colors.blue;
    }
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


// In lib/screens/map_screen.dart
// REPLACE this function

// In lib/screens/map_screen.dart
// REPLACE THIS FUNCTION

  void _startNavigation() {
    print("Start Navigation (Stage 1: To Patient)");
    print("Destination: $_destinationLocation");

    if (_destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Destination not set.')),
      );
      return;
    }

    setState(() {
      _markers.clear(); // Clear source/dest markers
      _isNavigating = true;
      _navigationStage = 1;
      _isPlanningRoute = false;
    });

    _positionStreamSubscription?.cancel();

    // --- THIS IS THE ZOOM FIX ---
    // 1. We first animate the camera to the start location.
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(_sourceLocation!, 17.0),
    ).then((_) {
      // 2. ONLY AFTER the animation is done, we start listening to the GPS.
      // This stops the camera from snapping back.
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) {
        LatLng currentLatLng = LatLng(position.latitude, position.longitude);

        // a. Animate camera to follow driver (this now happens *after* the zoom)
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

        // b. Draw the rotating user arrow
        setState(() {
          _markers.removeWhere((m) => m.markerId.value == 'user_location');
          _markers.add(
            Marker(
              markerId: const MarkerId('user_location'),
              position: currentLatLng,
              icon: _userArrowIcon,
              rotation: position.heading,
              anchor: const Offset(0.5, 0.5),
              flat: true,
              zIndex: 2,
            ),
          );
        });

        // c. Logic to find and display current nav step
        if (_navigationSteps.isNotEmpty) {
          // ... (this logic is unchanged)
          Map<String, dynamic>? closestStep;
          double minDistance = double.infinity;
          for (var step in _navigationSteps) {
            final stepLatLng = step['latLng'] as LatLng;
            final distance = Geolocator.distanceBetween(
              currentLatLng.latitude, currentLatLng.longitude,
              stepLatLng.latitude, stepLatLng.longitude,
            );
            if (distance < minDistance) {
              minDistance = distance;
              closestStep = step;
            }
          }
          if (minDistance < 30 && closestStep != null) {
            int stepIndex = _navigationSteps.indexOf(closestStep);
            if (stepIndex < _navigationSteps.length - 1) {
              _navigationSteps.removeAt(stepIndex);
            }
          }
          if (_navigationSteps.isNotEmpty) {
            setState(() {
              _currentNavStep = _navigationSteps.first;
            });
          }
        }

        // d. Arrival detection logic
        if (_navigationStage == 1 && _destinationLocation != null) {
          // ... (this logic is unchanged)
          double distanceInMeters = Geolocator.distanceBetween(
            currentLatLng.latitude, currentLatLng.longitude,
            _destinationLocation!.latitude, _destinationLocation!.longitude,
          );
          if (distanceInMeters < 50) {
            print("✅ Arrived at patient location!");
            _positionStreamSubscription?.cancel();
            _positionStreamSubscription = null;
            setState(() {
              _isNavigating = false;
              _currentNavStep = null;
              _markers.removeWhere((m) => m.markerId.value == 'user_location');
            });
            _showHospitalChoiceDialog(currentLatLng);
          }
        }
      });
    });
    // --- END OF THE ZOOM FIX ---

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
    _simulationTimer?.cancel(); // <-- ADD THIS LINE
    setState(() {
      _isNavigating = false;
      _navigationStage = 0;

      _polylines.clear();
      _markers.clear();
      _trafficSignalMarkers.clear();
      _markers.removeWhere((m) => m.markerId.value == 'user_location'); // <-- ADD THIS
      _routePolylinePoints.clear();
      _navigationSteps.clear();
      _currentNavStep = null;
      _distance = null;
      _duration = null;
      _durationInSeconds = 0;
    });

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(_initialPosition),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigation stopped.')),
    );
  }
// --- MAIN BUILD METHOD (with the duplicate removed) ---

  @override

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // LAYER 1: The Google Map
          GoogleMap(
            initialCameraPosition: _initialPosition,
            markers: Set.from(_markers)..addAll(_trafficSignalMarkers),
            polylines: _polylines,
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: false,
            myLocationButtonEnabled: true,

            trafficEnabled: true, // Keep this true! It helps Google's ETA
            zoomControlsEnabled: false,
            // ** UPDATED Padding to make room for top and bottom cards **
            padding: EdgeInsets.only(
              bottom: _isNavigating ? 100 : 100, // Room for bottom card
              top: _isNavigating ? 140 : 100,  // Room for top card
            ),
          ),

          // LAYER 2: The UI elements
          if (_isDashboardLoading)
            const Center(child: CircularProgressIndicator())
          else if (_activeEmergency != null)
            SafeArea(child: _buildMissionView())
          else
            _buildStandbyUI(), // Search bar, FABs, availability

          // LAYER 3: Standby "Start Navigation" button


          // --- UPDATED: LAYER 3 - NAVIGATION BUTTONS ---
          if (_polylines.isNotEmpty && !_isNavigating && _activeEmergency == null)
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // --- REAL NAVIGATION BUTTON ---
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.navigation_rounded),
                          label: const Text("Start Nav"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30.0),
                            ),
                          ),
                          onPressed: _startNavigation, // Calls the REAL function
                        ),
                      ),

                      const SizedBox(width: 10),

                      // --- SIMULATION BUTTON ---
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.fast_forward_rounded),
                          label: const Text("Start Sim"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green, // Different color
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30.0),
                            ),
                          ),
                          onPressed: _startNavigationSimulation, // Calls the NEW function
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // LAYER 4: LIVE NAVIGATION CARD (TOP)
          if (_isNavigating && _currentNavStep != null)
            _buildNavigationInstructionCard(),

          // --- NEW: LAYER 5 - LIVE NAVIGATION CARD (BOTTOM) ---
          if (_isNavigating)
            _buildBottomNavigationCard(),
        ],
      ),
    );
  }
  // In _MapScreenState class, add this new widget function

  Widget _buildNavigationInstructionCard() {
    if (_currentNavStep == null) {
      return Container(); // Return empty if no step
    }

    final maneuverType = _currentNavStep!['maneuver'].toString().toUpperCase();
    final instructions = _currentNavStep!['instructions'].toString();

    final iconPath = _maneuverIconPaths[maneuverType] ??
        _maneuverIconPaths['STRAIGHT'] ??
        _maneuverIconPaths['UNKNOWN'];

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Card(
          elevation: 8,
          margin: const EdgeInsets.all(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (iconPath != null)
                  Image.asset(
                    iconPath,
                    width: 50,
                    height: 50,
                    errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.navigation, size: 50),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    instructions,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildBottomNavigationCard() {
    if (_duration == null || _distance == null) {
      return Container();
    }

    // Calculate ETA
    final now = DateTime.now();
    final etaTime = now.add(Duration(seconds: _durationInSeconds));
    final etaString = DateFormat.jm().format(etaTime); // e.g., "4:37 PM"

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Card(
        margin: const EdgeInsets.all(12),
        elevation: 8,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Stop Button
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red, size: 30),
                onPressed: _stopNavigation,
              ),

              // ETA Info
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _duration!,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    "$_distance · $etaString",
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),

              // Re-center Button
              IconButton(
                icon: const Icon(Icons.my_location, color: Colors.blue, size: 30),
                onPressed: _goToCurrentLocation,
              ),
            ],
          ),
        ),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _sourceController,
          decoration: InputDecoration(
              hintText: 'Choose starting point, or click map',
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.my_location, color: Colors.yellow),
              suffixIcon: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _isPlanningRoute = false),
              )
          ),
        ),
        const Divider(height: 1, thickness: 1),
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
                onSubmitted: (_) => _getManualRoute(),
              ),
            ),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              child: _isPlanningRoute ? _buildRoutePlanningBar() : _buildSearchBar(),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0, bottom: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
          _buildAvailabilityCard(),
        ],
      ),
    );
  }
  Widget _buildAvailabilityCard() {
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 4,
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