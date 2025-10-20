import 'package:flutter/material.dart';
import '../services/api_service.dart';

class HospitalAdminDashboard extends StatefulWidget {
  const HospitalAdminDashboard({Key? key}) : super(key: key);

  @override
  _HospitalAdminDashboardState createState() => _HospitalAdminDashboardState();
}

class _HospitalAdminDashboardState extends State<HospitalAdminDashboard> {
  late Future<List<dynamic>> _pendingDrivers;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _pendingDrivers = ApiService.getPendingDriversForHospital();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hospital Admin Dashboard')),
      body: FutureBuilder<List<dynamic>>(
        future: _pendingDrivers,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No pending driver approvals.'));
          }
          final drivers = snapshot.data!;
          return ListView.builder(
            itemCount: drivers.length,
            itemBuilder: (context, index) {
              final driver = drivers[index];
              return ListTile(
                title: Text(driver['name']),
                subtitle: Text(driver['email']),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () async {
                      await ApiService.approveDriverByHospital(driver['_id']);
                      _loadData(); // Refresh list
                    }),
                    IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () async {
                      await ApiService.rejectDriverByHospital(driver['_id'], "Rejected by hospital.");
                      _loadData(); // Refresh list
                    }),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}