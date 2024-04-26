// geotag.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:external_path/external_path.dart';
import 'package:flutter/material.dart';
import 'package:gpx/gpx.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../utils/app/_gpx.dart';
import '../pcic_form/_pcic_form.dart';
import '../tasks/_control_task.dart';
import '_location_service.dart';
import '_map_service.dart';

class GeotagPage extends StatefulWidget {
  final TaskManager task;
  const GeotagPage({super.key, required this.task});

  @override
  GeotagPageState createState() => GeotagPageState();
}

class GeotagPageState extends State<GeotagPage> with WidgetsBindingObserver {
  final LocationService _locationService = LocationService();
  final MapService _mapService = MapService();

  bool retainPinDrop = false;
  bool showConfirmationDialog = true;
  String currentLocation = '';
  bool isColumnVisible = true;
  bool isRoutingStarted = false;
  bool isLoading = false;

  StreamSubscription<LatLng>? _locationSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationSubscription?.cancel();
    _mapService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _locationSubscription?.cancel();
      _mapService.dispose();
    }
  }

  Future<void> _initializeLocation() async {
    await _locationService.requestLocationPermission();
    _getCurrentLocation(addMarker: false);
  }

  Future<void> _getCurrentLocation({bool addMarker = true}) async {
    LatLng? position = await _locationService.getCurrentLocation();
    if (position != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            currentLocation =
                'Lat: ${position.latitude}, Long: ${position.longitude}';
            _mapService.moveMap(position);
          });
          if (addMarker) {
            _mapService.addMarker(position);
          }
        }
      });
    }
  }

  void _startRouting() async {
    LatLng? position = await _locationService.getCurrentLocation();
    if (position != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            isRoutingStarted = true;
            _mapService.clearRoutePoints();
            _mapService.addColoredMarker(position, Colors.green);
          });
          _trackRoutePoints();
        }
      });
    }
  }

  void _trackRoutePoints() {
    _locationSubscription =
        _locationService.getLocationStream().listen((position) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            currentLocation =
                'Lat: ${position.latitude}, Long: ${position.longitude}';
            _mapService
                .addRoutePoint(LatLng(position.latitude, position.longitude));
          });
        }
      });
    });
  }

  void _stopRouting() async {
    bool? shouldStop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Finish routing?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (shouldStop == true) {
      setState(() {
        isLoading = true;
      });

      _locationSubscription?.cancel();

      try {
        List<Wpt> routePoints = _mapService.routePoints
            .map((point) => Wpt(lat: point.latitude, lon: point.longitude))
            .toList();

        // Add starting point coordinates to close the route
        routePoints.add(Wpt(
          lat: routePoints.first.lat,
          lon: routePoints.first.lon,
        ));

        var gpx = GpxUtil.createGpx(routePoints);
        var gpxString = GpxWriter().asString(gpx);

        String gpxFilePath = await _saveGpxFile(gpxString);
        String screenshotFilePath = '';

        final screenshotBytes = await _mapService.captureMapScreenshot();
        if (screenshotBytes != null) {
          screenshotFilePath = await _saveMapScreenshot(screenshotBytes);
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              isRoutingStarted = false;
              _mapService.clearMarkers();
              isLoading = false;
            });

            // Show a snackbar with the file locations
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Files saved:\nGPX: $gpxFilePath\nScreenshot: $screenshotFilePath'),
                duration: const Duration(seconds: 2),
              ),
            );

            // Navigate to the forms page
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => PCICFormPage(
                  imageFile: screenshotFilePath,
                  gpxFile: gpxFilePath,
                  task: widget.task,
                  routePoints: _mapService.routePoints,
                  lastCoordinates: _mapService.routePoints.last,
                ),
              ),
            );
          }
        });
      } catch (e) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              isLoading = false;
            });
            // Handle the exception gracefully
            debugPrint('Exception caught: $e');
            // Show an error message to the user
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('An error occurred while saving the files.'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        });
      }
    }
  }

  Future<String> _saveGpxFile(String gpxString) async {
    final filePath = await ExternalPath.getExternalStoragePublicDirectory(
      ExternalPath.DIRECTORY_DOWNLOADS,
    );
    final downloadsDirectory = Directory(filePath);
    final insuranceId = widget.task.ppirInsuranceId;
    final insuranceDirectory =
        Directory('${downloadsDirectory.path}/$insuranceId');

    // Create the insurance directory if it doesn't exist
    if (!await insuranceDirectory.exists()) {
      await insuranceDirectory.create(recursive: true);
    }

    // Get the current date and time
    final dateTime = DateTime.now();
    final formattedDateTime = DateFormat('yyyyMMdd_HHmmss').format(dateTime);

    final file = File(
        '${insuranceDirectory.path}/${insuranceId}_$formattedDateTime.gpx');
    await file.writeAsString(gpxString);
    debugPrint('GPX file saved: ${file.path}');
    return file.path;
  }

  Future<String> _saveMapScreenshot(Uint8List screenshotBytes) async {
    final filePath = await ExternalPath.getExternalStoragePublicDirectory(
      ExternalPath.DIRECTORY_DOWNLOADS,
    );
    final downloadsDirectory = Directory(filePath);
    final insuranceId = widget.task.ppirInsuranceId;
    final insuranceDirectory =
        Directory('${downloadsDirectory.path}/$insuranceId');

    // Create the insurance directory if it doesn't exist
    if (!await insuranceDirectory.exists()) {
      await insuranceDirectory.create(recursive: true);
    }

    // Get the current date and time
    final dateTime = DateTime.now();
    final formattedDateTime = DateFormat('yyyyMMdd_HHmmss').format(dateTime);

    final file = File(
        '${insuranceDirectory.path}/${insuranceId}_$formattedDateTime.png');
    await file.writeAsBytes(screenshotBytes);
    debugPrint('Map screenshot saved: ${file.path}');
    return file.path;
  }

  Future<void> _addMarkerAtCurrentLocation() async {
    LatLng? position = await _locationService.getCurrentLocation();
    _mapService.addMarker(position!);

    if (showConfirmationDialog) {
      bool? shouldRetain = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Pin Drop'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return CheckboxListTile(
                title: const Text('Don\'t show again'),
                value: retainPinDrop,
                onChanged: (value) {
                  setState(() {
                    retainPinDrop = value!;
                  });
                },
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (shouldRetain == false) {
        _mapService.removeLastMarker();
      } else {
        showConfirmationDialog = !retainPinDrop;
      }
    } else {
      if (!retainPinDrop) {
        _mapService.removeLastMarker();
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (isLoading) {
      return false;
    }

    final shouldPop = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Are you sure you want to cancel?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Stack(
        children: [
          Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: _mapService.buildMap(),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Location',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(currentLocation),
                      const SizedBox(height: 20),
                      Visibility(
                        visible: isColumnVisible,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Route Points',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton(
                                  onPressed:
                                      isRoutingStarted ? null : _startRouting,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isRoutingStarted
                                        ? Colors.grey
                                        : Colors.blue,
                                  ),
                                  child: const Text('Start Routing'),
                                ),
                                ElevatedButton(
                                  onPressed:
                                      isRoutingStarted ? _stopRouting : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isRoutingStarted
                                        ? Colors.blue
                                        : Colors.grey,
                                  ),
                                  child: const Text('Stop Routing'),
                                ),
                                Visibility(
                                  visible: isRoutingStarted,
                                  child: ElevatedButton(
                                    onPressed: _addMarkerAtCurrentLocation,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.pin_drop),
                                        SizedBox(width: 4),
                                        Text('Pin Drop'),
                                      ],
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
              ],
            ),
            floatingActionButton: Stack(
              children: [
                Positioned(
                    top: 150.0,
                    right: 0,
                    bottom: 0,
                    child: SizedBox(
                      height: 45,
                      width: 45,
                      child: FloatingActionButton(
                        onPressed: () => _getCurrentLocation(addMarker: false),
                        shape: const CircleBorder(
                          side: BorderSide(color: Colors.green, width: 2.0),
                        ),
                        backgroundColor: const Color(0xFFD2FFCB),
                        elevation: 4.0,
                        child: const Icon(
                          Icons.my_location,
                          color: Colors.black,
                          size: 24.0,
                        ),
                      ),
                    )),
                Positioned(
                    top: 80.0,
                    left: 40.0,
                    child: SizedBox(
                      height: 45,
                      width: 45,
                      child: FloatingActionButton(
                        onPressed: () => _getCurrentLocation(addMarker: false),
                        shape: const CircleBorder(
                          side: BorderSide(color: Color(0xFFD2FFCB)),
                        ),
                        backgroundColor: const Color(0xFFD2FFCB),
                        elevation: 4.0,
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.black,
                          size: 24.0,
                        ),
                      ),
                    )),
              ],
            ),
          ),
          if (isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


/**
 * 
 * 
 * 
 * 
 * 
 */