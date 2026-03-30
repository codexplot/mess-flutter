import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _loading = false;
  String? _error;

  User? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  Future<void> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;
    _loading = true;
    notifyListeners();
    try {
      final res = await ApiService.get('/auth/me');
      if (res['success']) {
        _user = User.fromJson(res['data']);
      } else {
        await prefs.remove('token');
      }
    } catch (_) {
      await prefs.remove('token');
    }
    _loading = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiService.post(
        '/auth/login',
        {'email': email, 'password': password},
        auth: false,
      );
      if (res['success']) {
        final data = res['data'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        _user = User.fromJson(data['user']);
        _loading = false;
        notifyListeners();
        return true;
      } else {
        _error = res['message'];
        _loading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String name, String email, String password, {String? roomCode}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final body = <String, dynamic>{
        'name': name,
        'email': email,
        'password': password,
      };
      if (roomCode != null && roomCode.isNotEmpty) body['roomCode'] = roomCode;

      final res = await ApiService.post('/auth/register', body, auth: false);
      if (res['success']) {
        final data = res['data'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        _user = User.fromJson(data['user']);
        _loading = false;
        notifyListeners();
        return true;
      } else {
        _error = res['message'];
        _loading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    _user = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
