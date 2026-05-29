import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

class OfflineService {
  static late Box<Map<dynamic, dynamic>> _pendingExpensesBox;
  static late Box<Map<dynamic, dynamic>> _pendingSplitBillsBox;
  static late Box<String> _syncStatusBox;
  static late Box<bool> _isOnlineBox;

  static bool _initialized = false;
  static bool _isOnline = true;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Hive.initFlutter();

      _pendingExpensesBox = await Hive.openBox<Map>('pending_expenses');
      _pendingSplitBillsBox = await Hive.openBox<Map>('pending_split_bills');
      _syncStatusBox = await Hive.openBox<String>('sync_status');
      _isOnlineBox = await Hive.openBox<bool>('is_online');

      _initialized = true;
      debugPrint('✅ Offline service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing offline service: $e');
    }
  }

  static Future<void> savePendingExpense(Map<String, dynamic> expense) async {
    if (!_initialized) await initialize();

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      await _pendingExpensesBox.put(timestamp, Map<dynamic, dynamic>.from(expense));
      await _syncStatusBox.put('expense_$timestamp', 'pending');
      debugPrint('💾 Saved pending expense offline: $timestamp');
    } catch (e) {
      debugPrint('❌ Error saving pending expense: $e');
    }
  }

  static Future<void> savePendingSplitBill(Map<String, dynamic> bill) async {
    if (!_initialized) await initialize();

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      await _pendingSplitBillsBox.put(timestamp, Map<dynamic, dynamic>.from(bill));
      await _syncStatusBox.put('bill_$timestamp', 'pending');
      debugPrint('💾 Saved pending split bill offline: $timestamp');
    } catch (e) {
      debugPrint('❌ Error saving pending split bill: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getPendingExpenses() async {
    if (!_initialized) await initialize();

    try {
      final pending = <Map<String, dynamic>>[];
      for (var entry in _pendingExpensesBox.toMap().entries) {
        final status = _syncStatusBox.get('expense_${entry.key}');
        if (status == 'pending') {
          pending.add(Map<String, dynamic>.from(entry.value));
        }
      }
      return pending;
    } catch (e) {
      debugPrint('❌ Error getting pending expenses: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getPendingSplitBills() async {
    if (!_initialized) await initialize();

    try {
      final pending = <Map<String, dynamic>>[];
      for (var entry in _pendingSplitBillsBox.toMap().entries) {
        final status = _syncStatusBox.get('bill_${entry.key}');
        if (status == 'pending') {
          pending.add(Map<String, dynamic>.from(entry.value));
        }
      }
      return pending;
    } catch (e) {
      debugPrint('❌ Error getting pending split bills: $e');
      return [];
    }
  }

  static Future<void> markExpenseSynced(String timestamp) async {
    if (!_initialized) await initialize();

    try {
      await _syncStatusBox.put('expense_$timestamp', 'synced');
      await _pendingExpensesBox.delete(timestamp);
      debugPrint('✅ Marked expense as synced: $timestamp');
    } catch (e) {
      debugPrint('❌ Error marking expense synced: $e');
    }
  }

  static Future<void> markSplitBillSynced(String timestamp) async {
    if (!_initialized) await initialize();

    try {
      await _syncStatusBox.put('bill_$timestamp', 'synced');
      await _pendingSplitBillsBox.delete(timestamp);
      debugPrint('✅ Marked split bill as synced: $timestamp');
    } catch (e) {
      debugPrint('❌ Error marking split bill synced: $e');
    }
  }

  static Future<int> getPendingCount() async {
    if (!_initialized) await initialize();

    try {
      int count = 0;
      for (var key in _syncStatusBox.keys) {
        if (_syncStatusBox.get(key) == 'pending') {
          count++;
        }
      }
      return count;
    } catch (e) {
      return 0;
    }
  }

  static void setOnlineStatus(bool isOnline) {
    _isOnline = isOnline;
    try {
      if (_initialized) {
        _isOnlineBox.put('status', isOnline);
      }
    } catch (e) {
      debugPrint('Error setting online status: $e');
    }
  }

  static bool getOnlineStatus() => _isOnline;

  static Future<void> clearAllPending() async {
    if (!_initialized) await initialize();

    try {
      await _pendingExpensesBox.clear();
      await _pendingSplitBillsBox.clear();
      await _syncStatusBox.clear();
      debugPrint('✅ Cleared all pending data');
    } catch (e) {
      debugPrint('❌ Error clearing pending data: $e');
    }
  }
}

class SyncManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> syncAllPendingData() async {
    debugPrint('🔄 Starting sync of pending data...');

    try {
      final pendingExpenses = await OfflineService.getPendingExpenses();
      final pendingSplitBills = await OfflineService.getPendingSplitBills();

      int syncedCount = 0;

      // Sync split bills first
      for (var bill in pendingSplitBills) {
        try {
          final timestamp = bill['_timestamp'] as String?;
          await _firestore.collection('split_bills').add(bill);
          if (timestamp != null) {
            await OfflineService.markSplitBillSynced(timestamp);
          }
          syncedCount++;
          debugPrint('✅ Synced split bill');
        } catch (e) {
          debugPrint('❌ Failed to sync split bill: $e');
        }
      }

      // Sync expenses
      for (var expense in pendingExpenses) {
        try {
          final timestamp = expense['_timestamp'] as String?;
          final groupId = expense['groupId'] as String?;

          if (groupId != null) {
            await _firestore
                .collection('groups')
                .doc(groupId)
                .collection('expenses')
                .add(expense);

            if (timestamp != null) {
              await OfflineService.markExpenseSynced(timestamp);
            }
            syncedCount++;
            debugPrint('✅ Synced expense');
          }
        } catch (e) {
          debugPrint('❌ Failed to sync expense: $e');
        }
      }

      debugPrint('🎉 Sync complete! Synced $syncedCount items');
    } catch (e) {
      debugPrint('❌ Error during sync: $e');
    }
  }

  static Future<bool> isNetworkAvailable() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
