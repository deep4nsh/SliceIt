import 'dart:io';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Android: uses a platform channel to get a definitive result from UPI apps.
/// Other platforms: falls back to opening the deep link (no result callback).
class UpiPaymentService {
  static const _channel = MethodChannel('com.sliceit/upi');

  Future<String> pay({
    required String upiId,
    required double amount,
    String payeeName = 'SliceIt User',
    String note = 'Split settlement',
  }) async {
    if (Platform.isAndroid) {
      try {
        final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
          'startUpiPayment',
          {
            'upiId': upiId,
            'amount': amount,
            'payeeName': payeeName,
            'note': note,
          },
        );
        final status = (result?['status'] as String?) ?? 'unknown';
        return status;
      } on PlatformException catch (_) {
        // Fall back to deep link
      }
    }

    // Fallback: open UPI URI without a result callback
    final uri = Uri.parse(
      'upi://pay?pa=${Uri.encodeComponent(upiId)}&pn=${Uri.encodeComponent(payeeName)}&am=${amount.toStringAsFixed(2)}&cu=INR&tn=${Uri.encodeComponent(note)}',
    );
    if (await canLaunchUrl(uri)) {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      return ok ? 'submitted' : 'failure';
    }
    return 'failure';
  }
}
