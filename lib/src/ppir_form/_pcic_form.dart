import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pcic_mobile_app/src/tasks/controllers/storage_service.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../utils/app/_show_flash_message.dart';
import '../../utils/seeds/_dropdown.dart';
import '../geotag/_geotag.dart';
import '../geotag/controls/_map_service.dart';
import 'form_components/_signature_section.dart';
import '../tasks/controllers/task_manager.dart';
import 'form_components/_form_field.dart' as form_field;
import 'form_components/_form_section.dart';
import 'form_components/_gpx_file_buttons.dart';
import 'form_components/_success.dart';

class PPIRFormPage extends StatefulWidget {
  final TaskManager task;

  const PPIRFormPage({
    super.key,
    required this.task,
  });

  @override
  PPIRFormPageState createState() => PPIRFormPageState();
}

class PPIRFormPageState extends State<PPIRFormPage> {
  List<Seeds> seedsList = Seeds.getAllSeeds();
  Map<String, int> seedTitleToIdMap = {};
  List<DropdownMenuItem<int>> uniqueSeedsItems = [];
  final _taskData = <String, dynamic>{};
  final _areaPlantedController = TextEditingController();
  final _areaInHectaresController = TextEditingController();
  final _totalDistanceController = TextEditingController();
  final _signatureSectionKey = GlobalKey<SignatureSectionState>();
  final _formSectionKey = GlobalKey<FormSectionState>();

  bool isSaving = false;
  bool isLoading = true;
  bool openOnline = true;
  bool geotagSuccess = true;
  bool isSubmitting = false;
  String? gpxFile;
  List<LatLng>? routePoints;
  LatLng? lastCoordinates;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      final formData = await widget.task.getTaskData();
      if (formData.isNotEmpty) {
        _initializeFormData(formData);
      }

      final mapService = MapService();
      gpxFile = await widget.task.getGpxFilePath();
      if (gpxFile != null) {
        final gpxData = await mapService.readGpxFile(gpxFile!);
        routePoints = await mapService.parseGpxData(gpxData);
        await _calculateAreaAndDistance();
      }

      _initializeSeeds();

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _initializeFormData(Map<String, dynamic> formData) {
    _areaPlantedController.text = formData['trackDatetime'] is Timestamp
        ? (formData['trackDatetime'] as Timestamp).toDate().toString()
        : formData['trackDatetime'] ??
            DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    _areaInHectaresController.text = formData['trackTotalarea'] ?? '';
    _totalDistanceController.text = formData['trackTotaldistance'] ?? '';

    _taskData['trackLastcoord'] =
        formData['trackLastcoord'] ?? 'No coordinates available';
    _taskData['ppirDopdsAct'] = formData['ppirDopdsAct'] ?? '';
    _taskData['ppirDoptpAct'] = formData['ppirDoptpAct'] ?? '';
    _taskData['ppirSvpAct'] = formData['ppirSvpAct'] ?? '';
    _taskData['ppirAreaAct'] = formData['ppirAreaAct'] ?? '';
    _taskData['ppirRemarks'] = formData['ppirRemarks'] ?? '';
    _taskData['ppirNameInsured'] = formData['ppirNameInsured'] ?? '';
    _taskData['ppirNameIuia'] = formData['ppirNameIuia'] ?? '';
  }

  void _initializeSeeds() {
    uniqueSeedsItems.add(const DropdownMenuItem<int>(
      value: null,
      child: Text(
        'Select a Seed Variety',
        style: TextStyle(color: Colors.grey),
      ),
    ));
    for (var seed in seedsList) {
      uniqueSeedsItems.add(DropdownMenuItem<int>(
        value: seed.id,
        child: Text(seed.title),
      ));
      seedTitleToIdMap[seed.title] = seed.id;
    }
  }

  Future<void> _calculateAreaAndDistance() async {
    if (routePoints != null && routePoints!.isNotEmpty) {
      final mapService = MapService();
      final distance = mapService.calculateTotalDistance(routePoints!);

      double area = 0.0;
      double areaInHectares = 0.0;
      final initialPoint = routePoints!.first;
      final closingPoint = routePoints!.last;

      if (_isCloseEnough(initialPoint, closingPoint)) {
        area = mapService.calculateAreaOfPolygon(routePoints!);
        areaInHectares = area / 10000;
      } else {
        geotagSuccess = false;
      }

      setState(() {
        _areaInHectaresController.text =
            areaInHectares > 0 ? _formatNumber(areaInHectares, 'ha') : '';
        _totalDistanceController.text = _formatNumber(distance, 'm');
      });
    }
  }

