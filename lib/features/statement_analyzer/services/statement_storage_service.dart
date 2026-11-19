import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/statement_transaction.dart';
import '../models/monthly_statement_summary.dart';

class StatementStorageService {
  static const String _transactionsKey = 'gpay_statement_transactions';
  static const String _importedFilesKey = 'gpay_imported_files';

  List<StatementTransaction> _cachedTransactions = [];
  bool _isLoaded = false;

  static final StatementStorageService _instance = StatementStorageService._internal();
  factory StatementStorageService() => _instance;
  StatementStorageService._internal();

  List<StatementTransaction> get allTransactions => List.unmodifiable(_cachedTransactions);

  Future<void> init() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_transactionsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        _cachedTransactions = decoded.map((item) => StatementTransaction.fromJson(item)).toList();
      }
      _isLoaded = true;
    } catch (e) {
      debugPrint('Error loading statement transactions: $e');
      _cachedTransactions = [];
    }
  }

  Set<String> getExistingUpiIds() {
    return _cachedTransactions.map((t) => t.upiId).where((id) => id.isNotEmpty).toSet();
  }

  List<String> getAvailableMonths() {
    final monthsSet = <String>{};
    for (var tx in _cachedTransactions) {
      monthsSet.add(tx.monthKey);
    }
    final list = monthsSet.toList();
    // Sort chronological descending
    list.sort((a, b) {
      final dtA = _parseMonthKey(a);
      final dtB = _parseMonthKey(b);
      return dtB.compareTo(dtA);
    });
    return list;
  }

  DateTime _parseMonthKey(String key) {
    try {
      final parts = key.split(' ');
      if (parts.length == 2) {
        final mStr = parts[0];
        final yStr = parts[1];
        const months = {
          'january': 1, 'february': 2, 'march': 3, 'april': 4,
          'may': 5, 'june': 6, 'july': 7, 'august': 8,
          'september': 9, 'october': 10, 'november': 11, 'december': 12,
        };
        final m = months[mStr.toLowerCase()] ?? 1;
        final y = int.tryParse(yStr) ?? 2026;
        return DateTime(y, m);
      }
    } catch (_) {}
    return DateTime.now();
  }

  MonthlyStatementSummary getMonthlySummary(String monthKey) {
    final filtered = _cachedTransactions.where((t) => t.monthKey == monthKey).toList();
    return MonthlyStatementSummary.fromTransactions(monthKey, filtered);
  }

  Future<int> addTransactions(List<StatementTransaction> newTxList) async {
    await init();
    final existingUpi = getExistingUpiIds();
    int addedCount = 0;

    for (var tx in newTxList) {
      if (tx.upiId.isNotEmpty && existingUpi.contains(tx.upiId)) {
        // Skip duplicate
        continue;
      }
      _cachedTransactions.add(tx);
      existingUpi.add(tx.upiId);
      addedCount++;
    }

    _cachedTransactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    await _saveToDisk();
    return addedCount;
  }

  Future<void> updateTransaction(StatementTransaction updated) async {
    await init();
    final idx = _cachedTransactions.indexWhere((t) => t.id == updated.id);
    if (idx != -1) {
      _cachedTransactions[idx] = updated;
      await _saveToDisk();
    }
  }

  Future<void> deleteTransaction(String id) async {
    await init();
    _cachedTransactions.removeWhere((t) => t.id == id);
    await _saveToDisk();
  }

  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _cachedTransactions.map((t) => t.toJson()).toList();
      await prefs.setString(_transactionsKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving statement transactions: $e');
    }
  }

  Future<void> clearAll() async {
    _cachedTransactions.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_transactionsKey);
    await prefs.remove(_importedFilesKey);
  }
}
