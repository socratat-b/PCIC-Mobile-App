import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FormSection extends StatefulWidget {
  final Map<String, dynamic> formData;
  final List<DropdownMenuItem<int>> uniqueSeedsItems;
  final Map<String, int> seedTitleToIdMap;
  final bool isSubmitting;

  const FormSection(
      {super.key,
      required this.formData,
      required this.uniqueSeedsItems,
      required this.seedTitleToIdMap,
      required this.isSubmitting});

  @override
  FormSectionState createState() => FormSectionState();
}

class FormSectionState extends State<FormSection> {
  int? dropdownValue;
  final TextEditingController _ppirNameInsuredController =
      TextEditingController();
  final TextEditingController _ppirNameIuiaController = TextEditingController();
  final TextEditingController _ppirAreaController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _ppirDopdsActController = TextEditingController();
  final TextEditingController _ppirDoptpActController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _initializeDropdownValue();
    _initializeTextControllers();
    _setupListeners();
  }

  void _initializeDropdownValue() {
    String? seedTitle = widget.formData['ppirSvpAct']?.trim();
    if (seedTitle != null && widget.seedTitleToIdMap.containsKey(seedTitle)) {
      dropdownValue = widget.seedTitleToIdMap[seedTitle];
    } else {
      dropdownValue = null; // Set to null to show the placeholder
    }

    setState(() {
      widget.formData['ppirSvpAct'] = seedTitle;
    });
  }

  void _initializeTextControllers() {
    _ppirNameInsuredController.text = widget.formData['ppirNameInsured'] ?? '';
    _ppirNameIuiaController.text = widget.formData['ppirNameIuia'] ?? '';
    _ppirAreaController.text = widget.formData['ppirAreaAct'] ?? '';
    _remarksController.text = widget.formData['ppirRemarks'] ?? '';
    _ppirDopdsActController.text = widget.formData['ppirDopdsAct'] ?? '';
    _ppirDoptpActController.text = widget.formData['ppirDoptpAct'] ?? '';
  }

  void _setupListeners() {
    _ppirNameInsuredController.addListener(() {
      setState(() {}); // Update the UI to remove the error message
    });
    _ppirNameIuiaController.addListener(() {
      setState(() {}); // Update the UI to remove the error message
    });
    _ppirAreaController.addListener(() {
      setState(() {}); // Update the UI to remove the error message
    });
    _remarksController.addListener(() {
      setState(() {}); // Update the UI to remove the error message
    });
    _ppirDopdsActController.addListener(() {
      setState(() {}); // Update the UI to remove the error message
    });
    _ppirDoptpActController.addListener(() {
      setState(() {}); // Update the UI to remove the error message
    });
  }

  Future<void> _pickDate(BuildContext context, String key) async {
    DateTime initialDate = DateTime.now();
    if (widget.formData[key] != null && widget.formData[key].isNotEmpty) {
      initialDate = DateTime.parse(widget.formData[key]);
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (picked != null && picked != initialDate) {
      setState(() {
        widget.formData[key] = DateFormat('yyyy-MM-dd').format(picked);
        if (key == 'ppirDopdsAct') {
          _ppirDopdsActController.text =
              DateFormat('yyyy-MM-dd').format(picked);
        }
        if (key == 'ppirDoptpAct') {
          _ppirDoptpActController.text =
              DateFormat('yyyy-MM-dd').format(picked);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Seed Variety',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
                child: DropdownButtonFormField<int>(
                  isExpanded: true,
                  decoration: const InputDecoration.collapsed(hintText: ''),
                  value: dropdownValue,
                  items: widget.uniqueSeedsItems,
                  onChanged: (value) {
                    setState(() {
                      dropdownValue = value;
                      widget.formData['ppirSvpAct'] = widget
                          .seedTitleToIdMap.entries
                          .firstWhere((entry) => entry.value == value)
                          .key;
                    });
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a seed variety';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ppirAreaController,
                decoration: InputDecoration(
                  labelText: 'Actual Area Planted',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    widget.formData['ppirAreaAct'] = value;
                  });
                },
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'This field is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _pickDate(context, 'ppirDopdsAct'),
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Actual Date of Planting (DS)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    controller: _ppirDopdsActController,
                    readOnly: true,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'This field is required';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _pickDate(context, 'ppirDoptpAct'),
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Actual Date of Planting (TS)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    controller: _ppirDoptpActController,
                    readOnly: true,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'This field is required';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              // GestureDetector(
              //   onTap: () => _pickDate(context, 'ppirDoptpAct'),
              //   child: AbsorbPointer(
              //     child: TextFormField(
              //       decoration: InputDecoration(
              //         errorText: widget.isSubmitting &&
              //                 widget.formData['ppirDoptpAct'].isEmpty
              //             ? 'This field is required'
              //             : null,
              //         labelText: 'Actual Date of Planting (TP)',
              //         border: OutlineInputBorder(
              //           borderRadius: BorderRadius.circular(8),
              //         ),
              //         suffixIcon: const Icon(Icons.calendar_today),
              //       ),
              //       controller: TextEditingController(
              //         text: widget.formData['ppirDoptpAct'],
              //       ),
              //       onChanged: (value) {
              //         widget.formData['ppirDoptpAct'] = value;
              //       },
              //       autovalidateMode: AutovalidateMode.onUserInteraction,
              //       validator: (value) {
              //         if (value == null ||
              //             widget.formData['ppirDoptpAct'].isEmpty) {
              //           return 'This field is required';
              //         }
              //         return null;
              //       },
              //     ),
              //   ),
              // ),

              const SizedBox(height: 16),
              TextFormField(
                controller: _remarksController,
                decoration: InputDecoration(
                  labelText: 'Remarks',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 5,
                onChanged: (value) {
                  widget.formData['ppirRemarks'] = value;
                },
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (value) {
                  if (value == null || _remarksController.text.trim().isEmpty) {
                    return 'This field is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  bool validate() {
    return _formKey.currentState?.validate() ?? false;
  }
}