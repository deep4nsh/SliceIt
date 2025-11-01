import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/theme_provider.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          userData = doc.data();
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading user data: $e");
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _showEditBudgetDialog() async {
    final budgetController = TextEditingController();
    final user = _auth.currentUser;
    if (user == null) return;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Set Monthly Budget"),
        content: TextField(
          controller: budgetController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: "Amount",
            prefixText: "₹ ",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final newBudget = double.tryParse(budgetController.text);
              if (newBudget != null && newBudget > 0) {
                await _firestore
                    .collection('users')
                    .doc(user.uid)
                    .set({'monthlyBudget': newBudget}, SetOptions(merge: true));

                _loadUserData(); // Reload data
                if (mounted) Navigator.pop(context);
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a valid amount.")),
                );
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 50,
              backgroundImage: user?.photoURL != null
                  ? NetworkImage(user!.photoURL!)
                  : null,
              child: user?.photoURL == null
                  ? const Icon(Icons.person, size: 50)
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              userData?['name'] ?? user?.displayName ?? "User",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              userData?['email'] ?? user?.email ?? "No Email",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 30),
            _buildProfileCard(
              context,
              child: Column(
                children: [
                  _buildInfoRow("User ID", user?.uid ?? "N/A"),
                  const Divider(),
                  _buildInfoRow(
                    "Joined On",
                    userData?['createdAt'] != null
                        ? (userData!['createdAt'] as Timestamp)
                        .toDate()
                        .toString()
                        .substring(0, 10)
                        : "Unknown",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildProfileCard(
              context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Monthly Budget", style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "₹ ${userData?['monthlyBudget']?.toStringAsFixed(2) ?? 'Not Set'}",
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: _showEditBudgetDialog,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildProfileCard(
              context,
              child: SwitchListTile(
                title: const Text("Dark Mode"),
                value: themeProvider.isDarkMode,
                onChanged: (value) {
                  themeProvider.toggleTheme(value);
                  _firestore
                      .collection('users')
                      .doc(user!.uid)
                      .set({'theme': value ? 'dark' : 'light'}, SetOptions(merge: true));
                },
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () async {
                await AuthService().signOut();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                  );
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text("Logout"),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Flexible(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}
