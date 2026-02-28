import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../models/user_model.dart';

class ApiService {
  final String baseUrl = "https://sumberbaru.evognito.my.id/api";

  // ... imports

  // ... kode lainnya ...

  // Tambahkan parameter String imei
  // ... kode lainnya ...

  // 1. Tambahkan parameter String onesignalId
  Future<LoginResponse> login(String nik, String password, String imei, String onesignalId) async {
    try {
      var uri = Uri.parse("$baseUrl/login");
      var request = http.MultipartRequest('POST', uri);

      request.headers['Accept'] = 'application/json';

      request.fields['nik'] = nik;
      request.fields['password'] = password;
      request.fields['imei'] = imei;
      // 2. Kirim OneSignal ID ke API
      request.fields['onesignal_id'] = onesignalId;

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print("Login Payload - IMEI: $imei, OneSignal: $onesignalId"); // Debugging
      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        return LoginResponse.fromJson(json);
      } else {
        // Default pesan jika parsing gagal
        String msg = "Error Server: ${response.statusCode}";

        try {
          // Coba decode body untuk mengambil pesan error dari API
          var json = jsonDecode(response.body);
          if (json['message'] != null) {
            msg = json['message'];
          }
        } catch (e) {
          // Jika response bukan JSON (misal error 500 HTML), biarkan default msg
          print("Gagal parse error message: $e");
        }

        return LoginResponse(
            success: false,
            message: msg
        );
      }
    } catch (e) {
      return LoginResponse(success: false, message: "Error: $e");
    }
  }

  Future<bool> changePassword(String token, String current, String newPass, String confirm) async {
    try {
      var uri = Uri.parse("$baseUrl/change-password");
      var request = http.MultipartRequest('POST', uri);

      // Header Wajib
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.fields['current_password'] = current;
      request.fields['new_password'] = newPass;
      request.fields['new_password_confirmation'] = confirm;

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return true;
      } else {
        print("Gagal Ganti Password: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error: $e");
      return false;
    }
  }

  // Ubah return type jadi Map agar bisa bawa pesan
  Future<Map<String, dynamic>> postAttendance(String token, double lat, double long, File photo) async {
    try {
      var uri = Uri.parse("$baseUrl/attendance"); // Pastikan endpoint benar (attendance/attendances)
      var request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.fields['latitude'] = lat.toString();
      request.fields['longitude'] = long.toString();

      // Langsung kirim path (lebih stabil daripada cek exists dulu di beberapa android)
      var pic = await http.MultipartFile.fromPath("photo", photo.path);
      request.files.add(pic);

      print("Mengirim Absen: Lat: $lat, Long: $long");

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print("Status Absen: ${response.statusCode}");
      print("Body Absen: ${response.body}");

      // Ambil body response
      var json = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          "success": true,
          "message": json['message'] ?? "Absen Berhasil" // Ambil pesan dari API
        };
      } else {
        return {
          "success": false,
          "message": json['message'] ?? "Gagal Absen (Error ${response.statusCode})"
        };
      }
    } catch (e) {
      print("Error Absen: $e");
      return {
        "success": false,
        "message": "Terjadi kesalahan koneksi: $e"
      };
    }
  }
  Future<List<dynamic>> getHistory(String token) async {
    try {
      var uri = Uri.parse("$baseUrl/attendance/history");
      var response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        return json['data'];
      }
      return [];
    } catch (e) {
      print("Error History: $e");
      return [];
    }
  }
  Future<Map<String, dynamic>?> getProfile(String token) async {
    try {
      var uri = Uri.parse("$baseUrl/profile");
      var response = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        return json['data'];
      }
      return null;
    } catch (e) {
      print("Error Profile: $e");
      return null;
    }
  }
  // Tambahkan ini di dalam class ApiService
  Future<bool> updateProfile(String token, String field, String value) async {
    try {
      var uri = Uri.parse("$baseUrl/profile"); // Sesuaikan endpoint API Anda
      var request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      // Kirim field yang diedit (misal: 'email' atau 'phone')
      request.fields[field] = value;

      // Jika backend butuh method PUT/PATCH, sesuaikan.
      // Biasanya POST untuk update profil juga bisa tergantung backend.

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      print("Error Update: $e");
      return false;
    }
  }
  Future<List<dynamic>> getLeaveHistory(String token) async {
    try {
      var uri = Uri.parse("$baseUrl/leaves");
      var response = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        return json['data'];
      }
      return [];
    } catch (e) {
      print("Error Leave History: $e");
      return [];
    }
  }

  // --- Fungsi Tambahan di ApiService ---
  Future<Map<String, dynamic>> postLeaveRequest(
      String token,
      Map<String, String> data,
      File? attachment
      ) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/leaves'));

      // Tambahkan Headers
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      // Masukkan field teks (Cuti / Izin Jam)
      request.fields.addAll(data);

      // Masukkan File Attachment jika ada
      if (attachment != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'attachment',
          attachment.path,
        ));
      }
      print(data);
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        // Handle error dari server (misal validasi gagal)
        var errorData = json.decode(response.body);
        return {'success': false, 'message': errorData['message'] ?? 'Gagal mengirim pengajuan.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }
  // ... kode lainnya ...

  Future<List<dynamic>> getVisitsByDate(String token, String date) async {
    // Sesuaikan endpoint API Anda, misalnya: /api/schedules
    final url = Uri.parse('$baseUrl/schedules?date=$date');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        // Mengembalikan list yang ada di dalam key "data"
        return jsonResponse['data'] ?? [];
      } else {
        final jsonResponse = json.decode(response.body);
        return jsonResponse['meta'] ?? [];
      }
    } catch (e) {
      print("Error fetching visits: $e");
      throw e; // Lempar error agar bisa ditangkap di UI
    }
  }
  // --- Fungsi Tambahan untuk Tambah Toko ---

  // 1. Ambil Area Code
  Future<List<dynamic>> getAreas(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/areas'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (response.statusCode == 200) {
      return json.decode(response.body)['data'] ?? [];
    }
    throw Exception('Failed to load areas');
  }

  // 2. Ambil Provinsi
  Future<List<dynamic>> getProvinces(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/wilayah/provinces'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (response.statusCode == 200) {
      // Sesuaikan key json.decode dengan struktur JSON API Anda (misal: 'data' atau langsung list)
      var data = json.decode(response.body);
      return data['data'] != null ? data['data'] : data;
    }
    throw Exception('Failed to load provinces');
  }

  // 3. Ambil Kabupaten berdasarkan Kode Provinsi
  Future<List<dynamic>> getRegencies(String token, String provCode) async {
    final response = await http.get(
      Uri.parse('$baseUrl/wilayah/regencies/$provCode'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      return data['data'] != null ? data['data'] : data;
    }
    throw Exception('Failed to load regencies');
  }

  // 4. Ambil Kecamatan berdasarkan Kode Kabupaten
  Future<List<dynamic>> getDistricts(String token, String regencyCode) async {
    final response = await http.get(
      Uri.parse('$baseUrl/wilayah/districts/$regencyCode'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      return data['data'] != null ? data['data'] : data;
    }
    throw Exception('Failed to load districts');
  }

  // 5. POST Simpan Data Toko Baru
  Future<bool> postNewStore(String token, Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/customers'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: json.encode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        var resData = json.decode(response.body);
        return resData['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ... di dalam class ApiService ...

  // 1. CLOCK IN KUNJUNGAN
  Future<Map<String, dynamic>> clockInVisit(
      String token, String visitId, String lat, String lng, File photo) async {
    try {
      var uri = Uri.parse("$baseUrl/visit-attendance"); // Sesuaikan endpoint
      var request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.fields['schedule_id'] = visitId;
      request.fields['latitude'] = lat;
      request.fields['longitude'] = lng;

      // Upload Foto
      var pic = await http.MultipartFile.fromPath("photo", photo.path);
      request.files.add(pic);

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      return jsonDecode(response.body);
    } catch (e) {
      return {"success": false, "message": "Error Clock In: $e"};
    }
  }

  // 2. CLOCK OUT KUNJUNGAN
  Future<Map<String, dynamic>> clockOutVisit(
      String token, String visitId, String lat, String lng, File photo, String visitNotes) async {
    try {
      var uri = Uri.parse("$baseUrl/visit-attendance"); // Sesuaikan endpoint
      var request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.fields['schedule_id'] = visitId;
      request.fields['latitude'] = lat;
      request.fields['longitude'] = lng;
      request.fields['visit_notes'] = visitNotes; // Hasil kunjungan (misal: "Order 50 karton")

      // Upload Foto
      var pic = await http.MultipartFile.fromPath("photo", photo.path);
      request.files.add(pic);

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      return jsonDecode(response.body);
    } catch (e) {
      return {"success": false, "message": "Error Clock Out: $e"};
    }
  }
}