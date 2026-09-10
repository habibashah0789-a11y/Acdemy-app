import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../models/student_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../student_portal/student_auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/celebration_overlay.dart';
import '../widgets/student_qr_widget.dart';
import '../services/sound_service.dart';

/// Data model for each row in the spreadsheet table.
class BulkRowData {
  final String id;
  final TextEditingController nameC;
  final TextEditingController fatherC;
  final TextEditingController phoneC;
  final TextEditingController emailC;
  String classType;
  String grade;
  Map<String, String> selectedSubjectSchedules;
  final TextEditingController subjectsC;
  final TextEditingController schedulesC;
  final TextEditingController totalFeeC;
  final TextEditingController paidFeeC;

  final FocusNode nameFocus = FocusNode();
  final FocusNode fatherFocus = FocusNode();
  final FocusNode phoneFocus = FocusNode();
  final FocusNode emailFocus = FocusNode();
  final FocusNode classFocus = FocusNode();
  final FocusNode gradeFocus = FocusNode();
  final FocusNode subjectsFocus = FocusNode();
  final FocusNode schedulesFocus = FocusNode();
  final FocusNode totalFeeFocus = FocusNode();
  final FocusNode paidFeeFocus = FocusNode();

  bool hasError = false;
  String? errorMessage;
  Set<String> errorFields = {};

  BulkRowData({
    required this.id,
    String name = '',
    String father = '',
    String phone = '',
    String email = '',
    this.classType = 'FSc',
    this.grade = 'First Year',
    Map<String, String>? subjectSchedules,
    String totalFee = '',
    String paidFee = '',
  })  : nameC = TextEditingController(text: name),
        fatherC = TextEditingController(text: father),
        phoneC = TextEditingController(text: phone),
        emailC = TextEditingController(text: email),
        selectedSubjectSchedules = Map<String, String>.from(subjectSchedules ?? {'Biology': '7:00 AM'}),
        subjectsC = TextEditingController(text: (subjectSchedules ?? {'Biology': '7:00 AM'}).keys.join(', ')),
        schedulesC = TextEditingController(text: (subjectSchedules ?? {'Biology': '7:00 AM'}).values.join(', ')),
        totalFeeC = TextEditingController(text: totalFee),
        paidFeeC = TextEditingController(text: paidFee);

  void dispose() {
    nameC.dispose();
    fatherC.dispose();
    phoneC.dispose();
    emailC.dispose();
    subjectsC.dispose();
    schedulesC.dispose();
    totalFeeC.dispose();
    paidFeeC.dispose();

    nameFocus.dispose();
    fatherFocus.dispose();
    phoneFocus.dispose();
    emailFocus.dispose();
    classFocus.dispose();
    gradeFocus.dispose();
    subjectsFocus.dispose();
    schedulesFocus.dispose();
    totalFeeFocus.dispose();
    paidFeeFocus.dispose();
  }
}

class BulkStudentRegistrationWidget extends StatefulWidget {
  final String? presetClassType;
  final String? presetSubject;
  final String? presetGrade;
  final String? presetSchedule;

  const BulkStudentRegistrationWidget({
    super.key,
    this.presetClassType,
    this.presetSubject,
    this.presetGrade,
    this.presetSchedule,
  });

  @override
  State<BulkStudentRegistrationWidget> createState() => _BulkStudentRegistrationWidgetState();
}

class _BulkStudentRegistrationWidgetState extends State<BulkStudentRegistrationWidget> {
  final List<BulkRowData> _rows = [];
  final ScrollController _horizontalScroll = ScrollController();
  final ScrollController _verticalScroll = ScrollController();
  final FocusNode _keyboardFocusNode = FocusNode();

  // Registration Defaults
  String _defaultClassType = 'FSc';
  String _defaultGrade = 'First Year';
  Map<String, String> _defaultSubjectSchedules = {'Biology': '7:00 AM'};
  String _defaultTotalFee = '4000';
  String _defaultPaidFee = '4000';

  bool _isSaving = false;
  int _savedCount = 0;
  int _totalToSave = 0;
  String _statusText = '';

  static const List<String> _classTypes = ['FSc', 'Matric', 'MDCAT'];
  static const Map<String, List<String>> _gradeOptions = {
    'FSc': ['First Year', 'Second Year'],
    'Matric': ['Ninth', 'Tenth'],
    'MDCAT': ['MDCAT Session'],
  };
  static const List<String> _subjects = ['Biology', 'Physics', 'Chemistry', 'English', 'Math'];
  static const List<String> _scheduleSlots = [
    '7:00 AM', '8:00 AM', '9:00 AM', '10:00 AM', '11:00 AM',
    '12:00 PM', '1:00 PM', '2:00 PM', '3:00 PM', '4:00 PM',
    '5:00 PM', '6:00 PM', '7:00 PM', '8:00 PM', '9:00 PM', '10:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.presetClassType != null) {
      _defaultClassType = widget.presetClassType!;
    }
    if (widget.presetGrade != null) {
      _defaultGrade = widget.presetGrade!;
    } else if (widget.presetClassType != null) {
      _defaultGrade = _gradeOptions[_defaultClassType]!.first;
    }
    if (widget.presetSubject != null) {
      _defaultSubjectSchedules = {widget.presetSubject!: widget.presetSchedule ?? '7:00 AM'};
    }

    // Add initial 5 blank rows for data entry
    for (int i = 0; i < 5; i++) {
      _addRow(initial: true);
    }
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    _horizontalScroll.dispose();
    _verticalScroll.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  // ── Row Operations ────────────────────────────────────────────────────────

