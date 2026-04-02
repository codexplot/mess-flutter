import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // iOS simulator uses localhost, Android emulator uses 10.0.2.2, physical device uses Mac's LAN IP
  static const String _iosSimBase = 'http://localhost:5001/api';
  static const String _androidBase = 'http://10.0.2.2:5001/api';
  static const String _physicalDeviceBase = 'http://192.168.1.138:5001/api';

  static String get baseUrl {
    if (Platform.isAndroid) return _androidBase;
    // On iOS, check if running on simulator or physical device
    return _physicalDeviceBase;
  }

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (auth) {
      final token = await _getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static const _timeout = Duration(seconds: 10);

  static Future<Map<String, dynamic>> get(String path) async {
    final res = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
    ).timeout(_timeout);
    return _parse(res);
  }

  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body, {bool auth = true}) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    ).timeout(_timeout);
    return _parse(res);
  }

  static Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    ).timeout(_timeout);
    return _parse(res);
  }

  static Future<Map<String, dynamic>> delete(String path) async {
    final res = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
    ).timeout(_timeout);
    return _parse(res);
  }

  static Future<Map<String, dynamic>> postMultipart(
    String path,
    Map<String, String> fields,
    File? imageFile,
  ) async {
    final token = await _getToken();
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.fields.addAll(fields);
    if (imageFile != null) {
      request.files.add(await http.MultipartFile.fromPath('billImage', imageFile.path));
    }
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _parse(res);
  }

  static Map<String, dynamic> _parse(http.Response res) {
    final body = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return {'success': true, 'data': body};
    }
    return {
      'success': false,
      'message': body['message'] ?? 'Something went wrong',
    };
  }
}
