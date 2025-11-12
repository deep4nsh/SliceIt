import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sliceit/utils/deep_link_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sliceit/screens/group_detail_screen.dart';
import 'package:sliceit/utils/colors.dart';
import 'package:sliceit/services/invite_service.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Stream<QuerySnapshot> _getGroupsStream() {
    return _firestore
        .collection('groups')
        .where('members', arrayContains: _auth.currentUser!.uid)
        .snapshots();
  }

  Future<void> _launchEmailComposer(List<String> emails, {required String subject, required String body}) async {
    final uri = Uri(
      scheme: 'mailto',
      path: emails.join(','),
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await Share.share(body, subject: subject);
      }
    } catch (_) {
      await Share.share(body, subject: subject);
    }
  }

  Future<void> _createGroup() async {
    final groupNameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create Group'),
        content: TextField(
          controller: groupNameController,
          decoration: const InputDecoration(labelText: 'Group Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (groupNameController.text.isEmpty) return;
              await _firestore.collection('groups').add({
                'name': groupNameController.text,
                'createdBy': _auth.currentUser!.uid,
                'members': [_auth.currentUser!.uid],
              });
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareGroup(String groupId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Invite by Email'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Email addresses',
              hintText: 'Enter comma or newline separated emails',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final emails = _parseEmails(value ?? '');
              if (emails.isEmpty) return 'Enter at least one email';
              final invalid = emails.where((e) => !_isValidEmail(e)).toList();
              if (invalid.isNotEmpty) return 'Invalid: ${invalid.join(', ')}';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final emails = _parseEmails(controller.text);

              // Persist invites (optional tracking)
              final batch = _firestore.batch();
              for (final email in emails) {
                final doc = _firestore
                    .collection('groups')
                    .doc(groupId)
                    .collection('invites')
                    .doc(email);
                batch.set(doc, {
                  'email': email,
                  'inviterUid': currentUser.uid,
                  'sentAt': FieldValue.serverTimestamp(),
                  'status': 'pending',
                }, SetOptions(merge: true));
              }
              await batch.commit();

              // Send real emails via Cloud Function
              try {
                await InviteService.sendGroupInvites(
                  groupId: groupId,
                  inviterUid: currentUser.uid,
                  emails: emails,
                  subject: 'Join my SliceIt group',
                  body: _composeInviteBody(groupId, currentUser.uid), inviterName: '', groupName: '',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Invites sent to ${emails.length} recipient(s)')),
                  );
                }
              } catch (_) {
                // Fallback: open email composer/share
                await _launchEmailComposer(
                  emails,
                  subject: 'Join my SliceIt group',
                  body: _composeInviteBody(groupId, currentUser.uid),
                );
              }

              if (mounted) Navigator.pop(context);
            },
            child: const Text('Send Invites'),
          ),
        ],
      ),
    );
  }

  List<String> _parseEmails(String raw) {
    return raw
        .split(RegExp(r'[\n,; ]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(email);
  }

  String _composeInviteBody(String groupId, String inviterUid) {
    final httpLink = DeepLinkConfig.groupHttp(groupId, inviterUid);
    final schemeLink = DeepLinkConfig.groupScheme(groupId, inviterUid);
    return 'Hi,\n\nI\'d like you to join my SliceIt group.\n\nJoin link (opens app if installed):\n$httpLink\n\nIf the above does not open the app, tap this:\n$schemeLink\n\nThanks!';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Groups')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getGroupsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            debugPrint("Firestore Error in GroupsScreen: ${snapshot.error}");
            return const Center(child: Text('Error loading groups. Check logs for details.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No groups found. Create one!'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final groupName = data['name'] ?? 'Unnamed Group';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: doc.id)),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.person_add_alt),
                    tooltip: 'Invite by email',
                    onPressed: () => _shareGroup(doc.id),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createGroup,
        icon: const Icon(Icons.add),
        label: const Text('Create Group'),
        backgroundColor: AppColors.sageGreen,
      ),
    );
  }
}
