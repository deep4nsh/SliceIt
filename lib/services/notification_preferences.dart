import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences extends ChangeNotifier {
  static const String _pushNotificationsKey = 'push_notifications_enabled';
  static const String _settlementRemindersKey = 'settlement_reminders_enabled';
  static const String _groupInvitesKey = 'group_invites_enabled';
  static const String _expenseUpdatesKey = 'expense_updates_enabled';
  static const String _paymentRemindersKey = 'payment_reminders_enabled';
  static const String _isLoadedKey = 'preferences_loaded';

  bool _pushNotificationsEnabled = true;
  bool _settlementRemindersEnabled = true;
  bool _groupInvitesEnabled = true;
  bool _expenseUpdatesEnabled = true;
  bool _paymentRemindersEnabled = true;
  bool _isLoaded = false;

  NotificationPreferences() {
    _loadPreferences();
  }

  bool get pushNotificationsEnabled => _pushNotificationsEnabled;
  bool get settlementRemindersEnabled => _settlementRemindersEnabled;
  bool get groupInvitesEnabled => _groupInvitesEnabled;
  bool get expenseUpdatesEnabled => _expenseUpdatesEnabled;
  bool get paymentRemindersEnabled => _paymentRemindersEnabled;
  bool get isLoaded => _isLoaded;

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _pushNotificationsEnabled = prefs.getBool(_pushNotificationsKey) ?? true;
      _settlementRemindersEnabled = prefs.getBool(_settlementRemindersKey) ?? true;
      _groupInvitesEnabled = prefs.getBool(_groupInvitesKey) ?? true;
      _expenseUpdatesEnabled = prefs.getBool(_expenseUpdatesKey) ?? true;
      _paymentRemindersEnabled = prefs.getBool(_paymentRemindersKey) ?? true;
    } catch (e) {
      debugPrint('Error loading notification preferences: $e');
      _initializeDefaults();
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  void _initializeDefaults() {
    _pushNotificationsEnabled = true;
    _settlementRemindersEnabled = true;
    _groupInvitesEnabled = true;
    _expenseUpdatesEnabled = true;
    _paymentRemindersEnabled = true;
  }

  Future<void> setPushNotifications(bool enabled) async {
    if (_pushNotificationsEnabled == enabled) return;
    _pushNotificationsEnabled = enabled;
    notifyListeners();
    await _saveSetting(_pushNotificationsKey, enabled);
  }

  Future<void> setSettlementReminders(bool enabled) async {
    if (_settlementRemindersEnabled == enabled) return;
    _settlementRemindersEnabled = enabled;
    notifyListeners();
    await _saveSetting(_settlementRemindersKey, enabled);
  }

  Future<void> setGroupInvites(bool enabled) async {
    if (_groupInvitesEnabled == enabled) return;
    _groupInvitesEnabled = enabled;
    notifyListeners();
    await _saveSetting(_groupInvitesKey, enabled);
  }

  Future<void> setExpenseUpdates(bool enabled) async {
    if (_expenseUpdatesEnabled == enabled) return;
    _expenseUpdatesEnabled = enabled;
    notifyListeners();
    await _saveSetting(_expenseUpdatesKey, enabled);
  }

  Future<void> setPaymentReminders(bool enabled) async {
    if (_paymentRemindersEnabled == enabled) return;
    _paymentRemindersEnabled = enabled;
    notifyListeners();
    await _saveSetting(_paymentRemindersKey, enabled);
  }

  Future<void> _saveSetting(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      debugPrint('Error saving notification preference: $e');
    }
  }

  bool shouldShowNotification(String notificationType) {
    if (!_pushNotificationsEnabled) return false;

    switch (notificationType) {
      case 'settlement_reminder':
        return _settlementRemindersEnabled;
      case 'group_invite':
        return _groupInvitesEnabled;
      case 'expense_update':
        return _expenseUpdatesEnabled;
      case 'payment_reminder':
        return _paymentRemindersEnabled;
      default:
        return true;
    }
  }
}
