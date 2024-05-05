// file: pcic_form.dart
import 'dart:io';
import 'package:external_path/external_path.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:archive/archive_io.dart';

import '../../utils/seeds/_dropdown.dart';
import '../geotag/_map_service.dart';
import '../signature/_signature_section.dart';
import '../tasks/_control_task.dart';
import './_form_field.dart' as form_field;
import './_form_section.dart' as form_section;
import '_success.dart';

class PCICFormPage extends StatefulWidget {
  final String imageFile;
  final String gpxFile;
  final TaskManager task;
  final List<LatLng> routePoints;
  final LatLng lastCoordinates;

  const PCICFormPage({
    super.key,
    required this.imageFile,
    required this.gpxFile,
    required this.task,
    required this.routePoints,
    required this.lastCoordinates,
  });

  @override
  PCICFormPageState createState() => PCICFormPageState();
}

class PCICFormPageState extends State<PCICFormPage> {
  List<Seeds> seedsList = Seeds.getAllTasks();
  Set<String> uniqueTitles = {};
  List<DropdownMenuItem<String>> uniqueSeedsItems = [];
  final _formData = <String, dynamic>{};
  final _areaPlantedController = TextEditingController();
  final _areaInHectaresController = TextEditingController();
  final _totalDistanceController = TextEditingController();
  final _signatureSectionKey = GlobalKey<SignatureSectionState>();

  @override
  void initState() {
    super.initState();
    _initializeFormData();
    _initializeSeeds();
    _calculateAreaAndDistance();
  }

  void _initializeFormData() {
    _formData['ppirDopdsAct'] = widget.task.csvData?['ppirDopdsAct'] ?? '';
    _formData['ppirDoptpAct'] = widget.task.csvData?['ppirDoptpAct'] ?? '';

    String? ppirVarietyValue = widget.task.csvData?['ppirVariety'] ?? '';
    if (ppirVarietyValue!.isNotEmpty &&
        uniqueTitles.contains(ppirVarietyValue)) {
      _formData['ppirVariety'] = ppirVarietyValue;
    } else {
      _formData['ppirVariety'] = null;
    }

    _formData['ppirRemarks'] = widget.task.csvData?['ppirRemarks'] ?? '';

    String lastCoordinateDateTime =
        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    _areaPlantedController.text = lastCoordinateDateTime;

    _formData['lastCoordinates'] =
        '${widget.lastCoordinates.latitude}, ${widget.lastCoordinates.longitude}';
  }

  void _initializeSeeds() {
    final uniqueSeedTitles = <String>{};

    uniqueSeedsItems.add(const DropdownMenuItem<String>(
      value: null,
      child: Text('Select a seed variety'),
    ));

    for (var seed in seedsList) {
      final seedTitle = seed.title;
      if (!uniqueSeedTitles.contains(seedTitle)) {
        uniqueSeedTitles.add(seedTitle);
        uniqueSeedsItems.add(DropdownMenuItem<String>(
          value: seedTitle,
          child: Text(seedTitle),
        ));
      }
    }
  }

  void _calculateAreaAndDistance() {
    final mapService = MapService();
    final distance = mapService.calculateTotalDistance(widget.routePoints);

    double area = 0.0;
    double areaInHectares = 0.0;

    if (widget.routePoints.isNotEmpty) {
      final initialPoint = widget.routePoints.first;
      final closingPoint = widget.routePoints.last;

      if (_isCloseEnough(initialPoint, closingPoint)) {
        area = mapService.calculateAreaOfPolygon(widget.routePoints);
        areaInHectares = area / 10000;
      }
    }

    setState(() {
      // _areaPlantedController.text = area > 0 ? _formatNumber(area, 'm²') : '';
      _areaInHectaresController.text =
          areaInHectares > 0 ? _formatNumber(areaInHectares, 'ha') : '';
      _totalDistanceController.text = _formatNumber(distance, 'm');
    });
  }

