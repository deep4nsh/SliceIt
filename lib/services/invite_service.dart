import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class InviteService {
  InviteService._();

  static Future<void> sendGroupInvites({
    required String groupId,
    required String inviterUid,
    required String inviterName,
    required String groupName,
    required List<String> emails, required String subject, required String body,
  }) async {
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('sendGroupInvites');
      await callable.call({
        'to': emails,
        'groupId': groupId,
        'inviterUid': inviterUid,
        'inviterName': inviterName,
        'groupName': groupName,
      });
    } on FirebaseFunctionsException catch (e) {
      debugPrint('sendGroupInvites failed: ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('sendGroupInvites unexpected error: $e');
      rethrow;
    }
  }
}
