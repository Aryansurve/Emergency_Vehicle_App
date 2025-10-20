import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../services/api_service.dart';
import 'login_screen.dart';

// The main widget is now a Tab controller
class PlatformAdminDashboard extends StatefulWidget {
  const PlatformAdminDashboard({Key? key}) : super(key: key);

  @override
  State<PlatformAdminDashboard> createState() => _PlatformAdminDashboardState();
}

class _PlatformAdminDashboardState extends State<PlatformAdminDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Center'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.local_shipping), text: 'Dispatch'),
            Tab(icon: Icon(Icons.verified_user), text: 'Verifications'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          DispatchView(), // Your existing dispatch UI
          VerificationView(), // The new UI for approving drivers
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// WIDGET 1: THE DISPATCH CENTER (Your previous screen's logic)
// -----------------------------------------------------------------------------
class DispatchView extends StatefulWidget {
  const DispatchView({Key? key}) : super(key: key);
  @override
  State<DispatchView> createState() => _DispatchViewState();
}

class _DispatchViewState extends State<DispatchView> {
  late Future<List<dynamic>> _unassignedEmergencies;
  IO.Socket? _socket;
  GoogleMapController? _mapController;
  final Set<Marker> _driverMarkers = {};

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(19.2183, 72.9781),
    zoom: 11,
  );

  @override
  void initState() {
    super.initState();
    _loadEmergencies();
    _initSocket();
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _mapController?.dispose();
    super.dispose();
  }

  void _loadEmergencies() {
    if (mounted) {
      setState(() {
        _unassignedEmergencies = ApiService.getUnassignedEmergencies();
      });    }
  }

  void _initSocket() {
    _socket = IO.io('http://192.168.0.127:5000', IO.OptionBuilder().setTransports(['websocket']).build());
    _socket!.connect();
    _socket!.on('driverLocation', (data) {
      if (mounted && data is Map) {
        final driverId = data['driverId'];
        final lat = data['latitude'];
        final lng = data['longitude'];
        if (driverId != null && lat != null && lng != null) {
          final markerId = MarkerId(driverId);
          final newMarker = Marker(
            markerId: markerId,
            position: LatLng(lat, lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: InfoWindow(title: 'Driver $driverId'),
          );
          setState(() {
            _driverMarkers.removeWhere((m) => m.markerId == markerId);
            _driverMarkers.add(newMarker);
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          child: FutureBuilder<List<dynamic>>(
            future: _unassignedEmergencies,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                    child: Text('No unassigned emergencies.', style: TextStyle(color: Colors.grey[600]))
                );
              }
              final emergencies = snapshot.data!;
              return ListView.builder(
                itemCount: emergencies.length,
                itemBuilder: (context, index) {
                  final emergency = emergencies[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      leading: const Icon(Icons.warning, color: Colors.red),
                      title: Text(emergency['details'] ?? 'No Details'),
                      subtitle: Text('Location: ${emergency['location']}'),
                      trailing: ElevatedButton(
                        child: const Text('Assign'),
                        onPressed: () => _showAssignDialog(context, emergency),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Expanded(
          child: GoogleMap(
            initialCameraPosition: _initialPosition,
            onMapCreated: (controller) => _mapController = controller,
            markers: _driverMarkers,
          ),
        ),
      ],
    );
  }

  void _showAssignDialog(BuildContext context, Map<String, dynamic> emergency) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AssignDriverDialog(
          emergency: emergency,
          onAssigned: () {
            Navigator.of(context).pop();
            _loadEmergencies();
          },
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// WIDGET 2: THE NEW VERIFICATION LIST
// -----------------------------------------------------------------------------
class VerificationView extends StatefulWidget {
  const VerificationView({Key? key}) : super(key: key);
  @override
  State<VerificationView> createState() => _VerificationViewState();
}

class _VerificationViewState extends State<VerificationView> {
  late Future<List<dynamic>> _pendingDrivers;

  @override
  void initState() {
    super.initState();
    _loadPendingDrivers();
  }

  void _loadPendingDrivers() {
    if (mounted) {
      setState(() {
        _pendingDrivers = ApiService.getPendingDriversForPlatform();
      });    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _pendingDrivers,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text('No drivers are awaiting final verification.', style: TextStyle(color: Colors.grey[600])),
          );
        }
        final drivers = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async => _loadPendingDrivers(),
          child: ListView.builder(
            itemCount: drivers.length,
            itemBuilder: (context, index) {
              final driver = drivers[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: const Icon(Icons.person_pin_circle_outlined),
                  title: Text(driver['name'] ?? 'N/A'),
                  subtitle: Text(driver['email'] ?? 'N/A'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        tooltip: 'Reject',
                        onPressed: () async {
                          await ApiService.rejectUserByPlatform(driver['_id'], 'Rejected by Platform Admin');
                          _loadPendingDrivers();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        tooltip: 'Verify',
                        onPressed: () async {
                          await ApiService.verifyUserByPlatform(driver['_id']);
                          _loadPendingDrivers();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// DIALOG WIDGET (Unchanged)
// -----------------------------------------------------------------------------
class AssignDriverDialog extends StatefulWidget {
  final Map<String, dynamic> emergency;
  final VoidCallback onAssigned;

  const AssignDriverDialog({
    Key? key,
    required this.emergency,
    required this.onAssigned,
  }) : super(key: key);

  @override
  State<AssignDriverDialog> createState() => _AssignDriverDialogState();
}

class _AssignDriverDialogState extends State<AssignDriverDialog> {
  late Future<List<dynamic>> _availableDrivers;
  String? _selectedDriverId;
  bool _isAssigning = false;

  @override
  void initState() {
    super.initState();
    _availableDrivers = ApiService.getAvailableDrivers();
  }

  Future<void> _assign() async {
    if (_selectedDriverId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a driver.')));
      return;
    }
    setState(() => _isAssigning = true);
    final result = await ApiService.assignEmergency(widget.emergency['_id'], _selectedDriverId!);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'An error occurred.')));
    if (result['success'] == true) {
      widget.onAssigned();
    } else {
      if (mounted) setState(() => _isAssigning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign Emergency'),
      content: FutureBuilder<List<dynamic>>(
        future: _availableDrivers,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Text('No drivers are currently available.');
          }
          final drivers = snapshot.data!;
          return DropdownButtonFormField<String>(
            value: _selectedDriverId,
            hint: const Text('Select an available driver'),
            items: drivers.map<DropdownMenuItem<String>>((driver) {
              return DropdownMenuItem(
                value: driver['_id'],
                child: Text('${driver['name']} - ${driver['vehicleId']}'),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedDriverId = value),
          );
        },
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isAssigning ? null : _assign,
          child: _isAssigning ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Assign'),
        ),
      ],
    );
  }
}