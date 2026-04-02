import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import 'room_provider.dart';
import 'expense_provider.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  User? _pendingUser;
  bool _loading = false;
  String? _error;

  User? get user => _user;
  User? get pendingUser => _pendingUser;
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

  // Two-phase login: validate credentials but hold navigation until animation completes
  Future<bool> loginPending(String email, String password) async {
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
        _pendingUser = User.fromJson(data['user']);
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

  void completeLogin() {
    _user = _pendingUser;
    _pendingUser = null;
    notifyListeners();
  }

  Future<bool> login(String email, String password, {RoomProvider? roomProvider, ExpenseProvider? expenseProvider}) async {
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
        roomProvider?.clear();
        expenseProvider?.clear();
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

  Future<bool> register(String name, String email, String password, {String? roomCode, RoomProvider? roomProvider, ExpenseProvider? expenseProvider}) async {
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
        roomProvider?.clear();
        expenseProvider?.clear();
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

  Future<String?> updateProfile({String? name, String? email, String? phone, String? address}) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (email != null) body['email'] = email;
      if (phone != null) body['phone'] = phone;
      if (address != null) body['address'] = address;
      final res = await ApiService.put('/auth/profile', body);
      if (res['success']) {
        _user = User.fromJson(res['data']['user']);
        notifyListeners();
        return null;
      }
      return res['message'] ?? 'Update failed';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> changePassword(String currentPassword, String newPassword) async {
    try {
      final res = await ApiService.put('/auth/change-password', {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
      if (res['success']) return null;
      return res['message'] ?? 'Failed to change password';
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> logout({RoomProvider? roomProvider, ExpenseProvider? expenseProvider}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    roomProvider?.clear();
    expenseProvider?.clear();
    _user = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
