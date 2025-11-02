import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'group_detail_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<QuerySnapshot> _getGroupsStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('groups')
        .where('members', arrayContains: user.uid)
        .snapshots();
  }

  Future<void> _createGroup() async {
    final groupNameController = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Create New Group"),
        content: TextField(
          controller: groupNameController,
          decoration: const InputDecoration(labelText: "Group Name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (groupNameController.text.isEmpty) return;
              final user = _auth.currentUser;
              if (user == null) return;

              await _firestore.collection('groups').add({
                'name': groupNameController.text,
                'createdBy': user.uid,
                'createdAt': FieldValue.serverTimestamp(),
                'members': [user.uid],
              });

              if (mounted) Navigator.pop(context);
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getGroupsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading groups"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final groups = snapshot.data?.docs ?? [];

          if (groups.isEmpty) {
            return const Center(child: Text("No groups yet. Create one!"));
          }

          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              final data = group.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(data['name'] ?? 'No Name'),
                  subtitle: Text("Members: ${(data['members'] as List).length}"),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupDetailScreen(groupId: group.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createGroup,
        label: const Text("New Group"),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
