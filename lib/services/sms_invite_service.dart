import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';

class SMSInviteService {
  static Future<void> sendSMSInvite({
    required String phoneNumber,
    required String inviteLink,
    required String senderName,
  }) async {
    try {
      final message = 'Hey! Join me on SliceIt to split bills easily. $inviteLink';
      final smsUri = Uri(
        scheme: 'sms',
        path: phoneNumber,
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        debugPrint('Could not launch SMS');
        throw Exception('SMS not supported on this device');
      }
    } catch (e) {
      debugPrint('Error sending SMS invite: $e');
      rethrow;
    }
  }

  static String formatPhoneNumber(String phone) {
    // Remove all non-digit characters
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');

    // If 10 digits, assume US format
    if (digitsOnly.length == 10) {
      return '+1$digitsOnly';
    }

    // If already has country code or is international
    if (digitsOnly.length >= 11) {
      return '+$digitsOnly';
    }

    // Return as-is if unclear
    return phone;
  }
}
