import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../services/api_services.dart';
import '../services/pdf_services.dart';

class LeaveScreen extends StatefulWidget {
  final String token;
  const LeaveScreen({super.key, required this.token});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  final ApiService _apiService = ApiService();

  // --- AUTOMOTIVE BRAND COLORS (DARK THEME FOR LEAVE) ---
  final Color _brandRed = const Color(0xFFD32F2F);
  final Color _darkAsphalt = const Color(0xFF1E1E1E); // Main Black
  final Color _silverMetal = const Color(0xFFF0F0F0); // Background
  final Color _chrome = const Color(0xFFE0E0E0);

  // --- STATE VARIABELS ---
  int _formMode = 0; // 0 = Cuti Harian, 1 = Izin Jam
  bool _isLoading = false;

  // Controllers
  final _reasonController = TextEditingController();
  final _delegationNameController = TextEditingController();
  final _contactAddressController = TextEditingController();
  final _contactPhoneController = TextEditingController();

  // Data Cuti
  String _selectedLeaveType = 'Cuti Tahunan';
  DateTime? _startDate;
  DateTime? _endDate;
  final List<String> _leaveTypes = ['Cuti Tahunan', 'Cuti Melahirkan', 'Cuti Khusus', 'Sakit'];

  // Data Izin Jam
  DateTime? _permitDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final bool _isBackToWork = false;

  File? _attachment;

