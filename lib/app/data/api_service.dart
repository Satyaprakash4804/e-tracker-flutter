import 'dart:convert';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // ── Read token from storage ──
  static String _token() => GetStorage().read("token") ?? "";

  // ── Auth header ──
  static Map<String, String> _headers() => {
        "Content-Type": "application/json",
        "Authorization": "Bearer ${_token()}",
      };

  // =========================
  // POST (JSON)
  // =========================
  static Future<dynamic> post(String url, Map data) async {
    try {
      final res = await http.post(
        Uri.parse(url),
        headers: _headers(),          // ✅ sends token
        body: jsonEncode(data),
      );

      if (res.statusCode != 200 && res.statusCode != 201) {
        print("❌ API POST ERROR ${res.statusCode}: ${res.body}");
        // ✅ Still return the parsed body so caller can read "message"
        try { return jsonDecode(res.body); } catch (_) { return null; }
      }

      return jsonDecode(res.body);
    } catch (e) {
      print("❌ POST ERROR: $e");
      return null;
    }
  }

  // =========================
  // GET
  // =========================
  static Future<dynamic> get(String url) async {
    try {
      final res = await http.get(
        Uri.parse(url),
        headers: _headers(),          // ✅ sends token
      );

      if (res.statusCode != 200) {
        print("❌ API GET ERROR ${res.statusCode}: ${res.body}");
        try { return jsonDecode(res.body); } catch (_) { return null; }
      }

      return jsonDecode(res.body);
    } catch (e) {
      print("❌ GET ERROR: $e");
      return null;
    }
  }

  // =========================
  // DELETE
  // =========================
  static Future<dynamic> delete(String url) async {
    try {
      final res = await http.delete(
        Uri.parse(url),
        headers: _headers(),          // ✅ sends token
      );

      if (res.statusCode != 200) {
        print("❌ API DELETE ERROR ${res.statusCode}: ${res.body}");
        try { return jsonDecode(res.body); } catch (_) { return null; }
      }

      return jsonDecode(res.body);
    } catch (e) {
      print("❌ DELETE ERROR: $e");
      return null;
    }
  }

  // =========================
  // MULTIPART UPLOAD
  // =========================
  static Future<Map<String, dynamic>?> multipart(
    String url, {
    required Map<String, String> fields,
    required String fileKey,
    required String filePath,
  }) async {
    try {
      final request = http.MultipartRequest("POST", Uri.parse(url));

      // ✅ Auth header on multipart too
      request.headers["Authorization"] = "Bearer ${_token()}";

      request.fields.addAll(fields);
      request.files.add(
        await http.MultipartFile.fromPath(fileKey, filePath),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        print("❌ MULTIPART ERROR ${response.statusCode}: $responseBody");
        return null;
      }

      return jsonDecode(responseBody);
    } catch (e) {
      print("❌ MULTIPART EXCEPTION: $e");
      return null;
    }
  }
}