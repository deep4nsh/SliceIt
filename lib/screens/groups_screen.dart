import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sliceit/screens/group_detail_screen.dart';
import 'package:sliceit/utils/colors.dart';

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
            return const Center(child: Text('Error loading groups.'));
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
