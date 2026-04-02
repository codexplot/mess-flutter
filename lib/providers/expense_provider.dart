import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../services/api_service.dart';

class ExpenseProvider extends ChangeNotifier {
  List<Expense> _expenses = [];
  bool _loading = false;
  String? _error;

  List<Expense> get expenses => _expenses;
  bool get loading => _loading;
  String? get error => _error;

  List<Expense> get pendingExpenses => _expenses.where((e) => e.isPending).toList();
  List<Expense> get approvedExpenses => _expenses.where((e) => e.isApproved).toList();

  Future<void> fetchExpenses({String? status}) async {
    _loading = true;
    notifyListeners();
    try {
      final path = status != null ? '/expenses?status=$status' : '/expenses';
      final res = await ApiService.get(path);
      if (res['success']) {
        _expenses = (res['data'] as List).map((e) => Expense.fromJson(e)).toList();
      } else {
        _error = res['message'];
      }
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<bool> submitExpense({
    required double amount,
    required String shopName,
    required DateTime date,
    String? comments,
    File? billImage,
  }) async {
    try {
      final fields = {
        'amount': amount.toString(),
        'shopName': shopName,
        'date': date.toIso8601String(),
        if (comments != null && comments.isNotEmpty) 'comments': comments,
      };
      final res = await ApiService.postMultipart('/expenses', fields, billImage);
      if (res['success']) {
        await fetchExpenses();
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

  Future<bool> ownerAddExpense({
    required String memberId,
    required double amount,
    required String shopName,
    required DateTime date,
    String? comments,
  }) async {
    try {
      final res = await ApiService.post('/expenses/owner-add', {
        'memberId': memberId,
        'amount': amount,
        'shopName': shopName,
        'date': date.toIso8601String(),
        if (comments != null) 'comments': comments,
      });
      if (res['success']) {
        await fetchExpenses();
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

  Future<bool> updateStatus(String expenseId, String status, {String? rejectionNote}) async {
    try {
      final body = <String, dynamic>{'status': status};
      if (rejectionNote != null) body['rejectionNote'] = rejectionNote;
      final res = await ApiService.put('/expenses/$expenseId/status', body);
      if (res['success']) {
        await fetchExpenses();
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

  Future<bool> deleteExpense(String expenseId) async {
    try {
      final res = await ApiService.delete('/expenses/$expenseId');
      if (res['success']) {
        _expenses.removeWhere((e) => e.id == expenseId);
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

  void clear() {
    _expenses = [];
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
