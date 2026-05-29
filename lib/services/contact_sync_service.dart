import 'package:flutter_contacts/flutter_contacts.dart' hide PermissionStatus;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class ContactSyncService {
  static Future<PermissionStatus> _requestContactPermission() async {
    return await Permission.contacts.request();
  }

  static Future<List<Contact>> getPhoneContacts() async {
    final status = await _requestContactPermission();

    if (status.isDenied) {
      throw Exception('Contact permission denied');
    }

    if (status.isPermanentlyDenied) {
      openAppSettings();
      throw Exception('Contact permission permanently denied. Please enable in app settings.');
    }

    try {
      final contacts = await FlutterContacts.getAll(
        properties: {ContactProperty.name, ContactProperty.email},
      );
      return contacts;
    } catch (e) {
      debugPrint('Error fetching contacts: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, String>>> getContactEmails() async {
    try {
      final contacts = await getPhoneContacts();
      final emails = <Map<String, String>>[];

      for (var contact in contacts) {
        final name = contact.displayName ?? '';

        if (contact.emails.isNotEmpty) {
          for (var email in contact.emails) {
            final emailValue = email.address;
            if (emailValue.isNotEmpty) {
              emails.add({
                'name': name.isEmpty ? 'Unknown' : name,
                'email': emailValue,
              });
            }
          }
        }
      }

      return emails;
    } catch (e) {
      debugPrint('Error extracting contact emails: $e');
      rethrow;
    }
  }

  static Future<bool> hasContactPermission() async {
    final status = await Permission.contacts.status;
    return status.isGranted;
  }
}
