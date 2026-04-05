import 'package:flutter/foundation.dart';
import '../models/room.dart';
import '../services/api_service.dart';

class RoomProvider extends ChangeNotifier {
  Room? _room;
  Map<String, dynamic>? _summary;
  bool _loading = false;
  String? _error;
  String _currencySymbol = '₹';

  Room? get room => _room;
  Map<String, dynamic>? get summary => _summary;
  bool get loading => _loading;
  String? get error => _error;
  String get currencySymbol => _currencySymbol;

  Future<void> fetchRoom() async {
    _loading = true;
    notifyListeners();
    try {
      final res = await ApiService.get('/rooms/my-room');
      if (res['success']) {
        _room = Room.fromJson(res['data']);
        _currencySymbol = _room!.currencySymbol;
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

  Future<bool> updateMonthlyBills(
    double rent,
    double food,
    double electricity,
    double water,
    String billingMonth, {
    String currencyCode = 'INR',
    String currencySymbol = '₹',
    String currencyName = 'Indian Rupee',
  }) async {
    try {
      final res = await ApiService.put('/rooms/monthly-bills', {
        'rent': rent,
        'food': food,
        'electricity': electricity,
        'water': water,
        'billingMonth': billingMonth,
        'currency': {
          'code': currencyCode,
          'symbol': currencySymbol,
          'name': currencyName,
        },
      });
      if (res['success']) {
        _currencySymbol = currencySymbol;
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

  Future<bool> updateRoomDetails(String address, String location) async {
    try {
      final res = await ApiService.put('/rooms/room-details', {'address': address, 'location': location});
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

  Future<bool> partialPay(String memberId, double amount) async {
    try {
      final res = await ApiService.put('/rooms/members/$memberId/partial-pay', {'amount': amount});
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

  Future<bool> clearPartialPay(String memberId) async {
    try {
      final res = await ApiService.delete('/rooms/members/$memberId/partial-pay');
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

  Future<void> fetchSummary({String? month}) async {
    _loading = true;
    notifyListeners();
    try {
      final path = month != null ? '/rooms/summary?month=$month' : '/rooms/summary';
      final res = await ApiService.get(path);
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

  Future<List<String>> fetchSummaryMonths() async {
    try {
      final res = await ApiService.get('/rooms/summary-months');
      if (res['success']) {
        return List<String>.from(res['data']['months'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> fetchMemberSummary({String? month}) async {
    try {
      final path = month != null ? '/rooms/my-summary?month=$month' : '/rooms/my-summary';
      final res = await ApiService.get(path);
      if (res['success']) {
        final data = res['data'] as Map<String, dynamic>;
        // Cache currency symbol from summary
        final roomData = data['room'] as Map<String, dynamic>?;
        final currency = roomData?['currency'] as Map<String, dynamic>?;
        if (currency != null && currency['symbol'] != null) {
          _currencySymbol = currency['symbol'] as String;
          notifyListeners();
        }
        return data;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> fetchCarryForwardHistory() async {
    try {
      final res = await ApiService.get('/rooms/carry-forward');
      if (res['success'] == true) {
        return res['data'] as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<List<String>> fetchAvailableMonths() async {
    try {
      final res = await ApiService.get('/rooms/available-months');
      if (res['success']) {
        return List<String>.from(res['data']['months'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  void clear() {
    _room = null;
    _summary = null;
    _error = null;
    _currencySymbol = '₹';
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
