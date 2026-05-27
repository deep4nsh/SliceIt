import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'offline_service.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  static late Connectivity _connectivity;
  static final List<Function(bool)> _listeners = [];

  factory ConnectivityService() {
    return _instance;
  }

  ConnectivityService._internal() {
    _connectivity = Connectivity();
  }

  Future<void> initialize() async {
    debugPrint('🔗 Initializing connectivity service...');

    // Check initial status
    final result = await _connectivity.checkConnectivity();
    final isOnline = result != ConnectivityResult.none;
    OfflineService.setOnlineStatus(isOnline);
    debugPrint('📡 Initial status: ${isOnline ? 'Online' : 'Offline'}');

    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen((result) {
      final wasOnline = OfflineService.getOnlineStatus();
      final isNowOnline = result != ConnectivityResult.none;

      if (wasOnline != isNowOnline) {
        debugPrint('🔄 Connectivity changed: ${isNowOnline ? 'Online' : 'Offline'}');
        OfflineService.setOnlineStatus(isNowOnline);

        if (isNowOnline) {
          debugPrint('✨ Device is online - syncing pending data...');
          _syncPendingData();
        }

        // Notify all listeners
        for (final listener in _listeners) {
          listener(isNowOnline);
        }
      }
    });

    debugPrint('✅ Connectivity service initialized');
  }

  static void addListener(Function(bool) onStatusChanged) {
    _listeners.add(onStatusChanged);
  }

  static void removeListener(Function(bool) onStatusChanged) {
    _listeners.remove(onStatusChanged);
  }

  static Future<void> _syncPendingData() async {
    try {
      await SyncManager.syncAllPendingData();
    } catch (e) {
      debugPrint('❌ Error syncing pending data: $e');
    }
  }

  static Future<bool> checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }
}