  bool _isCloseEnough(LatLng point1, LatLng point2) {
    const double threshold = 10.0; // Adjust the threshold as needed
    final distance = const Distance().as(LengthUnit.Meter, point1, point2);
    return distance <= threshold;
  }

  String _formatNumber(double value, String unit) {
    final formatter = NumberFormat('#,##0.############', 'en_US');

    switch (unit) {
      case 'm²':
        return '${formatter.format(value)} m²';
      case 'ha':
        return '${formatter.format(value)} ha';
      case 'm':
        return '${formatter.format(value)} m';
      default:
        return formatter.format(value);
    }
  }

  void _createTaskFile(BuildContext context) async {
    try {
      final filePath = await ExternalPath.getExternalStoragePublicDirectory(
        ExternalPath.DIRECTORY_DOWNLOADS,
      );

      final downloadsDirectory = Directory(filePath);

      final serviceType = widget.task.csvData?['serviceType'] ?? 'Service Type';
      final idMapping = {serviceType: widget.task.ppirInsuranceId};

      // Provide a default if no mapping exists
      final mappedId = idMapping[serviceType] ?? '000000';

      final baseFilename =
          '${serviceType.replaceAll(' ', ' - ')}_${serviceType.replaceAll(' ', '_')}_$mappedId';

      final directory = Directory('${downloadsDirectory.path}/$baseFilename');

      // Create the insurance directory if it doesn't exist
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Create the Attachments directory if it doesn't exist
      final attachmentsDirectory = Directory('${directory.path}/Attachments');
      if (!await attachmentsDirectory.exists()) {
        await attachmentsDirectory.create(recursive: true);
      }

      final zipFilePath = '${downloadsDirectory.path}/$baseFilename.task';
      final zipFile = File(zipFilePath);

      // Delete the existing TASK file if it already exists
      if (await zipFile.exists()) {
        await zipFile.delete();
      }

      final zipFileStream = zipFile.openWrite();
      final archive = Archive();

      // Get the list of ArchiveFile objects
      final archiveFiles = await addFilesToArchive(directory, directory.path);

      // Add the files to the archive
      for (final archiveFile in archiveFiles) {
        archive.addFile(archiveFile);
      }

      // Write the ZIP archive data
      final zipData = ZipEncoder().encode(archive);
      zipFileStream.add(zipData!);
      await zipFileStream.close();

      // Verify the TASK file
      if (await zipFile.exists()) {
        final zipSize = await zipFile.length();
        debugPrint('TASK file created successfully. Size: $zipSize bytes');
        SchedulerBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Form data saved as TASK')),
          );
        });

