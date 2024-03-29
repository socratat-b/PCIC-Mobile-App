import 'package:flutter/foundation.dart'; // for printing debug messages
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class JobPage extends StatefulWidget {
  const JobPage({super.key});

  @override
  _JobPageState createState() => _JobPageState();
}

class _JobPageState extends State<JobPage> {
  MapController mapController = MapController();
  List<LatLng> routePoints = [];
  List<Marker> markers = [];
  String currentLocation = '';
  bool isColumnVisible = true;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      await _getCurrentLocation();
    } else {
      // Handle permission denied case
      if (kDebugMode) {
        print('Location permission denied');
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        mapController.move(
          LatLng(position.latitude, position.longitude),
          15.0,
        );
        routePoints.add(LatLng(position.latitude, position.longitude));
        markers.add(
          Marker(
            point: LatLng(position.latitude, position.longitude),
            child: const Icon(Icons.location_on, color: Colors.blue),
          ),
        );
        currentLocation =
            'Lat: ${position.latitude}, Long: ${position.longitude}';
      });
    } catch (e) {
      print('Error getting current location: $e');
    }
  }

  void _startRouting() {
    setState(() {
      routePoints = [];
      markers = [];
    });
  }

  void _stopRouting() {
    if (routePoints.length >= 2) {
      // Perform actions with the captured route points
      if (kDebugMode) {
        print('Captured route points: $routePoints');
      }
      // Add your logic here to process the captured route points
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              onTap: (position, point) {
                setState(() {
                  routePoints.add(point);
                  markers.add(
                    Marker(
                      point: point,
                      child: const Icon(Icons.location_on, color: Colors.red),
                    ),
                  );
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routePoints,
                    color: Colors.blue,
                    strokeWidth: 5.0,
                  ),
                ],
              ),
              MarkerLayer(
                markers: markers,
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x192F2F2F),
                    blurRadius: 20,
                    offset: Offset(-10, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Geotagging',
                        style: TextStyle(
                          color: Color(0xFF1E1E1E),
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            isColumnVisible = !isColumnVisible;
                          });
                        },
                        child: Icon(
                          isColumnVisible
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_up,
                        ),
                      ),
                    ],
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: isColumnVisible ? null : 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        const Text(
                          'Your Location',
                          style: TextStyle(
                            color: Color(0xFF9D9D9D),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currentLocation,
                          style: const TextStyle(
                            color: Color(0xFF343434),
                            fontSize: 12,
                          ),
                        ),
                        const Divider(height: 24),
                        const Text(
                          'Tracking Options',
                          style: TextStyle(
                            color: Color(0xFF9D9D9D),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildTrackingOption('Start'),
                            const SizedBox(width: 8),
                            _buildTrackingOption('Stop'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildTrackingOption('Pin Drop'),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  // Save button action
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF89C53F),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: const Text(
                                  'Save',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  // Reset button action
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF89C53F),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: const Text(
                                  'Reset',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              width: 20,
              height: 31,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage("https://via.placeholder.com/20x31"),
                  fit: BoxFit.fill,
                ),
              ),
              child: const Center(
                child: CircleAvatar(
                  radius: 5,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingOption(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Color(0xFF45C53F),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF1E1E1E),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    String label = '',
    bool isActive = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: isActive
          ? BoxDecoration(
              color: const Color(0x1989C53F),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Row(
        children: [
          Icon(
            icon,
            color: isActive ? const Color(0xFF89C53F) : Colors.black,
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFF89C53F) : Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
