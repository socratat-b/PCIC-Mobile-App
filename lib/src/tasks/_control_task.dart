// file: control_task.dart
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:external_path/external_path.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';
import 'package:flutter/foundation.dart';

class TaskManager {
  final String taskId;
  final String formId;
  final String type;

  TaskManager({
    required this.formId,
    required this.taskId,
    required this.type,
  });

  factory TaskManager.fromMap(Map<String, dynamic> data) {
    return TaskManager(
      formId: data['formId'] ?? '',
      taskId: data['taskId'] ?? '',
      type: data['type'] ?? '',
    );
  }

  static Future<List<TaskManager>> getTasksByQuery(Query query) async {
    List<TaskManager> tasks = [];

    try {
      final querySnapshot = await query.get();
      debugPrint('Tasks fetched: ${querySnapshot.docs.length}');

      for (final documentSnapshot in querySnapshot.docs) {
        debugPrint(
            'Task Document ID: ${documentSnapshot.id}'); // Debugging statement
        final taskId = documentSnapshot.id;
        final taskData = documentSnapshot.data() as Map<String, dynamic>?;
        debugPrint('Task Data: $taskData'); // Debugging statement

        if (taskData != null) {
          final formDetailsIdRef =
              taskData['formDetailsId'] as DocumentReference?;
          debugPrint(
              'Form Details ID Ref: $formDetailsIdRef'); // Debugging statement

          if (formDetailsIdRef != null) {
            final formDetailsSnapshot = await formDetailsIdRef.get();

            if (formDetailsSnapshot.exists) {
              final formDetailsData =
                  formDetailsSnapshot.data() as Map<String, dynamic>?;
              debugPrint(
                  'Form Details Data: $formDetailsData'); // Debugging statement

              if (formDetailsData != null) {
                final formIdRef =
                    formDetailsData['formId'] as DocumentReference?;
                debugPrint('Form ID Ref: $formIdRef'); // Debugging statement

                if (formIdRef != null) {
                  final formId = formIdRef.id;
                  final type = formDetailsData['type'];

                  final task = TaskManager.fromMap({
                    'formId': formId,
                    'taskId': taskId,
                    'type': type,
                  });

                  tasks.add(task);
                }
              }
            }
          }
        }
      }
    } catch (error) {
      debugPrint('Error retrieving tasks: $error');
    }

    debugPrint('Total tasks processed: ${tasks.length}'); // Debugging statement
    return tasks;
  }

  static Future<List<TaskManager>> getTasksByStatus(String status) async {
    final query = FirebaseFirestore.instance
        .collection('tasks')
        .where('status', isEqualTo: status);
    return await getTasksByQuery(query);
  }

  static Future<List<TaskManager>> getAllTasks() async {
    final query = FirebaseFirestore.instance.collection('tasks');
    return await getTasksByQuery(query);
  }

  static Future<List<String>> _getCSVFilePaths() async {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final manifestMap = json.decode(manifestContent) as Map<String, dynamic>;

    List<String> csvPaths = manifestMap.keys
        .where((path) =>
            path.startsWith('assets/storage/mergedtask/') &&
            path.endsWith('.csv'))
        .toList();

    return csvPaths;
  }

  static Future<List<TaskManager>> getNotCompletedTasks() async {
    final query = FirebaseFirestore.instance
        .collection('tasks')
        .where('status', isNotEqualTo: 'Completed');
    return await getTasksByQuery(query);
  }

  static Future<List<List<dynamic>>> _loadCSVData(String filePath) async {
    final fileContent = await rootBundle.loadString(filePath);
    return const CsvToListConverter().convert(fileContent);
  }

  static Future<void> syncDataFromCSV() async {
    try {
      final csvFilePaths = await _getCSVFilePaths();

      for (final csvFilePath in csvFilePaths) {
        final csvData = await _loadCSVData(csvFilePath);

        // Skip the first row and empty rows
        final Iterable<List<dynamic>> rowsToProcess =
            csvData.skip(1).where((row) => row.isNotEmpty);

        for (final row in rowsToProcess) {
          final ppirInsuranceId = row[7]?.toString().trim() ?? '';

          if (ppirInsuranceId.isNotEmpty) {
            final ppirFormQuerySnapshot = await FirebaseFirestore.instance
                .collection('ppirForms')
                .where('ppirInsuranceId', isEqualTo: ppirInsuranceId)
                .limit(1)
                .get();

            if (ppirFormQuerySnapshot.docs.isEmpty) {
              await _createNewTaskAndRelatedDocuments(row);
            } else {
              debugPrint(
                  'Duplicate PPIR form detected with ppirInsuranceId: $ppirInsuranceId');
            }
          }
        }
      }

      await _deleteDuplicateForms();
    } catch (error) {
      debugPrint('Error syncing data from CSV: $error');
    }
  }

