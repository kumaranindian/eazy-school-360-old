import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:eazy_school_360/core/providers/auth_provider.dart';
import 'package:eazy_school_360/data/repositories/staff_management_repository.dart';
import 'package:eazy_school_360/data/services/bulk_staff_upload_service.dart';

class BulkStaffUploadScreen extends ConsumerStatefulWidget {
  const BulkStaffUploadScreen({super.key});

  @override
  ConsumerState<BulkStaffUploadScreen> createState() => _BulkStaffUploadScreenState();
}

class _BulkStaffUploadScreenState extends ConsumerState<BulkStaffUploadScreen> {
  // Dark theme colors
  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  PlatformFile? _selectedFile;
  List<Map<String, dynamic>>? _parsedData;
  bool _isLoading = false;
  bool _isUploading = false;
  String? _errorMessage;
  BulkUploadResult? _uploadResult;
  int _uploadProgress = 0;
  int _uploadTotal = 0;
  String? _currentUploadingStaff;
  int _selectedSampleCount = 50;

  late BulkStaffUploadService _uploadService;

  @override
  void initState() {
    super.initState();
    final staffRepo = ref.read(staffManagementRepositoryProvider);
    _uploadService = BulkStaffUploadService(staffRepo);
  }

  Future<void> _downloadTemplate() async {
    final excelBytes = _uploadService.generateExcelTemplate(sampleCount: _selectedSampleCount);
    
    if (kIsWeb) {
      // Web: trigger download
      final blob = html.Blob([excelBytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'staff_upload_template.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      // Mobile/Desktop: show snackbar with instructions
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Template download is only available on web. Please use web version.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _downloadCredentials() async {
    if (_uploadResult == null) return;
    
    final excelBytes = _uploadService.generateCredentialsExcel(_uploadResult!);
    
    if (kIsWeb) {
      // Web: trigger download
      final blob = html.Blob([excelBytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'staff_credentials.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      // Mobile/Desktop: show snackbar with instructions
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Credentials download is only available on web. Please use web version.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
          _parsedData = null;
          _errorMessage = null;
          _uploadResult = null;
        });
        await _parseFile();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking file: $e';
      });
    }
  }

  Future<void> _parseFile() async {
    if (_selectedFile == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _uploadService.parseFile(_selectedFile!);
      setState(() {
        _parsedData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadStaff() async {
    if (_parsedData == null || _parsedData!.isEmpty) return;

    final session = ref.read(currentSessionProvider);
    if (session?.schoolId == null) {
      setState(() {
        _errorMessage = 'School ID not found';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _uploadTotal = _parsedData!.length;
      _currentUploadingStaff = null;
      _errorMessage = null;
    });

    try {
      final result = await _uploadService.processBulkUpload(
        schoolId: session!.schoolId!,
        adminUserId: session.uid,
        staffDataList: _parsedData!,
        onProgress: (current, total, staffName) {
          setState(() {
            _uploadProgress = current;
            _uploadTotal = total;
            _currentUploadingStaff = staffName;
          });
        },
      );

      setState(() {
        _uploadResult = result;
        _isUploading = false;
        _currentUploadingStaff = null;
      });

      if (result.allSuccessful) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully uploaded ${result.successCount} staff members'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isUploading = false;
        _currentUploadingStaff = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        title: const Text('Bulk Staff Upload', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF161B22),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions Card
            _buildInstructionsCard(),
            const SizedBox(height: 24),

            // Download Template & Upload File
            Row(
              children: [
                Expanded(child: _buildDownloadTemplateCard()),
                const SizedBox(width: 16),
                Expanded(child: _buildUploadFileCard()),
              ],
            ),
            const SizedBox(height: 24),

            // Preview Data
            if (_parsedData != null && _parsedData!.isNotEmpty) ...[
              _buildPreviewCard(),
              const SizedBox(height: 24),
            ],

            // Upload Progress
            if (_isUploading) ...[
              _buildProgressCard(),
              const SizedBox(height: 24),
            ],

            // Error Message
            if (_errorMessage != null) ...[
              _buildErrorCard(),
              const SizedBox(height: 24),
            ],

            // Upload Result
            if (_uploadResult != null) ...[
              _buildResultCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    final progress = _uploadTotal > 0 ? (_uploadProgress / _uploadTotal) : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accentBlue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _accentBlue.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.cloud_upload_rounded, color: _accentBlue, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Uploading Staff', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: _borderColor,
            valueColor: const AlwaysStoppedAnimation<Color>(_accentBlue),
            minHeight: 8,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_uploadProgress of $_uploadTotal staff members',
                style: const TextStyle(color: _textSecondary, fontSize: 13),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: _accentBlue, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (_currentUploadingStaff != null) ...[
            const SizedBox(height: 8),
            Text(
              'Currently uploading: $_currentUploadingStaff',
              style: const TextStyle(color: _textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _accentBlue.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.info_outline, color: _accentBlue, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Instructions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '1. Download the Excel template using the button below\n'
            '2. Fill in staff details in the "Staff Data" sheet (red headers are mandatory)\n'
            '3. Use dropdown values for Staff Type column (TEACHING/NON_TEACHING)\n'
            '4. Upload the completed Excel file\n'
            '5. Review the preview and click "Upload Staff" to create accounts\n'
            '6. Each staff member will receive login credentials via email',
            style: TextStyle(color: _textSecondary, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadTemplateCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.download_rounded, color: Colors.green, size: 32),
          ),
          const SizedBox(height: 16),
          const Text('Step 1: Download Template', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 8),
          const Text('Get the Excel template with dropdowns and instructions', style: TextStyle(color: _textSecondary, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          // Sample count selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: _borderColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedSampleCount,
                dropdownColor: _cardDark,
                style: const TextStyle(color: _textPrimary),
                items: const [1, 5, 10, 20, 30, 40, 50].map((count) {
                  return DropdownMenuItem<int>(
                    value: count,
                    child: Text('$count sample records', style: const TextStyle(color: _textPrimary)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedSampleCount = value;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _downloadTemplate,
            icon: const Icon(Icons.download),
            label: const Text('Download Template'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadFileCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _selectedFile != null ? _accentBlue : _borderColor),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _accentBlue.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(
              _selectedFile != null ? Icons.check_circle : Icons.upload_file_rounded,
              color: _accentBlue,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text('Step 2: Upload Excel/CSV File', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 8),
          Text(
            _selectedFile != null ? 'Selected: ${_selectedFile!.name}' : 'Select your completed Excel or CSV file',
            style: const TextStyle(color: _textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _pickFile,
            icon: _isLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.folder_open),
            label: Text(_selectedFile != null ? 'Change File' : 'Select File'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.preview_rounded, color: Colors.orange, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text('Preview (${_parsedData!.length} staff members)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _uploadStaff,
                icon: _isUploading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_upload),
                label: const Text('Upload Staff'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: _borderColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(_bgDark),
                columns: const [
                  DataColumn(label: Text('Name', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Email', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Department', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Staff Type', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Designation', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold))),
                ],
                rows: _parsedData!.take(10).map((staff) => DataRow(
                  cells: [
                    DataCell(Text(staff['name']?.toString() ?? '', style: const TextStyle(color: _textSecondary))),
                    DataCell(Text(staff['email']?.toString() ?? '', style: const TextStyle(color: _textSecondary))),
                    DataCell(Text(staff['department']?.toString() ?? '', style: const TextStyle(color: _textSecondary))),
                    DataCell(Text(staff['staffType']?.toString().split('.').last ?? '', style: const TextStyle(color: _textSecondary))),
                    DataCell(Text(staff['designation']?.toString() ?? '', style: const TextStyle(color: _textSecondary))),
                  ],
                )).toList(),
              ),
            ),
          ),
          if (_parsedData!.length > 10)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('... and ${_parsedData!.length - 10} more', style: const TextStyle(color: _textSecondary, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final result = _uploadResult!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: result.allSuccessful ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.allSuccessful ? Icons.check_circle : Icons.warning,
                color: result.allSuccessful ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 12),
              Text(
                'Upload Complete',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: result.allSuccessful ? Colors.green : Colors.orange),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildResultStat('Total', result.totalProcessed, _accentBlue),
              const SizedBox(width: 24),
              _buildResultStat('Created', result.successCount, Colors.green),
              const SizedBox(width: 24),
              _buildResultStat('Updated', result.updatedStaff.length, Colors.blue),
              const SizedBox(width: 24),
              _buildResultStat('Failed', result.failedCount, Colors.red),
            ],
          ),
          if (result.successfulUploads.isNotEmpty || result.updatedStaff.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Staff Credentials:', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: () => _downloadCredentials(),
                  icon: const Icon(Icons.download),
                  label: const Text('Download Credentials'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...result.successfulUploads.map((success) {
                      final parts = success.split('|');
                      final displayText = parts.length == 4 
                          ? '${parts[1]} (${parts[2]}) - Password: ${parts[3]}'
                          : success;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          displayText,
                          style: const TextStyle(color: Colors.green, fontSize: 12),
                        ),
                      );
                    }).toList(),
                    ...result.updatedStaff.map((updated) {
                      final parts = updated.split('|');
                      final displayText = parts.length == 4 
                          ? '${parts[1]} (${parts[2]}) - Password: ${parts[3]} (Updated)'
                          : updated;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          displayText,
                          style: const TextStyle(color: Colors.blue, fontSize: 12),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ],
          if (result.updatedStaff.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Updated Staff:', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: result.updatedStaff.map((updated) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      updated,
                      style: const TextStyle(color: Colors.blue, fontSize: 12),
                    ),
                  )).toList(),
                ),
              ),
            ),
          ],
          if (result.hasFailures) ...[
            const SizedBox(height: 16),
            const Text('Failed Uploads:', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...result.failedUploads.map((failure) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Row ${failure['row']?.toString() ?? ''}: ${failure['name']?.toString() ?? ''} - ${failure['error']?.toString() ?? ''}',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildResultStat(String label, int value, Color color) {
    return Column(
      children: [
        Text('$value', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(color: _textSecondary, fontSize: 12)),
      ],
    );
  }
}