  bool _isCloseEnough(LatLng point1, LatLng point2) {
    const double threshold = 10.0;
    final distance = const Distance().as(LengthUnit.Meter, point1, point2);
    return distance <= threshold;
  }

  String _formatNumber(double value, String unit) {
    final formatter = NumberFormat('#,##0.############', 'en_US');
    return '${formatter.format(value)} $unit';
  }

  Future<void> _submitForm(BuildContext context) async {
    setState(() {
      isSubmitting = true;
    });

    if (!_formSectionKey.currentState!.validate() ||
        !_signatureSectionKey.currentState!.validate()) {
      showFlashMessage(context, 'Info', 'Validation Failed',
          'Please fill in all required fields.');
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final signatureData =
          await _signatureSectionKey.currentState?.getSignatureData() ?? {};

      _taskData['ppirNameInsured'] = signatureData['ppirNameInsured'];
      _taskData['ppirNameIuia'] = signatureData['ppirNameIuia'];

      if (!_formSectionKey.currentState!.validate() ||
          !_signatureSectionKey.currentState!.validate() ||
          signatureData['ppirNameInsured']?.trim().isEmpty == true ||
          signatureData['ppirNameIuia']?.trim().isEmpty == true) {
        showFlashMessage(context, 'Info', 'Validation Failed',
            'Please fill in all required fields.');
        setState(() {
          isSaving = false;
        });
        return;
      }

      final enabledFieldKeys = _taskData.keys.where((key) {
        return key != 'trackLastcoord' &&
            key != 'trackTotalarea' &&
            key != 'trackDatetime' &&
            key != 'trackTotaldistance' &&
            key != 'ppirRemarks';
      }).toList();

      bool hasEmptyEnabledFields = enabledFieldKeys.any((key) =>
          _taskData[key] == null || _taskData[key].toString().trim().isEmpty);

      bool hasEmptySignatureFields = signatureData['ppirSigInsured'] == null ||
          signatureData['ppirNameInsured']?.trim().isEmpty == true ||
          signatureData['ppirSigIuia'] == null ||
          signatureData['ppirNameIuia']?.trim().isEmpty == true;

      if (hasEmptyEnabledFields || hasEmptySignatureFields) {
        showFlashMessage(context, 'Info', 'Form Fields',
            'Please fill in all required fields');
        setState(() {
          isSaving = false;
        });
        return;
      }

      _taskData['trackTotalarea'] = _areaInHectaresController.text;
      _taskData['trackDatetime'] = _areaPlantedController.text;
      _taskData['trackLastcoord'] = _taskData['trackLastcoord'];
      _taskData['trackTotaldistance'] = _totalDistanceController.text;

      _taskData['ppirRemarks'] = _taskData['ppirRemarks'] ?? 'no value';
      _taskData['ppirSigInsured'] =
          signatureData['ppirSigInsured'] ?? 'no value';
      _taskData['ppirNameInsured'] =
          signatureData['ppirNameInsured'] ?? 'no value';
      _taskData['ppirSigIuia'] = signatureData['ppirSigIuia'] ?? 'no value';
      _taskData['ppirNameIuia'] = signatureData['ppirNameIuia'] ?? 'no value';
      _taskData['status'] = 'Completed';

      await widget.task.updatePpirFormData(_taskData);

      await StorageService.saveTaskFileToFirebaseStorage(
          widget.task.taskId, _taskData);

      await StorageService.compressAndUploadTaskFiles(
          widget.task.taskId, widget.task.taskId);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const FormSuccessPage(isSaveSuccessful: true),
          ),
        );
      }
    } catch (e) {
      showFlashMessage(
          context, 'Error', 'Save Failed', 'Failed to save form data.');
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<void> _saveForm() async {
    setState(() {
      isSaving = true;
    });

    try {
      final signatureData =
          await _signatureSectionKey.currentState?.getSignatureData() ?? {};

      _taskData['trackTotalarea'] = _areaInHectaresController.text;
      _taskData['trackDatetime'] = _areaPlantedController.text;
      _taskData['trackLastcoord'] = _taskData['trackLastcoord'];
      _taskData['trackTotaldistance'] = _totalDistanceController.text;

      _taskData['ppirRemarks'] = _taskData['ppirRemarks'] ?? 'no value';
      _taskData['ppirSigInsured'] =
          signatureData['ppirSigInsured'] ?? 'no value';
      _taskData['ppirNameInsured'] =
          signatureData['ppirNameInsured'] ?? 'no value';
      _taskData['ppirSigIuia'] = signatureData['ppirSigIuia'] ?? 'no value';
      _taskData['ppirNameIuia'] = signatureData['ppirNameIuia'] ?? 'no value';
      _taskData['status'] = 'Ongoing';

      if (mounted) {
        showFlashMessage(
            context, 'Info', 'Form Saved', 'Form data saved successfully.');
        // Navigate to dashboard
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    } catch (e) {
      showFlashMessage(
          context, 'Error', 'Save Failed', 'Failed to save form data.');
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  void _cancelForm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
            'You have unsaved changes. If you go back, your data will not be saved.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () {
              _saveForm();
            },
            child: const Text('Save', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (!isSaving) {
      bool? shouldLeave = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unsaved Changes'),
          content: const Text(
              'You have unsaved changes. If you go back, your data will not be saved.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, true); // Close dialog and pop screen
              },
              child: const Text('Leave', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () {
                _saveForm();
                Navigator.pop(
                    context, false); // Close dialog and stay on screen
              },
              child: const Text('Save', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      );
      return shouldLeave ?? false;
    }
    return true;
  }

  void _navigateToGeotagPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GeotagPage(task: widget.task),
      ),
    );
  }

  void _openGpxFile(String gpxFilePath) async {
    if (openOnline) {
      try {
        final response = await http.get(Uri.parse(gpxFilePath));
        if (response.statusCode == 200) {
          final directory = await getTemporaryDirectory();
          final file = File('${directory.path}/temp.gpx');
          await file.writeAsBytes(response.bodyBytes);
          _openLocalFile(file.path);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error downloading GPX file')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error downloading GPX file')),
          );
        }
      }
    } else {
      _openLocalFile(gpxFilePath);
    }
  }

  void _openLocalFile(String filePath) async {
    try {
      final gpxFile = File(filePath);
      if (await gpxFile.exists()) {
        final status = await Permission.manageExternalStorage.status;
        if (status.isGranted) {
          final result = await OpenFile.open(gpxFile.path);
          if (result.type == ResultType.done) {
            // debugPrint('GPX file opened successfully');
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Error opening GPX file')),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'External storage permission is required to open GPX files'),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('GPX file not found')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error opening GPX file')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: _onWillPop,
        child: Stack(
          children: [
            if (isLoading)
              const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              )
            else
              Scaffold(
                appBar: AppBar(
                  automaticallyImplyLeading: false,
                  title: const Text('PCIC Form'),
                  centerTitle: true,
                ),
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      form_field.FormField(
                        labelText: 'Last Coordinates',
                        initialValue: _taskData['trackLastcoord'] ?? '',
                        enabled: false,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _areaPlantedController,
                        decoration: const InputDecoration(
                          labelText: 'Date and Time',
                          border: OutlineInputBorder(),
                        ),
                        enabled: false,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _areaInHectaresController,
                        decoration: const InputDecoration(
                          labelText: 'Total Area (Hectares)',
                          border: OutlineInputBorder(),
                        ),
                        enabled: false,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _totalDistanceController,
                        decoration: const InputDecoration(
                          labelText: 'Total Distance',
                          border: OutlineInputBorder(),
                        ),
                        enabled: false,
                      ),
                      const SizedBox(height: 24),
                      FormSection(
                        key: _formSectionKey,
                        formData: _taskData,
                        uniqueSeedsItems: uniqueSeedsItems,
                        seedTitleToIdMap: seedTitleToIdMap,
                        isSubmitting: isSubmitting,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Signatures',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SignatureSection(
                          key: _signatureSectionKey,
                          task: widget.task,
                          isSubmitting: isSubmitting),
                      const SizedBox(height: 24),
                      const Text(
                        'Map Geotag',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      if (gpxFile != null)
                        GPXFileButtons(
                          openGpxFile: () {
                            _openGpxFile(gpxFile!);
                          },
                        )
                      else
                        Column(
                          children: [
                            const Text(
                              'Geotag failed: Initial and end points did not match to close the land for calculation.',
                              style: TextStyle(color: Colors.red),
                            ),
                            ElevatedButton(
                              onPressed: () => _navigateToGeotagPage(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Repeat Geotag'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                bottomNavigationBar: BottomAppBar(
                  elevation: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: _cancelForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: _saveForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Save'),
                      ),
                      ElevatedButton(
                        onPressed: () => _submitForm(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Submit'),
                      ),
                    ],
                  ),
                ),
              ),
            if (isSaving)
              Container(
                color: Colors.black54,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ));
  }
}