  // --- FUNGSI REFRESH (RESET FORM) ---
  Future<void> _refreshForm() async {
    await Future.delayed(const Duration(milliseconds: 800));

    setState(() {
      _reasonController.clear();
      _delegationNameController.clear();
      _contactAddressController.clear();
      _contactPhoneController.clear();
      _startDate = null;
      _endDate = null;
      _permitDate = null;
      _startTime = null;
      _endTime = null;
      _attachment = null;
      _selectedLeaveType = 'Cuti Tahunan';
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Formulir telah di-reset")),
    );
  }

  Future<void> _pickDate(BuildContext context, {required Function(DateTime) onPicked}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: _darkAsphalt, onPrimary: Colors.white, onSurface: _darkAsphalt),
            textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: _brandRed)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => onPicked(picked));
  }

  Future<void> _pickTime(BuildContext context, {required Function(TimeOfDay) onPicked}) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: _darkAsphalt, onPrimary: Colors.white, onSurface: _darkAsphalt),
            timePickerTheme: TimePickerThemeData(
              dayPeriodTextColor: _brandRed,
              dialHandColor: _darkAsphalt,
              dialBackgroundColor: _silverMetal,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => onPicked(picked));
  }

  Future<void> _pickAttachment() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'jpeg', 'pdf'] // Allow image and pdf
    );

    if (result != null) {
      setState(() => _attachment = File(result.files.single.path!));
    }
  }

  // --- FUNGSI PRINT PDF ---
  Future<void> _printPdf() async {
    if (_formMode == 0) {
      if (_startDate == null || _endDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tanggal cuti wajib diisi")));
        return;
      }
    } else {
      // ... validasi hourly ...
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(child: CircularProgressIndicator(color: _darkAsphalt)),
    );

    try {
      final profileData = await _apiService.getProfile(widget.token);

      if (!mounted) return;
      Navigator.pop(context);

      if (profileData != null) {
        String apiName = profileData['name'] ?? "Tanpa Nama";
        String apiNik = profileData['nik'] ?? "-";

        // AMBIL SISA CUTI DARI API
        int apiSisaCuti = 12;
        if (profileData['leave_remaining'] != null) {
          apiSisaCuti = int.parse(profileData['leave_remaining'].toString());
        }

        String apiDivisi = "-";
        if (profileData['position'] != null) {
          apiDivisi = profileData['position']['name'];
        } else {
          apiDivisi = profileData['role'] ?? "-";
        }

        final pdfService = PdfService();

        if (_formMode == 0) {
          await pdfService.createCutiPdf(
            apiName,
            apiNik,
            apiDivisi,
            _selectedLeaveType,
            _startDate!,
            _endDate!,
            _reasonController.text,
            _delegationNameController.text,
            _contactAddressController.text,
            _contactPhoneController.text,
            apiSisaCuti, 
          );
        } else {
          // ... (createHourlyPdf code) ...
        }

      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal mengambil data profil.")));
      }
    } catch (e) {
      // ... error handling ...
    }
  }

  // --- SUBMIT KE API ---
  Future<void> _submitForm() async {
    // 1. Validasi Input Dasar
    if (_formMode == 0) {
      if (_startDate == null || _endDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tanggal cuti mulai dan selesai wajib diisi!"), backgroundColor: Colors.orange));
        return;
      }
    } else {
      if (_permitDate == null || _startTime == null || _endTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tanggal dan Jam Izin wajib diisi!"), backgroundColor: Colors.orange));
        return;
      }
    }

    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Alasan/Keperluan wajib diisi!"), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isLoading = true);

    try {
      Map<String, String> payload = {};

      if (_formMode == 0) {
        // Mode Cuti Harian
        payload = {
          'type': 'Cuti',
          'jenis_cuti': _selectedLeaveType,
          'start_date': DateFormat('yyyy-MM-dd').format(_startDate!),
          'end_date': DateFormat('yyyy-MM-dd').format(_endDate!),
          'reason': _reasonController.text,
          // Mengirim data JSON string untuk contact darurat (sesuaikan dengan API Backend Anda)
          'emergency_name': _delegationNameController.text,
          'emergency_address': _contactAddressController.text,
          'emergency_phone': _contactPhoneController.text,
        };
      } else {
        // Mode Izin Jam
        payload = {
          'type': 'Izin',
          'jenis_cuti': "Izin Jam",
          'start_date': DateFormat('yyyy-MM-dd').format(_permitDate!),
          'start_time': '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}',
          'end_time': '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}',
          'reason': _reasonController.text,
        };
      }

      // 2. Kirim POST melalui ApiService
      var response = await _apiService.postLeaveRequest(widget.token, payload, _attachment);

      if (!mounted) return;

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message'] ?? "Pengajuan berhasil dikirim."), backgroundColor: Colors.green)
        );
        // Refresh/Kosongkan Form setelah berhasil
        _refreshForm();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message'] ?? "Gagal mengirim pengajuan."), backgroundColor: Colors.red)
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _silverMetal,
      appBar: AppBar(
        title: const Text("PENGAJUAN", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 18)),
        backgroundColor: _darkAsphalt,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background Decoration (Dark Theme)
          Positioned(
            top: -20, right: -20,
            child: Opacity(
              opacity: 0.05,
              child: Icon(Icons.assignment_outlined, size: 250, color: Colors.black),
            ),
          ),
          
          // Carbon Fiber Stripe Decoration
          Positioned(
            bottom: 0, left: 0, right: 0,
            height: 10,
            child: Container(
              color: _brandRed,
            ),
          ),

          RefreshIndicator(
            color: _darkAsphalt,
            backgroundColor: Colors.white,
            onRefresh: _refreshForm,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 25, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTypeSelector(),
                  const SizedBox(height: 30),

                  // FORM CONTENT
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _formMode == 0 ? _buildCutiForm() : _buildHourlyForm(),
                  ),

                  const SizedBox(height: 25),
                  _buildReasonAndAttachment(),

                  const SizedBox(height: 40),

                  // TOMBOL AKSI
                  Column(
                    children: [
                      // TOMBOL PRINT
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _darkAsphalt,
                            elevation: 2,
                            side: BorderSide(color: _darkAsphalt.withOpacity(0.3), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _printPdf,
                          icon: Icon(Icons.print_outlined, color: _darkAsphalt, size: 24),
                          label: Text("CETAK / PREVIEW PDF", style: TextStyle(color: _darkAsphalt, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // TOMBOL KIRIM
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 6))],
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _darkAsphalt,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _isLoading ? null : _submitForm,
                            icon: _isLoading
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.send_rounded),
                            label: const Text("KIRIM PENGAJUAN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(children: [Expanded(child: _toggleButton("CUTI HARIAN", 0)), Expanded(child: _toggleButton("IZIN JAM KERJA", 1))]),
    );
  }

  Widget _toggleButton(String title, int index) {
    bool isSelected = _formMode == index;
    return GestureDetector(
      onTap: () => setState(() => _formMode = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? _darkAsphalt : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[600],
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.5
          ),
        ),
      ),
    );
  }

  // --- FORM SECTIONS ---

  Widget _buildCutiForm() {
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("DETAIL CUTI"),
        _buildShadowedInput(
          child: DropdownButtonFormField<String>(
            value: _selectedLeaveType,
            decoration: _cleanInputDecoration("Jenis Cuti", Icons.category_outlined),
            items: _leaveTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (val) => setState(() => _selectedLeaveType = val!),
          ),
        ),
        const SizedBox(height: 15),
        Row(children: [
          Expanded(child: _dateField("Mulai Cuti", _startDate, () => _pickDate(context, onPicked: (d) => setState(() => _startDate = d)))),
          const SizedBox(width: 15),
          Expanded(child: _dateField("Selesai Cuti", _endDate, () => _pickDate(context, onPicked: (d) => setState(() => _endDate = d)))),
        ]),

        const SizedBox(height: 30),
        _sectionHeader("KONTAK DARURAT"),
        _buildShadowedInput(
          child: TextField(controller: _delegationNameController, decoration: _cleanInputDecoration("Nama Pengganti/Kontak", Icons.person_outline)),
        ),
        const SizedBox(height: 15),
        _buildShadowedInput(
          child: TextField(controller: _contactAddressController, decoration: _cleanInputDecoration("Alamat Selama Cuti", Icons.home_outlined)),
        ),
        const SizedBox(height: 15),
        _buildShadowedInput(
          child: TextField(controller: _contactPhoneController, keyboardType: TextInputType.phone, decoration: _cleanInputDecoration("No. Telp / HP", Icons.phone_android)),
        ),
      ],
    );
  }

  Widget _buildHourlyForm() {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("DETAIL IZIN"),
        _buildShadowedInput(
          child: _dateField("Tanggal Izin", _permitDate, () => _pickDate(context, onPicked: (d) => setState(() => _permitDate = d)), fullWidth: true, wrapped: false),
        ),
        const SizedBox(height: 15),
        Row(children: [
          Expanded(child: _timeField("Jam Keluar", _startTime, () => _pickTime(context, onPicked: (t) => setState(() => _startTime = t)))),
          const SizedBox(width: 15),
          Expanded(child: _timeField("Jam Kembali", _endTime, () => _pickTime(context, onPicked: (t) => setState(() => _endTime = t)))),
        ]),
      ],
    );
  }

  Widget _buildReasonAndAttachment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Pekerjaan Yang Ditinggalkan"),
        _buildShadowedInput(
          child: TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: _cleanInputDecoration("Pekerjaan Lanjutan", Icons.notes)
          ),
        ),
        const SizedBox(height: 15),

        // --- TOMBOL PILIH FILE ---
        GestureDetector(
          onTap: _pickAttachment,
          child: _buildShadowedInput(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: _brandRed.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.attach_file, color: _brandRed),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Bukti Lampiran (Opsional)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          _attachment != null ? _attachment!.path.split('/').last : "Ketuk untuk memilih file (JPG/PDF)",
                          style: TextStyle(color: _attachment != null ? Colors.green[700] : Colors.grey[500], fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (_attachment != null)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red, size: 20),
                      onPressed: () => setState(() => _attachment = null),
                    )
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- HELPERS ---

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        children: [
          Container(width: 4, height: 16, decoration: BoxDecoration(color: _brandRed, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: _darkAsphalt, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.2)),
        ],
      ),
    );
  }

  Widget _buildShadowedInput({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }

  InputDecoration _cleanInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
      prefixIcon: Icon(icon, color: _darkAsphalt.withOpacity(0.7), size: 22),
      border: InputBorder.none,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _brandRed, width: 1.5)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
    );
  }

  Widget _dateField(String label, DateTime? date, VoidCallback onTap, {bool fullWidth = false, bool wrapped = true}) {
    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(children: [
        Icon(Icons.calendar_today_rounded, size: 22, color: _darkAsphalt.withOpacity(0.7)),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(date != null ? DateFormat('dd MMM yy').format(date) : "-", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _darkAsphalt))
          ],
        ))
      ]),
    );

    return GestureDetector(onTap: onTap, child: wrapped ? _buildShadowedInput(child: content) : content);
  }

  Widget _timeField(String label, TimeOfDay? time, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: _buildShadowedInput(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(children: [
            Icon(Icons.access_time_rounded, size: 22, color: Colors.orange.withOpacity(0.8)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(time != null ? time.format(context) : "--:--", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _darkAsphalt))
              ],
            ))
          ]),
        ),
      ),
    );
  }
}