  static Future<void> _deleteDuplicateForms() async {
    final ppirFormsSnapshot =
        await FirebaseFirestore.instance.collection('ppirForms').get();
    final Map<String, List<QueryDocumentSnapshot>> duplicateFormsMap = {};

    for (final ppirForm in ppirFormsSnapshot.docs) {
      final ppirInsuranceId =
          ppirForm['ppirInsuranceId']?.toString().trim() ?? '';
      if (ppirInsuranceId.isNotEmpty) {
        if (duplicateFormsMap.containsKey(ppirInsuranceId)) {
          duplicateFormsMap[ppirInsuranceId]!.add(ppirForm);
        } else {
          duplicateFormsMap[ppirInsuranceId] = [ppirForm];
        }
      }
    }

    final List<Future> deletionFutures = [];

    for (var entry in duplicateFormsMap.entries) {
      final duplicateForms = entry.value;

      if (duplicateForms.length > 1) {
        for (int i = 1; i < duplicateForms.length; i++) {
          final duplicateForm = duplicateForms[i];
          final data = duplicateForm.data() as Map<String, dynamic>?;
          final formDetailsRef = data?['formDetailsId'] as DocumentReference?;
          final taskRef = data?['taskId'] as DocumentReference?;

          // Delete the ppirForm
          debugPrint('Deleting ppirForm: ${duplicateForm.id}');
          deletionFutures.add(duplicateForm.reference.delete());

          // Delete the formDetails
          if (formDetailsRef != null) {
            debugPrint('Deleting formDetailsRef: ${formDetailsRef.id}');
            try {
              final formDetailsSnapshot = await formDetailsRef.get();
              if (formDetailsSnapshot.exists) {
                final formDetailsData =
                    formDetailsSnapshot.data() as Map<String, dynamic>?;
                final relatedTaskRef =
                    formDetailsData?['taskId'] as DocumentReference?;

                // Delete the related task
                if (relatedTaskRef != null) {
                  debugPrint(
                      'Deleting related taskRef from formDetails: ${relatedTaskRef.id}');
                  deletionFutures.add(relatedTaskRef.delete());
                }

                // Delete the formDetails
                deletionFutures.add(formDetailsRef.delete());
              }
            } catch (e) {
              debugPrint(
                  'Error deleting formDetailsRef: ${formDetailsRef.id}, error: $e');
            }
          }

          // Delete the task
          if (taskRef != null) {
            debugPrint('Deleting taskRef: ${taskRef.id}');
            try {
              final taskSnapshot = await taskRef.get();
              if (taskSnapshot.exists) {
                final taskData = taskSnapshot.data() as Map<String, dynamic>?;
                final relatedFormDetailsRef =
                    taskData?['formDetailsId'] as DocumentReference?;

                // Delete the related formDetails
                if (relatedFormDetailsRef != null) {
                  debugPrint(
                      'Deleting related formDetailsRef from task: ${relatedFormDetailsRef.id}');
                  deletionFutures.add(relatedFormDetailsRef.delete());
                }

                // Delete the task
                deletionFutures.add(taskRef.delete());
              }
            } catch (e) {
              debugPrint('Error deleting taskRef: ${taskRef.id}, error: $e');
            }
          }
        }
      }
    }

    await Future.wait(deletionFutures);
    debugPrint('Deletion of duplicate forms completed.');
  }

  static Map<String, dynamic> _createTaskData(
      List<dynamic> row, String taskId, DocumentReference formDetailsRef) {
    return {
      'assignee': FirebaseFirestore.instance
          .collection('users')
          .doc(row[5]?.toString().trim() ?? ''),
      'assignor': null, // Assign appropriate assignor
      'formDetailsId': formDetailsRef,
      'dateCreated': FieldValue.serverTimestamp(),
      'dateAccess': FieldValue.serverTimestamp(),
      'status': row[4]?.toString().trim() ?? '',
    };
  }