        // Delete the directory after the TASK file is successfully created
        // await _deleteDirectory(directory);
      } else {
        debugPrint('Failed to create TASK file');
        SchedulerBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error saving form data as TASK')),
          );
        });
      }
    } catch (e, stackTrace) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving form data as TASK')),
        );
      });
      debugPrint('Error saving form data as TASK: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  // Future<void> _deleteDirectory(Directory directory) async {
  //   try {
  //     if (await directory.exists()) {
  //       await directory.delete(recursive: true);
  //       debugPrint('Directory deleted: ${directory.path}');
  //     } else {
  //       debugPrint('Directory does not exist: ${directory.path}');
  //     }
  //   } catch (e) {
  //     debugPrint('Error deleting directory: ${directory.path}');
  //     debugPrint('Error details: $e');
  //   }
  // }

  Future<List<ArchiveFile>> addFilesToArchive(
      Directory dir, String rootPath) async {
    final archiveFiles = <ArchiveFile>[];
    final files = dir.listSync();

    for (var file in files) {
      if (file is File) {
        try {
          final fileContent = await file.readAsBytes();
          if (fileContent.isNotEmpty) {
            final archiveFile = ArchiveFile(
              file.path.replaceAll('$rootPath/', ''),
              fileContent.length,
              fileContent,
            );
            archiveFiles.add(archiveFile);
          } else {
            debugPrint('Skipping empty file: ${file.path}');
          }
        } catch (e) {
          debugPrint('Error adding file to archive: ${file.path}');
          debugPrint('Error details: $e');
        }
      } else if (file is Directory) {
        final attachmentsDirectory = Directory('${file.path}/Attachments');
        if (await attachmentsDirectory.exists()) {
          final signatureFiles = [
            File('${attachmentsDirectory.path}/insured_signature.png'),
            File('${attachmentsDirectory.path}/iuia_signature.png'),
          ];

          for (final signatureFile in signatureFiles) {
            if (await signatureFile.exists()) {
              final fileContent = await signatureFile.readAsBytes();
              final archiveFile = ArchiveFile(
                signatureFile.path.replaceAll('$rootPath/', ''),
                fileContent.length,
                fileContent,
              );
              archiveFiles.add(archiveFile);
            } else {
              debugPrint('Signature file not found: ${signatureFile.path}');
            }
          }
        }

        final xmlFile = File('${file.path}/Task.xml');
        if (await xmlFile.exists()) {
          final fileContent = await xmlFile.readAsBytes();
          final archiveFile = ArchiveFile(
            xmlFile.path.replaceAll('$rootPath/', ''),
            fileContent.length,
            fileContent,
          );
          archiveFiles.add(archiveFile);
        } else {
          debugPrint('XML file not found: ${xmlFile.path}');
        }

        archiveFiles.addAll(await addFilesToArchive(file, rootPath));
      }
    }

    return archiveFiles;
  }

  void _submitForm(BuildContext context) async {
    // Get a list of keys for the enabled fields
    final enabledFieldKeys = _formData.keys.where((key) {
      return key != 'lastCoordinates' &&
          key != 'trackTotalarea' &&
          key != 'trackDatetime' &&
          key != 'trackLastcoord' &&
          key != 'trackTotaldistance' &&
          key != 'ppirRemarks';
    }).toList();

    // Check if any of the enabled fields are empty
    bool hasEmptyEnabledFields = enabledFieldKeys.any((key) =>
        _formData[key] == null || _formData[key].toString().trim().isEmpty);

    // Get the signature data from the SignatureSection
    final signatureData =
        await _signatureSectionKey.currentState?.getSignatureData() ?? {};

    // Check if any of the signature fields are empty
    bool hasEmptySignatureFields = signatureData['ppirSigInsured'] == null ||
        signatureData['ppirNameInsured']?.trim().isEmpty == true ||
        signatureData['ppirSigIuia'] == null ||
        signatureData['ppirNameIuia']?.trim().isEmpty == true;

    if (hasEmptyEnabledFields || hasEmptySignatureFields) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Incomplete Form'),
          content: const Text(
              'Please fill in all required fields and provide signatures before submitting the form.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Show the confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Are you sure the data above is correct?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              _saveFormData();
              _createTaskFile(context);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  void _saveFormData() async {
    // Get the signature data from the SignatureSection
    final signatureData =
        await _signatureSectionKey.currentState?.getSignatureData() ?? {};

    // Update the additional columns
    _formData['trackTotalarea'] = _areaInHectaresController.text;
    _formData['trackDatetime'] = _areaPlantedController.text;
    _formData['trackLastcoord'] = _formData['lastCoordinates'];
    _formData['trackTotaldistance'] = _totalDistanceController.text;

    // Update the remarks and signature fields with default values if null
    _formData['ppirRemarks'] = _formData['ppirRemarks'] ?? 'no value';
    _formData['ppirSigInsured'] = signatureData['ppirSigInsured'] ?? 'no value';
    _formData['ppirNameInsured'] =
        signatureData['ppirNameInsured'] ?? 'no value';
    _formData['ppirSigIuia'] = signatureData['ppirSigIuia'] ?? 'no value';
    _formData['ppirNameIuia'] = signatureData['ppirNameIuia'] ?? 'no value';

    widget.task.updateCsvData(_getChangedData());
    widget.task.isCompleted = true;

    // Save the signature files
    _saveSignatureFiles(signatureData, widget.task.csvData?['serviceType'],
        widget.task.ppirInsuranceId);

    // Save the XML file
    await widget.task.saveXmlData(
        widget.task.csvData?['serviceType'], widget.task.ppirInsuranceId);

    // Create the .task file
    if (mounted) {
      _createTaskFile(context);

      // Update the task in Firebase after saving the files
      _updateTaskInFirebase();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const FormSuccessPage(
            isSaveSuccessful: true,
          ),
        ),
      );
    }
  }

  Map<String, dynamic> _getChangedData() {
    Map<String, dynamic> changedData = {};

    _formData.forEach((key, value) {
      if (value != widget.task.csvData?[key]) {
        changedData[key] = value;
      }
    });

    return changedData;
  }

  void _updateTaskInFirebase() {
    final databaseReference = FirebaseDatabase.instance.ref();
    final taskId = widget.task.ppirInsuranceId.toString();
    final taskPath = 'tasks/task-$taskId';

    debugPrint('Updating task: $taskPath');

    final updatedTask = <String, dynamic>{
      'isCompleted': true,
    };

    databaseReference.child(taskPath).update(updatedTask).then((_) {
      debugPrint('Task updated successfully');
    }).catchError((error) {
      debugPrint('Error updating task: $error');
    });
  }

  void _cancelForm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Are you sure you want to cancel?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  void _viewScreenshot(String screenshotPath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Screenshot'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: Image.file(
                  File(screenshotPath),
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16),
              const Text('This is the screenshot captured during the task.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PCIC Form'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _cancelForm(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            form_field.FormField(
              labelText: 'Last Coordinates',
              initialValue: _formData['lastCoordinates'],
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
            form_section.FormSection(
              formData: _formData,
              uniqueSeedsItems: uniqueSeedsItems,
            ),
            const SizedBox(height: 24),
            const Text(
              'Signatures',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SignatureSection(
              key: _signatureSectionKey,
              task: widget.task,
            ),
            const SizedBox(height: 24),
            const Text(
              'Map Screenshot',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _viewScreenshot(widget.imageFile),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                textStyle: const TextStyle(fontSize: 16),
              ),
              child: const Text('View Screenshot'),
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
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _submitForm(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveSignatureFiles(Map<String, dynamic> signatureData,
      String? serviceType, int ppirInsuranceId) async {
    try {
      final filePath = await ExternalPath.getExternalStoragePublicDirectory(
        ExternalPath.DIRECTORY_DOWNLOADS,
      );

      final downloadsDirectory = Directory(filePath);

      if (serviceType == null || serviceType.isEmpty) {
        serviceType = 'Service Type';
      }

      final baseFilename =
          '${serviceType.replaceAll(' ', ' - ')}_${serviceType.replaceAll(' ', '_')}_$ppirInsuranceId';

      final insuranceDirectory =
          Directory('${downloadsDirectory.path}/$baseFilename');

      // Create the insurance directory if it doesn't exist
      if (!await insuranceDirectory.exists()) {
        await insuranceDirectory.create(recursive: true);
      }

      // Save the confirmed by signature file
      if (signatureData['ppirSigInsured'] != null) {
        final confirmedByFile = File(
            '${insuranceDirectory.path}/Attachments/insured_signature.png');
        await confirmedByFile.writeAsBytes(signatureData['ppirSigInsured']);
        debugPrint('Confirmed by signature saved: ${confirmedByFile.path}');
      }

      // Save the prepared by signature file
      if (signatureData['ppirSigIuia'] != null) {
        final preparedByFile =
            File('${insuranceDirectory.path}/Attachments/iuia_signature.png');
        await preparedByFile.writeAsBytes(signatureData['ppirSigIuia']);
        debugPrint('Prepared by signature saved: ${preparedByFile.path}');
      }
    } catch (e, stackTrace) {
      debugPrint('Error saving signature files: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }
}