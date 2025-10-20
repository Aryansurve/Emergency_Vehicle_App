import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';

class EmergencyTrackingScreen extends StatefulWidget {
  final String trackingId;
  const EmergencyTrackingScreen({Key? key, required this.trackingId}) : super(key: key);

  @override
  State<EmergencyTrackingScreen> createState() => _EmergencyTrackingScreenState();
}

class _EmergencyTrackingScreenState extends State<EmergencyTrackingScreen> {
  IO.Socket? _socket;
  final Set<Marker> _markers = {};
  String _statusMessage = "Waiting for a driver to be assigned...";

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(19.2183, 72.9781), // Default view
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    _initSocket();
  }

  @override
  void dispose() {
    _socket?.disconnect();
    super.dispose();
  }

  void _initSocket() {
    _socket = IO.io('http://192.168.0.127:5000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });
    _socket!.connect();

    _socket!.onConnect((_) {
      print('👀 Public user connected and joining room: ${widget.trackingId}');
      _socket!.emit('joinTrackingRoom', widget.trackingId);
    });

    // **LIVE LOCATION LISTENER**
    _socket!.on('missionUpdate', (data) {
      if (mounted && data is Map) {
        final lat = data['latitude'];
        final lng = data['longitude'];
        if (lat != null && lng != null) {
          setState(() {
            _statusMessage = "Ambulance is on the way!";
            _markers.removeWhere((m) => m.markerId.value == 'ambulance');
            _markers.add(Marker(
              markerId: const MarkerId('ambulance'),
              position: LatLng(lat, lng),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: const InfoWindow(title: 'Ambulance'),
            ));
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracking Emergency'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            color: Colors.blue.shade100,
            child: Text(
              _statusMessage,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: _initialPosition,
              markers: _markers,
            ),
          ),
        ],
      ),
    );
  }
}