import 'package:flutter/foundation.dart';
import '../models/room.dart';
import '../services/api_service.dart';

class RoomProvider extends ChangeNotifier {
  Room? _room;
  Map<String, dynamic>? _summary;
  bool _loading = false;
  String? _error;

  Room? get room => _room;
  Map<String, dynamic>? get summary => _summary;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> fetchRoom() async {
    _loading = true;
    notifyListeners();
    try {
      final res = await ApiService.get('/rooms/my-room');
      if (res['success']) {
        _room = Room.fromJson(res['data']);
      } else {
        _error = res['message'];
      }
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<bool> createRoom(String name) async {
    try {
      final res = await ApiService.post('/rooms', {'name': name});
      if (res['success']) {
        _room = Room.fromJson(res['data']['room']);
        notifyListeners();
        return true;
      }
      _error = res['message'];
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateMonthlyBills(double rent, double food, double electricity, double water, String billingMonth) async {
    try {
      final res = await ApiService.put('/rooms/monthly-bills', {
        'rent': rent,
        'food': food,
        'electricity': electricity,
        'water': water,
        'billingMonth': billingMonth,
      });
      if (res['success']) {
        await fetchRoom();
        return true;
      }
      _error = res['message'];
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> addMember(String email) async {
    try {
      final res = await ApiService.post('/rooms/add-member', {'email': email});
      if (res['success']) {
        await fetchRoom();
        await fetchSummary();
        return true;
      }
      _error = res['message'];
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeMember(String memberId) async {
    try {
      final res = await ApiService.delete('/rooms/remove-member/$memberId');
      if (res['success']) {
        await fetchRoom();
        await fetchSummary();
        return true;
      }
      _error = res['message'];
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> togglePaid(String memberId) async {
    try {
      final res = await ApiService.put('/rooms/members/$memberId/toggle-paid', {});
      if (res['success']) {
        await fetchRoom();
        await fetchSummary();
        return true;
      }
      _error = res['message'];
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleFood(String memberId) async {
    try {
      final res = await ApiService.put('/rooms/members/$memberId/toggle-food', {});
      if (res['success']) {
        await fetchRoom();
        await fetchSummary();
        return true;
      }
      _error = res['message'];
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchSummary() async {
    _loading = true;
    notifyListeners();
    try {
      final res = await ApiService.get('/rooms/summary');
      if (res['success']) {
        _summary = res['data'];
      } else {
        _error = res['message'];
      }
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> fetchMemberSummary() async {
    try {
      final res = await ApiService.get('/rooms/my-summary');
      if (res['success']) return res['data'];
    } catch (_) {}
    return null;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