  static Map<String, dynamic> _createFormDetailsData(
      List<dynamic> row, String formDetailsId, DocumentReference taskRef) {
    return {
      'taskId': taskRef,
      'formId':
          FirebaseFirestore.instance.collection('ppirForms').doc(formDetailsId),
      'type': row[2]?.toString().trim() ?? '',
    };
  }

  static Map<String, dynamic> _createPPIRFormData(
      List<dynamic> row, String ppirFormId, DocumentReference taskRef) {
    return {
      'taskId': taskRef,
      'generatedFilename': '',
      'taskManagerNumber': row[7]?.toString().trim() ?? '',
      'serviceGroup': row[1]?.toString().trim() ?? '',
      'serviceType': row[2]?.toString().trim() ?? '',
      'priority': row[3]?.toString().trim() ?? '',
      'status': row[4]?.toString().trim() ?? '',
      'assigneeId': row[5]?.toString().trim() ?? '',
      'ppirAssignmentId': row[6]?.toString().trim() ?? '',
      'ppirInsuranceId': row[7]?.toString().trim() ?? '',
      'ppirFarmerName': row[8]?.toString().trim() ?? '',
      'ppirAddress': row[9]?.toString().trim() ?? '',
      'ppirFarmerType': row[10]?.toString().trim() ?? '',
      'ppirMobileNo': row[11]?.toString().trim() ?? '',
      'ppirGroupName': row[12]?.toString().trim() ?? '',
      'ppirGroupAddress': row[13]?.toString().trim() ?? '',
      'ppirLenderName': row[14]?.toString().trim() ?? '',
      'ppirLenderAddress': row[15]?.toString().trim() ?? '',
      'ppirCicNo': row[16]?.toString().trim() ?? '',
      'ppirFarmLoc': row[17]?.toString().trim() ?? '',
      'ppirNorth': row[18]?.toString().trim() ?? '',
      'ppirSouth': row[19]?.toString().trim() ?? '',
      'ppirEast': row[20]?.toString().trim() ?? '',
      'ppirWest': row[21]?.toString().trim() ?? '',
      'ppirAtt1': row[22]?.toString().trim() ?? '',
      'ppirAtt2': row[23]?.toString().trim() ?? '',
      'ppirAtt3': row[24]?.toString().trim() ?? '',
      'ppirAtt4': row[25]?.toString().trim() ?? '',
      'ppirAreaAci': row[26]?.toString().trim() ?? '',
      'ppirAreaAct': row[27]?.toString().trim() ?? '',
      'ppirDopdsAci': row[28]?.toString().trim() ?? '',
      'ppirDopdsAct': row[29]?.toString().trim() ?? '',
      'ppirDoptpAci': row[30]?.toString().trim() ?? '',
      'ppirDoptpAct': row[31]?.toString().trim() ?? '',
      'ppirSvpAci': row[32]?.toString().trim() ?? '',
      'ppirSvpAct': row[33]?.toString().trim() ?? '',
      'ppirVariety': row[34]?.toString().trim() ?? '',
      'ppirStagecrop': row[35]?.toString().trim() ?? '',
      'ppirRemarks': row[36]?.toString().trim() ?? '',
      'ppirNameInsured': row[37]?.toString().trim() ?? '',
      'ppirNameIuia': row[38]?.toString().trim() ?? '',
      'ppirSigInsured': row[39]?.toString().trim() ?? '',
      'ppirSigIuia': row[40]?.toString().trim() ?? '',
      'trackTotalarea': '',
      'trackDatetime': FieldValue.serverTimestamp(),
      'trackLastcoord': '',
      'trackTotaldistance': '',
    };
  }

