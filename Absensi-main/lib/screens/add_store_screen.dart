import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_services.dart';

class AddStoreScreen extends StatefulWidget {
  final String token;
  const AddStoreScreen({super.key, required this.token});

  @override
  State<AddStoreScreen> createState() => _AddStoreScreenState();
}

class _AddStoreScreenState extends State<AddStoreScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  // --- AUTOMOTIVE THEME COLORS ---
  final Color _brandRed = const Color(0xFFE50000);
  final Color _brandBlue = const Color(0xFF0044CC);
  final Color _brandBlack = const Color(0xFF212121);
  final Color _darkAsphalt = const Color(0xFF1E1E1E);
  final Color _silverMetal = const Color(0xFFF5F5F5);

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _stockController = TextEditingController();
  final _radiusController = TextEditingController(text: "100");
  final _ownerNameController = TextEditingController();
  final _ownerPhoneController = TextEditingController();

  double? _latitude;
  double? _longitude;
  bool _isFetchingLocation = false;
  bool _isSubmitting = false;

  List<dynamic> _areas = [];
  List<dynamic> _provinces = [];
  List<dynamic> _regencies = [];
  List<dynamic> _districts = [];

  Map<String, dynamic>? _selectedArea;
  Map<String, dynamic>? _selectedProvince;
  Map<String, dynamic>? _selectedRegency;
  Map<String, dynamic>? _selectedDistrict;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _getLocation();
  }

  Future<void> _fetchInitialData() async {
    try {
      var areas = await _apiService.getAreas(widget.token);
      var provs = await _apiService.getProvinces(widget.token);
      setState(() {
        _areas = areas;
        _provinces = provs;
      });
    } catch (e) {
      _showSnack("Gagal mengambil data wilayah: $e", Colors.red);
    }
  }

  Future<void> _fetchRegencies(String provId) async {
    setState(() {
      _regencies = [];
      _districts = [];
      _selectedRegency = null;
      _selectedDistrict = null;
    });
    try {
      var regencies = await _apiService.getRegencies(widget.token, provId);
      setState(() => _regencies = regencies);
    } catch (e) {
      _showSnack("Gagal mengambil data Kabupaten", Colors.red);
    }
  }

  Future<void> _fetchDistricts(String regencyId) async {
    setState(() {
      _districts = [];
      _selectedDistrict = null;
    });
    try {
      var dists = await _apiService.getDistricts(widget.token, regencyId);
      setState(() => _districts = dists);
    } catch (e) {
      _showSnack("Gagal mengambil data Kecamatan", Colors.red);
    }
  }

  Future<void> _getLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('GPS tidak aktif');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Izin ditolak');
      }
      if (permission == LocationPermission.deniedForever) throw Exception('Izin ditolak permanen');

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      _showSnack("Gagal mendapat lokasi: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) {
      _showSnack("Mohon lengkapi semua data wajib", Colors.orange);
      return;
    }
    if (_latitude == null || _longitude == null) {
      _showSnack("Lokasi GPS belum ditemukan. Tekan tombol refresh lokasi.", Colors.orange);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      Map<String, dynamic> payload = {
        "name": _nameController.text,
        "owner_name": _ownerNameController.text,
        "phone": _ownerPhoneController.text,
        "code_area": _selectedArea?['code_area'],
        "stock": int.tryParse(_stockController.text) ?? 0,
        "address": _addressController.text,
        "provinsi": _selectedProvince?['name'],
        "kabupaten": _selectedRegency?['name'],
        "kecamatan": _selectedDistrict?['name'],
        "lat": _latitude,
        "long": _longitude,
        "radius": int.tryParse(_radiusController.text) ?? 100,
      };

      bool isSuccess = await _apiService.postNewStore(widget.token, payload);

      if (isSuccess) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Toko baru berhasil ditambahkan!"), backgroundColor: Colors.green));
        Navigator.pop(context);
      } else {
        _showSnack("Gagal menambahkan toko.", Colors.red);
      }
    } catch (e) {
      _showSnack("Error: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _silverMetal,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_brandRed, _brandBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text("TAMBAH TOKO BARU", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
        leading: const BackButton(color: Colors.white),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Background Decoration
          Positioned(
            top: 0, right: 0,
            child: Opacity(opacity: 0.05, child: Icon(Icons.store_mall_directory_rounded, size: 200, color: _brandBlack)),
          ),
          
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100), // Extra padding bottom for button
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SECTION 1: DATA TOKO ---
                  _buildSectionHeader("INFORMASI TOKO", Icons.storefront_rounded),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildTextField("Nama Toko", _nameController, Icons.business_rounded),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildDropdown(
                                  "Code Area", _areas, _selectedArea,
                                  (val) => setState(() => _selectedArea = val),
                                  (item) => "${item['code_area']} (${item['name']})",
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: _buildTextField("Stok Awal", _stockController, Icons.inventory_2_rounded, isNumber: true),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 25),

                  // --- SECTION 2: PEMILIK ---
                  _buildSectionHeader("DATA PEMILIK", Icons.person_pin_rounded),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildTextField("Nama Pemilik (Owner)", _ownerNameController, Icons.person_rounded),
                          const SizedBox(height: 16),
                          _buildTextField("No. Telepon / HP", _ownerPhoneController, Icons.phone_android_rounded, isNumber: true),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // --- SECTION 3: LOKASI ---
                  _buildSectionHeader("LOKASI & WILAYAH", Icons.map_rounded),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildDropdown("Provinsi", _provinces, _selectedProvince, (val) {
                            setState(() => _selectedProvince = val);
                            if (val != null) _fetchRegencies(val['code'].toString());
                          }, (item) => item['name']),
                          const SizedBox(height: 16),
                          _buildDropdown("Kabupaten / Kota", _regencies, _selectedRegency, (val) {
                            setState(() => _selectedRegency = val);
                            if (val != null) _fetchDistricts(val['code'].toString());
                          }, (item) => item['name']),
                          const SizedBox(height: 16),
                          _buildDropdown("Kecamatan", _districts, _selectedDistrict, (val) => setState(() => _selectedDistrict = val), (item) => item['name']),
                          const SizedBox(height: 16),
                          _buildTextField("Alamat Lengkap", _addressController, Icons.location_on_outlined, maxLines: 3),
                          
                          const Divider(height: 30),
                          
                          // GPS SECTION
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _brandBlue.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _brandBlue.withOpacity(0.2))
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                  child: _isFetchingLocation 
                                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _brandBlue))
                                    : Icon(Icons.my_location_rounded, color: _brandBlue),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Titik Koordinat (GPS)", style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Text(
                                        _latitude != null ? "$_latitude, $_longitude" : "Belum terdeteksi", 
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _darkAsphalt)
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh_rounded), 
                                  color: _brandRed,
                                  tooltip: "Refresh Lokasi",
                                  onPressed: _isFetchingLocation ? null : _getLocation,
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _brandRed,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 4,
          ),
          onPressed: _isSubmitting ? null : _submitData,
          child: _isSubmitting
              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text("SIMPAN DATA TOKO", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _brandRed),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: _brandBlack, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isNumber = false, int maxLines = 1}) {
    return TextFormField(
      controller: controller, 
      keyboardType: isNumber ? TextInputType.number : TextInputType.text, 
      maxLines: maxLines,
      style: TextStyle(color: _brandBlack, fontWeight: FontWeight.w600),
      validator: (value) => value == null || value.isEmpty ? "$label wajib diisi" : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
        prefixIcon: maxLines == 1 ? Icon(icon, color: Colors.grey[400], size: 22) : null,
        filled: true, 
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _brandRed, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.red.shade200)),
      ),
    );
  }

  Widget _buildDropdown(String label, List<dynamic> items, Map<String, dynamic>? selectedValue, Function(Map<String, dynamic>?) onChanged, String Function(Map<String, dynamic>) getLabel) {
    return DropdownButtonFormField<Map<String, dynamic>>(
      value: selectedValue, 
      validator: (value) => value == null ? "Pilih $label" : null, 
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
        filled: true, 
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _brandRed, width: 1.5)),
      ),
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      items: items.map((item) => DropdownMenuItem<Map<String, dynamic>>(value: item, child: Text(getLabel(item), style: TextStyle(fontSize: 14, color: _brandBlack), overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
    );
  }
}
