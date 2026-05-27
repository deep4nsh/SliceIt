import 'package:contacts_service/contacts_service.dart';
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
      final contacts = await ContactsService.getContacts(withThumbnails: false);
      return contacts.toList();
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
        final name = contact.displayName ?? 'Unknown';

        if (contact.emails?.isNotEmpty == true) {
          for (var email in contact.emails ?? []) {
            final emailValue = email.value ?? '';
            if (emailValue.isNotEmpty) {
              emails.add({
                'name': name,
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