  static Future<void> _createNewTaskAndRelatedDocuments(
      List<dynamic> row) async {
    final ppirInsuranceId = row[7]?.toString().trim() ?? '';
    final assigneeEmail = row[5]?.toString().trim() ?? '';
    final ppirAssignmentId = row[6]?.toString().trim() ?? '';

    if (ppirInsuranceId.isNotEmpty &&
        assigneeEmail.isNotEmpty &&
        ppirAssignmentId.isNotEmpty) {
      final existingPPIRForms = await FirebaseFirestore.instance
          .collection('ppirForms')
          .where('ppirInsuranceId', isEqualTo: ppirInsuranceId)
          .get();

      if (existingPPIRForms.docs.isEmpty) {
        final taskRef = FirebaseFirestore.instance.collection('tasks').doc();
        final formDetailsRef =
            FirebaseFirestore.instance.collection('formDetails').doc();
        final ppirFormRef =
            FirebaseFirestore.instance.collection('ppirForms').doc();

        final taskData = _createTaskData(row, taskRef.id, formDetailsRef);
        final formDetailsData =
            _createFormDetailsData(row, ppirFormRef.id, taskRef);
        final ppirFormData = _createPPIRFormData(row, ppirFormRef.id, taskRef);

        final batch = FirebaseFirestore.instance.batch();
        batch.set(taskRef, taskData);
        batch.set(formDetailsRef, formDetailsData);
        batch.set(ppirFormRef, ppirFormData);
        await batch.commit();
      } else {
        debugPrint(
            'Duplicate PPIR form detected with ppirInsuranceId: $ppirInsuranceId');
      }
    }
  }

  static Map<String, dynamic> createTaskData(
      List<dynamic> row, String taskId, DocumentReference formDetailsRef) {
    return {
      'assignee': FirebaseFirestore.instance
          .collection('users')
          .doc(row[5]?.toString() ?? ''),
      'assignor': null, // Assign appropriate assignor
      'formDetailsId': formDetailsRef,
      'dateCreated': FieldValue.serverTimestamp(),
      'dateAccess': FieldValue.serverTimestamp(),
      'status': row[4]?.toString() ?? '',
    };
  }

  static Map<String, dynamic> createFormDetailsData(
      List<dynamic> row, String formDetailsId, DocumentReference taskRef) {
    return {
      'taskId': taskRef,
      'formId':
          FirebaseFirestore.instance.collection('ppirForms').doc(formDetailsId),
      'type': row[2]?.toString() ?? '',
    };
  }

  static Map<String, dynamic> createPPIRFormData(
      List<dynamic> row, String ppirFormId, DocumentReference taskRef) {
    return {
      'taskId': taskRef,
      'generatedFilename': '',
      'taskManagerNumber': row[7]?.toString() ?? '',
      'serviceGroup': row[1]?.toString() ?? '',
      'serviceType': row[2]?.toString() ?? '',
      'priority': row[3]?.toString() ?? '',
      'status': row[4]?.toString() ?? '',
      'assigneeId': row[5]?.toString() ?? '',
      'ppirAssignmentId': row[6]?.toString() ?? '',
      'ppirInsuranceId': row[7]?.toString() ?? '',
      'ppirFarmerName': row[8]?.toString() ?? '',
      'ppirAddress': row[9]?.toString() ?? '',
      'ppirFarmerType': row[10]?.toString() ?? '',
      'ppirMobileNo': row[11]?.toString() ?? '',
      'ppirGroupName': row[12]?.toString() ?? '',
      'ppirGroupAddress': row[13]?.toString() ?? '',
      'ppirLenderName': row[14]?.toString() ?? '',
      'ppirLenderAddress': row[15]?.toString() ?? '',
      'ppirCicNo': row[16]?.toString() ?? '',
      'ppirFarmLoc': row[17]?.toString() ?? '',
      'ppirNorth': row[18]?.toString() ?? '',
      'ppirSouth': row[19]?.toString() ?? '',
      'ppirEast': row[20]?.toString() ?? '',
      'ppirWest': row[21]?.toString() ?? '',
      'ppirAtt1': row[22]?.toString() ?? '',
      'ppirAtt2': row[23]?.toString() ?? '',
      'ppirAtt3': row[24]?.toString() ?? '',
      'ppirAtt4': row[25]?.toString() ?? '',
      'ppirAreaAci': row[26]?.toString() ?? '',
      'ppirAreaAct': row[27]?.toString() ?? '',
      'ppirDopdsAci': row[28]?.toString() ?? '',
      'ppirDopdsAct': row[29]?.toString() ?? '',
      'ppirDoptpAci': row[30]?.toString() ?? '',
      'ppirDoptpAct': row[31]?.toString() ?? '',
      'ppirSvpAci': row[32]?.toString() ?? '',
      'ppirSvpAct': row[33]?.toString() ?? '',
      'ppirVariety': row[34]?.toString() ?? '',
      'ppirStagecrop': row[35]?.toString() ?? '',
      'ppirRemarks': row[36]?.toString() ?? '',
      'ppirNameInsured': row[37]?.toString() ?? '',
      'ppirNameIuia': row[38]?.toString() ?? '',
      'ppirSigInsured': row[39]?.toString() ?? '',
      'ppirSigIuia': row[40]?.toString() ?? '',
      'trackTotalarea': '',
      'trackDatetime': FieldValue.serverTimestamp(),
      'trackLastcoord': '',
      'trackTotaldistance': '',
    };
  }