  void _addRow({bool initial = false}) {
    setState(() {
      final newRow = BulkRowData(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        classType: _defaultClassType,
        grade: _defaultGrade,
        subjectSchedules: _defaultSubjectSchedules,
        totalFee: _defaultTotalFee,
        paidFee: _defaultPaidFee,
      );
      _rows.add(newRow);
    });

    if (!initial && _rows.length > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _getFocusNode(_rows.length - 1, 0).requestFocus();
      });
    }
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Table must have at least one row.')),
      );
      return;
    }
    setState(() {
      final removed = _rows.removeAt(index);
      removed.dispose();
    });
  }

  void _applyDefaultsToAllRows() {
    setState(() {
      for (final r in _rows) {
        r.classType = _defaultClassType;
        r.grade = _defaultGrade;
        r.totalFeeC.text = _defaultTotalFee;
        r.paidFeeC.text = _defaultPaidFee;
        r.selectedSubjectSchedules = Map<String, String>.from(_defaultSubjectSchedules);
        r.subjectsC.text = _defaultSubjectSchedules.keys.join(', ');
        r.schedulesC.text = _defaultSubjectSchedules.values.join(', ');
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Applied default values to all rows!'), backgroundColor: AppTheme.primaryBlue),
    );
  }

  String? _normalizeSubject(String raw) {
    final s = raw.toLowerCase().trim();
    if (s == 'bio' || s == 'biology') return 'Biology';
    if (s == 'phy' || s == 'physics') return 'Physics';
    if (s == 'chem' || s == 'chemistry') return 'Chemistry';
    if (s == 'eng' || s == 'english') return 'English';
    if (s == 'math' || s == 'maths' || s == 'mathematics') return 'Math';
    
    for (final standard in _subjects) {
      if (standard.toLowerCase() == s) return standard;
    }
    return null;
  }

  String _normalizeSchedule(String raw) {
    final s = raw.toUpperCase().trim();
    for (final slot in _scheduleSlots) {
      if (slot.toUpperCase() == s) return slot;
    }
    if (RegExp(r'^\d+$').hasMatch(s)) {
      final hour = int.parse(s);
      if (hour >= 1 && hour <= 12) {
        return '$hour:00 ${hour >= 7 && hour < 12 ? 'AM' : 'PM'}';
      }
    }
    return raw.isEmpty ? '7:00 AM' : raw;
  }

  void _syncSubjectSchedulesFromText(BulkRowData r) {
    r.selectedSubjectSchedules.clear();
    final subjectList = r.subjectsC.text.split(RegExp(r'[,;]')).map((s) => s.trim()).toList();
    final scheduleList = r.schedulesC.text.split(RegExp(r'[,;]')).map((s) => s.trim()).toList();

    for (int i = 0; i < subjectList.length; i++) {
      final rawSub = subjectList[i];
      if (rawSub.isEmpty) continue;
      
      final normalizedSub = _normalizeSubject(rawSub);
      if (normalizedSub == null) continue;

      String sched = '7:00 AM';
      if (i < scheduleList.length && scheduleList[i].isNotEmpty) {
        sched = _normalizeSchedule(scheduleList[i]);
      } else if (scheduleList.isNotEmpty && scheduleList.first.isNotEmpty) {
        sched = _normalizeSchedule(scheduleList.first);
      }
      r.selectedSubjectSchedules[normalizedSub] = sched;
    }
  }

  void _copyPreviousRow(int index) {
    if (index <= 0 || index >= _rows.length) return;
    final prev = _rows[index - 1];
    final curr = _rows[index];

    setState(() {
      curr.classType = prev.classType;
      curr.grade = prev.grade;
      curr.selectedSubjectSchedules = Map<String, String>.from(prev.selectedSubjectSchedules);
      curr.subjectsC.text = prev.subjectsC.text;
      curr.schedulesC.text = prev.schedulesC.text;
      curr.totalFeeC.text = prev.totalFeeC.text;
      curr.paidFeeC.text = prev.paidFeeC.text;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied values from Row #$index to Row #${index + 1}')),
    );
  }

  void _showSubjectSchedulesDialog(BulkRowData row) {
    showDialog(
      context: context,
      builder: (ctx) {
        Map<String, String> tempSchedules = Map<String, String>.from(row.selectedSubjectSchedules);
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Select Subjects & Schedules', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
              content: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85 < 420 ? MediaQuery.of(context).size.width * 0.85 : 420),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _subjects.map((sub) {
                      final isChecked = tempSchedules.containsKey(sub);
                      final currentSchedule = tempSchedules[sub] ?? '7:00 AM';
                      
                      return CheckboxListTile(
                        title: Text(sub, style: TextStyle(fontWeight: isChecked ? FontWeight.bold : FontWeight.normal)),
                        value: isChecked,
                        activeColor: AppTheme.primaryBlue,
                        controlAffinity: ListTileControlAffinity.leading,
                        subtitle: isChecked
                            ? DropdownButton<String>(
                                value: currentSchedule,
                                isDense: true,
                                underline: const SizedBox(),
                                items: _scheduleSlots.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: (sVal) {
                                  if (sVal != null) {
                                    setDialogState(() {
                                      tempSchedules[sub] = sVal;
                                    });
                                  }
                                },
                              )
                            : null,
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) {
                              tempSchedules[sub] = '7:00 AM';
                            } else {
                              tempSchedules.remove(sub);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      row.selectedSubjectSchedules = tempSchedules;
                      row.subjectsC.text = tempSchedules.keys.join(', ');
                      row.schedulesC.text = tempSchedules.values.join(', ');
                    });
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDefaultSubjectSchedulesDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        Map<String, String> tempSchedules = Map<String, String>.from(_defaultSubjectSchedules);
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Select Default Subjects & Schedules', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
              content: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85 < 420 ? MediaQuery.of(context).size.width * 0.85 : 420),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _subjects.map((sub) {
                      final isChecked = tempSchedules.containsKey(sub);
                      final currentSchedule = tempSchedules[sub] ?? '7:00 AM';
                      
                      return CheckboxListTile(
                        title: Text(sub, style: TextStyle(fontWeight: isChecked ? FontWeight.bold : FontWeight.normal)),
                        value: isChecked,
                        activeColor: AppTheme.primaryBlue,
                        controlAffinity: ListTileControlAffinity.leading,
                        subtitle: isChecked
                            ? DropdownButton<String>(
                                value: currentSchedule,
                                isDense: true,
                                underline: const SizedBox(),
                                items: _scheduleSlots.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: (sVal) {
                                  if (sVal != null) {
                                    setDialogState(() {
                                      tempSchedules[sub] = sVal;
                                    });
                                  }
                                },
                              )
                            : null,
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) {
                              tempSchedules[sub] = '7:00 AM';
                            } else {
                              tempSchedules.remove(sub);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _defaultSubjectSchedules = tempSchedules;
                    });
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Keyboard & Cell Focus Movement ────────────────────────────────────────

  FocusNode _getFocusNode(int rowIdx, int colIdx) {
    if (rowIdx < 0 || rowIdx >= _rows.length) return FocusNode();
    final r = _rows[rowIdx];
    switch (colIdx) {
      case 0: return r.nameFocus;
      case 1: return r.fatherFocus;
      case 2: return r.phoneFocus;
      case 3: return r.emailFocus;
      case 4: return r.classFocus;
      case 5: return r.gradeFocus;
      case 6: return r.subjectsFocus;
      case 7: return r.schedulesFocus;
      case 8: return r.totalFeeFocus;
      case 9: return r.paidFeeFocus;
      default: return r.nameFocus;
    }
  }

  void _moveNextCell(int rowIdx, int colIdx) {
    if (colIdx < 9) {
      _getFocusNode(rowIdx, colIdx + 1).requestFocus();
    } else {
      // Last column in row (Paid Fee) -> move to next row column 0 (Name)
      if (rowIdx < _rows.length - 1) {
        _getFocusNode(rowIdx + 1, 0).requestFocus();
      } else {
        // Last row last column -> auto add row & focus column 0 of new row
        _addRow();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _getFocusNode(_rows.length - 1, 0).requestFocus();
        });
      }
    }
  }

  void _handleCellKeyEvent({
    required KeyEvent event,
    required int rowIdx,
    required int colIdx,
  }) {
    if (event is! KeyDownEvent) return;

    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

    if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _moveNextCell(rowIdx, colIdx);
    } else if (event.logicalKey == LogicalKeyboardKey.tab) {
      if (isShiftPressed) {
        if (colIdx > 0) {
          _getFocusNode(rowIdx, colIdx - 1).requestFocus();
        } else if (rowIdx > 0) {
          _getFocusNode(rowIdx - 1, 9).requestFocus();
        }
      } else {
        _moveNextCell(rowIdx, colIdx);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (rowIdx > 0) {
        _getFocusNode(rowIdx - 1, colIdx).requestFocus();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (rowIdx < _rows.length - 1) {
        _getFocusNode(rowIdx + 1, colIdx).requestFocus();
      } else {
        _addRow();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _getFocusNode(_rows.length - 1, colIdx).requestFocus();
        });
      }
    }
  }

  // ── Clipboard Paste (Excel / Google Sheets Parser) ─────────────────────────

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null || data.text == null || data.text!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipboard is empty or contains non-text data.')),
      );
      return;
    }

    final text = data.text!.trim();
    final rawLines = text.split(RegExp(r'\r?\n'));
    int insertedCount = 0;

    setState(() {
      for (int i = 0; i < rawLines.length; i++) {
        final line = rawLines[i].trim();
        if (line.isEmpty) continue;

        // Split by TAB (\t) or comma if CSV style
        final delimiter = line.contains('\t') ? '\t' : ',';
        final cells = line.split(delimiter).map((c) => c.trim()).toList();

        final name = cells.isNotEmpty ? cells[0] : '';
        final father = cells.length > 1 ? cells[1] : '';
        final phone = cells.length > 2 ? cells[2] : '';
        final email = cells.length > 3 ? cells[3] : '';
        
        String classType = _defaultClassType;
        if (cells.length > 4) {
          classType = _classTypes.contains(cells[4]) ? cells[4] : _defaultClassType;
        }
        
        String grade = _defaultGrade;
        if (cells.length > 5) {
          grade = (_gradeOptions[classType]?.contains(cells[5]) ?? false) ? cells[5] : _defaultGrade;
        }

        String subjectsText = '';
        String schedulesText = '';
        String totalFee = _defaultTotalFee;
        String paidFee = _defaultPaidFee;

        if (cells.length >= 10) {
          // New format: contains Subjects and Schedules
          subjectsText = cells[6];
          schedulesText = cells[7];
          totalFee = cells[8];
          paidFee = cells[9];
        } else {
          // Old format: fallback to defaults for subjects and schedules
          subjectsText = _defaultSubjectSchedules.keys.join(', ');
          schedulesText = _defaultSubjectSchedules.values.join(', ');
          if (cells.length > 6) {
            totalFee = cells[6];
          }
          if (cells.length > 7) {
            paidFee = cells[7];
          }
        }

        if (name.isEmpty && father.isEmpty && phone.isEmpty) continue;

        // Find an empty row or append new row
        BulkRowData? targetRow;
        for (final r in _rows) {
          if (r.nameC.text.trim().isEmpty && r.fatherC.text.trim().isEmpty && r.phoneC.text.trim().isEmpty) {
            targetRow = r;
            break;
          }
        }

        if (targetRow == null) {
          targetRow = BulkRowData(
            id: '${DateTime.now().microsecondsSinceEpoch}_$i',
            classType: classType,
            grade: grade,
            subjectSchedules: _defaultSubjectSchedules,
            totalFee: totalFee,
            paidFee: paidFee,
          );
          _rows.add(targetRow);
        }

        targetRow.nameC.text = name;
        targetRow.fatherC.text = father;
        targetRow.phoneC.text = phone;
        targetRow.emailC.text = email;
        targetRow.classType = classType;
        targetRow.grade = grade;
        targetRow.subjectsC.text = subjectsText;
        targetRow.schedulesC.text = schedulesText;
        targetRow.totalFeeC.text = totalFee;
        targetRow.paidFeeC.text = paidFee;
        targetRow.hasError = false;
        targetRow.errorFields.clear();

        _syncSubjectSchedulesFromText(targetRow);

        insertedCount++;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pasted $insertedCount student record(s) from Excel!'),
        backgroundColor: AppTheme.secondaryGreen,
      ),
    );
  }

  // ── CSV File Import ───────────────────────────────────────────────────────

  Future<void> _importCsvFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );

      if (result == null || result.files.isEmpty) return;

      String fileContent = '';
      final file = result.files.first;

      if (kIsWeb) {
        if (file.bytes != null) {
          fileContent = utf8.decode(file.bytes!);
        }
      } else if (file.path != null) {
        fileContent = await File(file.path!).readAsString();
      }

      if (fileContent.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected CSV file is empty.')),
        );
        return;
      }

      await Clipboard.setData(ClipboardData(text: fileContent));
      await _pasteFromClipboard();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to import CSV: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ── Live Cell Validation ─────────────────────────────────────────────────

  bool _validateAllRows({bool showSnack = true}) {
    bool hasAnyError = false;
    int errorCount = 0;
    int firstErrorRowIndex = -1;
    String firstErrorField = '';

    setState(() {
      for (int i = 0; i < _rows.length; i++) {
        final r = _rows[i];
        r.hasError = false;
        r.errorMessage = null;
        r.errorFields.clear();

        final name = r.nameC.text.trim();
        final father = r.fatherC.text.trim();
        final phone = r.phoneC.text.trim();
        final totalFee = double.tryParse(r.totalFeeC.text.trim());
        final paidFee = double.tryParse(r.paidFeeC.text.trim());

        // Ignore rows that are completely empty
        if (name.isEmpty && father.isEmpty && phone.isEmpty) {
          continue;
        }

        // Sync inputs from TextFields to the map
        _syncSubjectSchedulesFromText(r);

        if (name.isEmpty) {
          r.hasError = true;
          r.errorFields.add('name');
          r.errorMessage = 'Name is required';
        }
        if (father.isEmpty) {
          r.hasError = true;
          r.errorFields.add('father');
          r.errorMessage = r.errorMessage != null ? '${r.errorMessage!}, Father Name is required' : 'Father Name is required';
        }
        if (phone.isEmpty) {
          r.hasError = true;
          r.errorFields.add('phone');
          r.errorMessage = r.errorMessage != null ? '${r.errorMessage!}, Phone Number is required' : 'Phone Number is required';
        }

        // Subject Validation
        final subjectList = r.subjectsC.text.split(RegExp(r'[,;]')).map((s) => s.trim()).toList();
        bool hasInvalidSubject = false;
        for (final rawSub in subjectList) {
          if (rawSub.isNotEmpty && _normalizeSubject(rawSub) == null) {
            hasInvalidSubject = true;
            break;
          }
        }

        if (r.selectedSubjectSchedules.isEmpty) {
          r.hasError = true;
          r.errorFields.add('subjects');
          r.errorMessage = r.errorMessage != null 
              ? '${r.errorMessage!}, At least one valid subject is required' 
              : 'At least one valid subject is required';
        } else if (hasInvalidSubject) {
          r.hasError = true;
          r.errorFields.add('subjects');
          r.errorMessage = r.errorMessage != null
              ? '${r.errorMessage!}, One or more subjects are invalid'
              : 'One or more subjects are invalid';
        }

        if (totalFee == null || totalFee < 0) {
          r.hasError = true;
          r.errorFields.add('totalFee');
          r.errorMessage = r.errorMessage != null ? '${r.errorMessage!}, Invalid Total Fee' : 'Invalid Total Fee';
        }
        if (paidFee == null || paidFee < 0) {
          r.hasError = true;
          r.errorFields.add('paidFee');
          r.errorMessage = r.errorMessage != null ? '${r.errorMessage!}, Invalid Paid Fee' : 'Invalid Paid Fee';
        }

        if (r.hasError) {
          hasAnyError = true;
          errorCount++;
          if (firstErrorRowIndex == -1) {
            firstErrorRowIndex = i;
            firstErrorField = r.errorFields.first;
          }
        }
      }
    });

    if (hasAnyError) {
      if (showSnack) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$errorCount row(s) contain errors. Please correct highlighted fields.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      // Focus first error field
      if (firstErrorRowIndex != -1) {
        int colToFocus = 0;
        if (firstErrorField == 'father') {
          colToFocus = 1;
        } else if (firstErrorField == 'phone') {
          colToFocus = 2;
        } else if (firstErrorField == 'email') {
          colToFocus = 3;
        } else if (firstErrorField == 'subjects') {
          colToFocus = 6;
        } else if (firstErrorField == 'schedules') {
          colToFocus = 7;
        } else if (firstErrorField == 'totalFee') {
          colToFocus = 8;
        } else if (firstErrorField == 'paidFee') {
          colToFocus = 9;
        }

        _getFocusNode(firstErrorRowIndex, colToFocus).requestFocus();
      }
      return false;
    }
    return true;
  }

  // ── Duplicate Detection ────────────────────────────────────────────────

  Future<List<String>> _checkForDuplicates() async {
    final List<String> warnings = [];

    final Set<String> seenPhones = {};
    final Set<String> seenNames = {};

    for (int i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      final name = r.nameC.text.trim();
      final father = r.fatherC.text.trim();
      final phone = r.phoneC.text.trim();

      if (name.isEmpty && father.isEmpty && phone.isEmpty) continue;

      if (phone.isNotEmpty) {
        if (seenPhones.contains(phone)) {
          warnings.add('Row #${i + 1}: Duplicate phone number "$phone" found in bulk table.');
        } else {
          seenPhones.add(phone);
        }
      }

      final nameKey = '${name.toLowerCase()}_${father.toLowerCase()}_${r.classType.toLowerCase()}';
      if (name.isNotEmpty && father.isNotEmpty) {
        if (seenNames.contains(nameKey)) {
          warnings.add('Row #${i + 1}: Duplicate student "$name s/o $father" found in bulk table.');
        } else {
          seenNames.add(nameKey);
        }
      }
    }

    final existingStudents = DatabaseService.getAllStudentsLocal();
    for (int i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      final name = r.nameC.text.trim();
      final father = r.fatherC.text.trim();
      final phone = r.phoneC.text.trim();

      if (name.isEmpty) continue;

      for (final existing in existingStudents) {
        bool matchPhone = phone.isNotEmpty && existing.phone.trim() == phone;
        bool matchName = name.toLowerCase() == existing.firstName.toLowerCase() &&
            father.toLowerCase() == existing.fatherName.toLowerCase();

        if (matchPhone || matchName) {
          warnings.add(
            'Row #${i + 1}: "$name" matches existing student "${existing.name}" (Code: ${existing.studentCode}, Phone: ${existing.phone}) in database.',
          );
          break;
        }
      }
    }

    return warnings;
  }

  // ── Batch Save All Students ──────────────────────────────────────────────

  Future<void> _saveAllStudents() async {
    final validRowsToSave = _rows.where((r) {
      final name = r.nameC.text.trim();
      final father = r.fatherC.text.trim();
      final phone = r.phoneC.text.trim();
      return name.isNotEmpty || father.isNotEmpty || phone.isNotEmpty;
    }).toList();

    if (validRowsToSave.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No student records to save. Please fill at least one row.')),
      );
      return;
    }

    if (!_validateAllRows()) return;

    final duplicateWarnings = await _checkForDuplicates();
    if (duplicateWarnings.isNotEmpty && mounted) {
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text('Duplicate Warning'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Possible duplicate students detected (${duplicateWarnings.length}):',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...duplicateWarnings.map((w) => Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Text('• $w', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                    )),
                const SizedBox(height: 12),
                const Text('Do you want to proceed and save these students anyway?'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Review Rows'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
              child: const Text('Proceed & Save All'),
            ),
          ],
        ),
      );

      if (shouldProceed != true) return;
    }

    setState(() {
      _isSaving = true;
      _savedCount = 0;
      _totalToSave = validRowsToSave.length;
      _statusText = 'Preparing student ID generation...';
    });

    final existingStudents = DatabaseService.getAllStudentsLocal();
    final Map<String, int> levelOffsets = {};

    final List<StudentModel> studentsToSave = [];
    final Map<String, String> studentQrTokens = {};
    final List<BulkRowData> failedRows = [];
    final List<BulkRowData> successfulRows = [];

    for (int i = 0; i < validRowsToSave.length; i++) {
      final r = validRowsToSave[i];
      final levelCode = StudentModel.getClassLevelCode(r.classType, r.grade);
      final offset = levelOffsets[levelCode] ?? 0;
      final studentCode = StudentModel.generateStudentCode(
        classType: r.classType,
        grade: r.grade,
        existingStudents: existingStudents,
        offset: offset,
      );
      levelOffsets[levelCode] = offset + 1;
      final studentId = '${DateTime.now().millisecondsSinceEpoch}_$i';

      // Generate a distinct, cryptographically unique QR token for this student
      final qrToken = StudentAuthService.generateQrToken();
      studentQrTokens[studentId] = qrToken;

      try {
        final totalFee = double.tryParse(r.totalFeeC.text.trim()) ?? 0;
        final paidFee = double.tryParse(r.paidFeeC.text.trim()) ?? 0;
        final remFee = (totalFee - paidFee) < 0 ? 0.0 : (totalFee - paidFee);

        final numSubjects = r.selectedSubjectSchedules.keys.length;
        final divisor = numSubjects > 0 ? numSubjects : 1;
        final feePerSubject = totalFee / divisor;
        final paidPerSubject = paidFee / divisor;

        final student = StudentModel(
          id: studentId,
          studentCode: studentCode,
          firstName: r.nameC.text.trim(),
          fatherName: r.fatherC.text.trim(),
          lastName: '',
          phone: r.phoneC.text.trim(),
          email: r.emailC.text.trim(),
          schedule: r.selectedSubjectSchedules.entries.map((e) => '${e.key}: ${e.value}').join(', '),
          classType: r.classType,
          grade: r.grade,
          subject: r.selectedSubjectSchedules.keys.join(', '),
          feeSubmitted: paidFee,
          feeRemaining: remFee,
          biologyFee: r.selectedSubjectSchedules.containsKey('Biology') ? feePerSubject : 0,
          physicsFee: r.selectedSubjectSchedules.containsKey('Physics') ? feePerSubject : 0,
          chemistryFee: r.selectedSubjectSchedules.containsKey('Chemistry') ? feePerSubject : 0,
          englishFee: r.selectedSubjectSchedules.containsKey('English') ? feePerSubject : 0,
          mathFee: r.selectedSubjectSchedules.containsKey('Math') ? feePerSubject : 0,
          profilePicUrl: '',
          subjectPaymentsJson: jsonEncode({
            for (var sub in r.selectedSubjectSchedules.keys)
              sub: paidPerSubject,
          }),
          subjectSchedulesJson: jsonEncode(r.selectedSubjectSchedules),
          paymentHistoryJson: paidFee > 0
              ? jsonEncode([
                  {
                    'date': DateTime.now().toIso8601String(),
                    'amount': paidFee,
                    'note': 'Bulk Registration Payment',
                  }
                ])
              : null,
        );

        studentsToSave.add(student);
        successfulRows.add(r);
      } catch (saveErr) {
        debugPrint('Bulk row prepare error for index $i: $saveErr');
        r.hasError = true;
        r.errorMessage = 'Save failed: $saveErr';
        failedRows.add(r);
      }
    }

    if (studentsToSave.isNotEmpty) {
      setState(() {
        _statusText = 'Enrolling students and provisioning unique QR codes...';
      });

      // Single atomic batch save to Hive + background Cloud batch (<10ms!)
      await DatabaseService.addStudentsBulk(studentsToSave);
      SoundService.playSuccess();

      // Atomically batch create unique student_auth records in Firestore
      try {
        await StudentAuthService.createStudentAuthRecordsBulk(
          students: studentsToSave,
          pregeneratedTokens: studentQrTokens,
        );
      } catch (authErr) {
        debugPrint('[BulkRegistration] Error batch saving auth records: $authErr');
      }

      for (final student in studentsToSave) {
        NotificationService.createStudentRegistrationNotification(student: student);
      }
    }

    if (mounted) {
      setState(() {
        _isSaving = false;
        for (final succ in successfulRows) {
          _rows.remove(succ);
          succ.dispose();
        }
        if (_rows.isEmpty) {
          _addRow();
        }
      });

      if (failedRows.isEmpty) {
        showDialog(
          context: context,
          builder: (ctx) => CelebrationOverlay(
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: const [
                  Icon(Icons.check_circle_rounded, color: AppTheme.secondaryGreen, size: 32),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bulk Registration Complete',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Successfully registered ${successfulRows.length} student(s)!',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield_rounded, color: AppTheme.primaryBlue, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Each student has been assigned their own separate, unique QR Access Code for privacy and security. No two students have the same QR code.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showBulkQrPassesViewer(context, studentsToSave, studentQrTokens);
                  },
                  icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                  label: const Text('View All QR Passes'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryBlue,
                    side: const BorderSide(color: AppTheme.primaryBlue),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.white),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${successfulRows.length} student(s) registered successfully!',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: AppTheme.secondaryGreen,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${successfulRows.length} saved successfully. ${failedRows.length} failed.'),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
    }
  }

  void _showBulkQrPassesViewer(
    BuildContext context,
    List<StudentModel> students,
    Map<String, String> qrTokens,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setViewerState) {
            final filtered = students.where((s) {
              if (searchQuery.isEmpty) return true;
              final q = searchQuery.toLowerCase();
              return s.name.toLowerCase().contains(q) ||
                  s.studentCode.toLowerCase().contains(q);
            }).toList();

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800, maxHeight: 680),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.qr_code_2_rounded, color: AppTheme.primaryBlue, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bulk Registered QR Passes (${students.length})',
                                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Each student has an independent, scannable QR Access Code',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () {
                              Navigator.pop(dialogCtx);
                              Navigator.pop(context, true);
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        onChanged: (val) => setViewerState(() => searchQuery = val.trim()),
                        decoration: InputDecoration(
                          hintText: 'Search by student name or code...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(child: Text('No students match your search.'))
                            : GridView.builder(
                                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 360,
                                  mainAxisExtent: 220,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                                itemCount: filtered.length,
                                itemBuilder: (context, idx) {
                                  final s = filtered[idx];
                                  final token = qrTokens[s.id];
                                  return Card(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          StudentQrWidget(
                                            student: s,
                                            size: 100,
                                            showLabel: false,
                                            customQrData: token,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  s.name,
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    s.studentCode,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppTheme.primaryBlue,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${s.classType} • ${s.grade}',
                                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                ),
                                                const SizedBox(height: 10),
                                                OutlinedButton.icon(
                                                  onPressed: () {
                                                    showStudentQrDialog(context, s, customQrData: token);
                                                  },
                                                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                                                  label: const Text('Enlarge', style: TextStyle(fontSize: 11)),
                                                  style: OutlinedButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(dialogCtx);
                            Navigator.pop(context, true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── UI Builders ──────────────────────────────────────────────────────────

  Widget _buildRegistrationDefaultsBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_suggest_rounded, color: AppTheme.primaryBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Registration Defaults (Auto-applied to new rows)',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _applyDefaultsToAllRows,
                icon: const Icon(Icons.playlist_add_check_rounded, size: 16),
                label: const Text('Apply to All Rows'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 140,
                child: DropdownButtonFormField<String>(
                  value: _defaultClassType,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Default Class', isDense: true),
                  items: _classTypes.map((t) => DropdownMenuItem<String>(value: t, child: Text(t))).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _defaultClassType = v;
                        _defaultGrade = _gradeOptions[v]!.first;
                      });
                    }
                  },
                ),
              ),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('default_grade_$_defaultClassType'),
                  value: _defaultGrade,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Default Grade', isDense: true),
                  items: _gradeOptions[_defaultClassType]!
                      .map((g) => DropdownMenuItem<String>(value: g, child: Text(g, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _defaultGrade = v);
                  },
                ),
              ),
              SizedBox(
                width: 140,
                child: TextFormField(
                  initialValue: _defaultTotalFee,
                  decoration: const InputDecoration(labelText: 'Total Fee (Rs)', prefixText: 'Rs ', isDense: true),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _defaultTotalFee = v,
                ),
              ),
              SizedBox(
                width: 140,
                child: TextFormField(
                  initialValue: _defaultPaidFee,
                  decoration: const InputDecoration(labelText: 'Paid Fee (Rs)', prefixText: 'Rs ', isDense: true),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _defaultPaidFee = v,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.menu_book_rounded, color: Colors.grey, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Default Subjects: ${_defaultSubjectSchedules.keys.join(", ")} (${_defaultSubjectSchedules.values.toSet().join(", ")})',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _showDefaultSubjectSchedulesDialog,
                icon: const Icon(Icons.edit_note, size: 16),
                label: const Text('Change Default Subjects'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: () => _addRow(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('+ Add Row'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _pasteFromClipboard(),
              icon: const Icon(Icons.content_paste_rounded, size: 18),
              label: const Text('Paste Excel (Ctrl+V)'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _importCsvFile,
              icon: const Icon(Icons.file_upload_outlined, size: 18),
              label: const Text('Import CSV'),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: () => _validateAllRows(),
              icon: const Icon(Icons.fact_check_outlined, size: 18),
              label: const Text('Validate'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveAllStudents,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: Text('Save All Students (${_rows.length})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Scrollbar(
        controller: _horizontalScroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _horizontalScroll,
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1350),
            child: DataTable(
              columnSpacing: 16,
              headingRowHeight: 48,
              dataRowMinHeight: 56,
              dataRowMaxHeight: 64,
              headingRowColor: WidgetStateProperty.all(AppTheme.primaryBlue.withValues(alpha: 0.08)),
              columns: const [
                DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Student Name *', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Father Name *', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Phone *', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Class', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Grade', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Subjects', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Class Times', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Total Fee', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Paid Fee', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: List.generate(_rows.length, (index) {
                final r = _rows[index];
                final isError = r.hasError;

                return DataRow(
                  color: WidgetStateProperty.resolveWith((states) {
                    if (isError) return Colors.red.shade50;
                    if (index % 2 == 1) return Colors.grey.shade50;
                    return Colors.white;
                  }),
                  cells: [
                    // Index
                    DataCell(
                      Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isError ? Colors.red : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    // Name (Col 0)
                    DataCell(_buildCellTextField(
                      controller: r.nameC,
                      focusNode: r.nameFocus,
                      hint: 'Ali Khan',
                      rowIdx: index,
                      colIdx: 0,
                      isError: r.errorFields.contains('name'),
                    )),
                    // Father Name (Col 1)
                    DataCell(_buildCellTextField(
                      controller: r.fatherC,
                      focusNode: r.fatherFocus,
                      hint: 'Ahmad Khan',
                      rowIdx: index,
                      colIdx: 1,
                      isError: r.errorFields.contains('father'),
                    )),
                    // Phone (Col 2)
                    DataCell(_buildCellTextField(
                      controller: r.phoneC,
                      focusNode: r.phoneFocus,
                      hint: '03001234567',
                      rowIdx: index,
                      colIdx: 2,
                      keyboardType: TextInputType.phone,
                      isError: r.errorFields.contains('phone'),
                    )),
                    // Email (Col 3)
                    DataCell(_buildCellTextField(
                      controller: r.emailC,
                      focusNode: r.emailFocus,
                      hint: 'student@gmail.com',
                      rowIdx: index,
                      colIdx: 3,
                      keyboardType: TextInputType.emailAddress,
                      isError: r.errorFields.contains('email'),
                    )),
                    // Class Type (Col 4)
                    DataCell(
                      SizedBox(
                        width: 90,
                        child: Focus(
                          focusNode: r.classFocus,
                          onKeyEvent: (node, evt) {
                            if (evt is KeyDownEvent && (evt.logicalKey == LogicalKeyboardKey.enter || evt.logicalKey == LogicalKeyboardKey.numpadEnter)) {
                              _moveNextCell(index, 4);
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: DropdownButton<String>(
                            value: _classTypes.contains(r.classType) ? r.classType : _classTypes.first,
                            isExpanded: true,
                            underline: const SizedBox(),
                            isDense: true,
                            style: const TextStyle(fontSize: 13, color: Colors.black87),
                            items: _classTypes.map((t) => DropdownMenuItem<String>(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  r.classType = v;
                                  r.grade = _gradeOptions[v]!.first;
                                });
                                _moveNextCell(index, 4);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    // Grade (Col 5)
                    DataCell(
                      SizedBox(
                        width: 120,
                        child: Focus(
                          focusNode: r.gradeFocus,
                          onKeyEvent: (node, evt) {
                            if (evt is KeyDownEvent && (evt.logicalKey == LogicalKeyboardKey.enter || evt.logicalKey == LogicalKeyboardKey.numpadEnter)) {
                              _moveNextCell(index, 5);
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: DropdownButton<String>(
                            value: _gradeOptions[r.classType]!.contains(r.grade) ? r.grade : _gradeOptions[r.classType]!.first,
                            isExpanded: true,
                            underline: const SizedBox(),
                            isDense: true,
                            style: const TextStyle(fontSize: 13, color: Colors.black87),
                            items: _gradeOptions[r.classType]!
                                .map((g) => DropdownMenuItem<String>(
                                      value: g,
                                      child: Text(g, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => r.grade = v);
                                _moveNextCell(index, 5);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    // Subjects (Col 6)
                    DataCell(_buildCellTextField(
                      controller: r.subjectsC,
                      focusNode: r.subjectsFocus,
                      hint: 'Biology, Physics',
                      rowIdx: index,
                      colIdx: 6,
                      width: 170,
                      isError: r.errorFields.contains('subjects'),
                      suffix: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.edit_note, size: 20, color: AppTheme.primaryBlue),
                        onPressed: () => _showSubjectSchedulesDialog(r),
                      ),
                    )),
                    // Class Times (Col 7)
                    DataCell(_buildCellTextField(
                      controller: r.schedulesC,
                      focusNode: r.schedulesFocus,
                      hint: '7:00 AM, 9:00 AM',
                      rowIdx: index,
                      colIdx: 7,
                      width: 170,
                      isError: r.errorFields.contains('schedules'),
                    )),
                    // Total Fee (Col 8)
                    DataCell(_buildCellTextField(
                      controller: r.totalFeeC,
                      focusNode: r.totalFeeFocus,
                      hint: '4000',
                      rowIdx: index,
                      colIdx: 8,
                      keyboardType: TextInputType.number,
                      isError: r.errorFields.contains('totalFee'),
                    )),
                    // Paid Fee (Col 9)
                    DataCell(_buildCellTextField(
                      controller: r.paidFeeC,
                      focusNode: r.paidFeeFocus,
                      hint: '4000',
                      rowIdx: index,
                      colIdx: 9,
                      keyboardType: TextInputType.number,
                      isError: r.errorFields.contains('paidFee'),
                    )),
                    // Actions
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (index > 0)
                            IconButton(
                              icon: const Icon(Icons.content_copy_rounded, size: 18),
                              tooltip: 'Copy values from previous row',
                              onPressed: () => _copyPreviousRow(index),
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                            tooltip: 'Delete Row',
                            onPressed: () => _removeRow(index),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCellTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required int rowIdx,
    required int colIdx,
    TextInputType keyboardType = TextInputType.text,
    bool isError = false,
    Widget? suffix,
    double width = 140,
  }) {
    return SizedBox(
      width: width,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (evt) => _handleCellKeyEvent(event: evt, rowIdx: rowIdx, colIdx: colIdx),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textInputAction: TextInputAction.next,
          inputFormatters: keyboardType == TextInputType.number
              ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')), _StripLeadingZeroFormatter()]
              : null,
          onSubmitted: (_) => _moveNextCell(rowIdx, colIdx),
          style: TextStyle(
            fontSize: 13,
            color: isError ? Colors.red.shade900 : Colors.black87,
            fontWeight: isError ? FontWeight.bold : FontWeight.normal,
          ),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding: suffix != null
                ? const EdgeInsets.only(left: 10, right: 2, top: 8, bottom: 8)
                : const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            filled: isError,
            fillColor: isError ? Colors.red.shade100 : Colors.transparent,
            suffixIcon: suffix,
            suffixIconConstraints: suffix != null
                ? const BoxConstraints(maxHeight: 30, maxWidth: 30)
                : null,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: isError ? Colors.red : AppTheme.primaryBlue, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: isError ? Colors.red.shade400 : Colors.grey.shade300,
                width: isError ? 1.5 : 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyV, control: true): () => _pasteFromClipboard(),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () => _saveAllStudents(),
      },
      child: Focus(
        autofocus: true,
        focusNode: _keyboardFocusNode,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRegistrationDefaultsBar(),
                  _buildToolbar(),
                  const SizedBox(height: 12),
                  Text(
                    'Tip: Press Enter or Tab to move to the next field. Pressing Enter on the last column moves to the next row (and auto-creates a new row).',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 12),
                  _buildTable(),
                  const SizedBox(height: 24),
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () => _addRow(),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('Add Another Blank Row'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
            if (_isSaving)
              Container(
                color: Colors.black.withValues(alpha: 0.4),
                child: Center(
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    margin: const EdgeInsets.all(24),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SpinKitThreeBounce(color: AppTheme.primaryBlue, size: 36),
                          const SizedBox(height: 20),
                          Text(
                            'Saving Students...',
                            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$_savedCount / $_totalToSave registered',
                            style: const TextStyle(fontSize: 14, color: AppTheme.primaryBlue, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _statusText,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: 200,
                            child: LinearProgressIndicator(
                              value: _totalToSave > 0 ? _savedCount / _totalToSave : 0,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StripLeadingZeroFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text;
    if (text.length > 1 && text.startsWith('0') && !text.startsWith('0.')) {
      text = text.replaceFirst(RegExp(r'^0+'), '');
      if (text.isEmpty) text = '0';
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    return newValue;
  }
}