  Future<String?> get taskManagerNumber async {
    try {
      final formData = await getFormData(type);
      return formData['ppirInsuranceId'] as String?;
    } catch (error) {
      debugPrint('Error retrieving Task Number: $error');
      return null;
    }
  }

  Future<Map<String, dynamic>> getFormData(String formType) async {
    final db = FirebaseFirestore.instance;
    final document = await db.collection('ppirForms').doc(formId).get();

    if (document.exists) {
      return document.data() ?? {};
    }

    return {};
  }

  Future<void> assignTaskManagerNumberToFormData(
      String taskManagerNumber) async {
    final db = FirebaseFirestore.instance;

    await db.collection(type).doc(formId).update({
      'taskManagerNumber': taskManagerNumber,
    });
  }

  static Future<void> saveTaskToXML(
      Map<String, dynamic> taskData, Map<String, dynamic> formData) async {
    try {
      final String directoryPath =
          await ExternalPath.getExternalStoragePublicDirectory(
              ExternalPath.DIRECTORY_DOCUMENTS);
      final String fileName = 'task_${taskData['taskId']}.xml';
      final File xmlFile = File('$directoryPath/$fileName');

      if (taskData.isNotEmpty && formData.isNotEmpty) {
        final builder = XmlBuilder();
        builder.processing('xml', 'version="1.0" encoding="UTF-8"');
        builder.element('Task', nest: () {
          builder.element('TaskId', nest: taskData['taskId']);
          builder.element('TaskNumber',
              nest: taskData['taskManagerNumber'] ?? '');
          builder.element('FormType', nest: formData['serviceType'] ?? '');
          builder.element('Audit', nest: () {
            builder.element('TaskAuditLogZipModel', nest: () {
              builder.element('AuditLevel', nest: 'Task');
              builder.element('Label', nest: 'Task Owner');
              builder.element('Message', nest: taskData['assigneeId'] ?? '');
              builder.element('SnapshotValue', nest: 'Office Clerk');
              builder.element('Source', nest: taskData['assigneeId'] ?? '');
              builder.element('TaskId', nest: taskData['taskId']);
              builder.element('Timestamp',
                  nest: taskData['dateAccess']?.toString() ?? '');
              builder.element('UpdatedValue',
                  nest: taskData['assigneeEmail'] ?? '');
              builder.element('FieldLabel', nest: 'Task Owner');
              builder.element('IPAddress', nest: '');
            });
          });

          builder.element('Details', nest: () {
            builder.element('TaskDetailZipModel', nest: () {
              builder.element('ServiceType',
                  nest: formData['serviceType'] ?? '');
              builder.element('TaskStatus', nest: taskData['status'] ?? '');
              builder.element('TaskOwner',
                  nest: taskData['assigneeEmail'] ?? '');
            });
          });
        });

        final xmlDocument = builder.buildDocument();
        await xmlFile
            .writeAsString(xmlDocument.toXmlString(pretty: true, indent: '\t'));
        debugPrint('Task XML saved successfully.');
      } else {
        debugPrint('No task data or form data available to save.');
      }
    } catch (error) {
      debugPrint('Error saving Task XML: $error');
    }
  }

  Future<String?> get status async {
    try {
      final taskSnapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .doc(taskId)
          .get();

      if (taskSnapshot.exists) {
        final taskData = taskSnapshot.data();
        return taskData?['status'] as String?;
      }
    } catch (error) {
      debugPrint('Error retrieving task status: $error');
    }
    return null;
  }

  Future<DateTime?> get dateAccess async {
    try {
      final taskSnapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .doc(taskId)
          .get();

      if (taskSnapshot.exists) {
        final taskData = taskSnapshot.data();
        final timestamp = taskData?['dateAccess'] as Timestamp?;
        return timestamp?.toDate();
      }
    } catch (error) {
      debugPrint('Error retrieving task date access: $error');
    }
    return null;
  }
}
