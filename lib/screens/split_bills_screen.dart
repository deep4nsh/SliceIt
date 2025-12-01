import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sliceit/screens/add_friend_screen.dart';
import 'package:sliceit/screens/split_bill_detail_screen.dart';
import 'package:sliceit/services/friend_service.dart';
import '../models/friend_model.dart';
import '../utils/colors.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:sliceit/screens/create_split_bill_screen.dart';
import 'package:sliceit/models/line_model.dart';

class SplitBillsScreen extends StatefulWidget {
  const SplitBillsScreen({super.key});

  @override
  State<SplitBillsScreen> createState() => _SplitBillsScreenState();
}

class _SplitBillsScreenState extends State<SplitBillsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FriendService _friendService = FriendService();

  // Camera/OCR related variables (moved from old implementation)
  final picker = ImagePicker();
  final TextRecognizer textRecognizer = GoogleMlKit.vision.textRecognizer();

  Future<void> _createNewBill(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Scan Receipt'),
            onTap: () async {
              Navigator.pop(context);
              await _processImage(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Upload from Gallery'),
            onTap: () async {
              Navigator.pop(context);
              await _processImage(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Enter Manually'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateSplitBillScreen(lines: [], receiptImage: null),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _processImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) return;

    final imageFile = File(pickedFile.path);
    final inputImage = InputImage.fromFile(imageFile);

    try {
      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
      }

      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      List<Line> lines = [];
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          lines.add(Line(line.text, line.boundingBox));
        }
      }

      if (mounted) {
        Navigator.pop(context); // Hide loading
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateSplitBillScreen(lines: lines, receiptImage: imageFile),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Hide loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1), // Light orange/yellow background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
              child: user?.photoURL == null ? const Icon(Icons.person) : null,
            ),
            const SizedBox(width: 10),
            const Text("Split Bills", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    "You Owe",
                    "₹567.58",
                    Colors.black,
                    Colors.white,
                    Icons.arrow_outward,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    "Owes you",
                    "₹826.43",
                    Colors.black,
                    Colors.white,
                    Icons.arrow_downward,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Pending Bills Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Pending Bills", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(onPressed: () {}, child: const Text("View All", style: TextStyle(color: Colors.orange))),
              ],
            ),
            
            // Pending Bills List
            StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('split_bills')
                  .where('participants', arrayContains: user?.email)
                  .orderBy('createdAt', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Text("No pending bills");

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final splitId = docs[index].id;
                    return _buildBillCard(context, data, splitId, user?.email);
                  },
                );
              },
            ),

            const SizedBox(height: 24),

            // Friends Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Friends", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddFriendScreen()),
                  ),
                ),
              ],
            ),

            // Friends List
            StreamBuilder<List<Friend>>(
              stream: _friendService.getFriendsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final friends = snapshot.data ?? [];
                if (friends.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text("No friends added yet. Add friends to split bills easily!"),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    return _buildFriendItem(friends[index]);
                  },
                );
              },
            ),
            const SizedBox(height: 80), // Space for FAB
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createNewBill(context),
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.add),
        label: const Text("Create Bill"),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String amount, Color bgColor, Color textColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(amount, style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: textColor.withOpacity(0.7))),
              Icon(icon, color: textColor.withOpacity(0.7), size: 20),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillCard(BuildContext context, Map<String, dynamic> data, String splitId, String? userEmail) {
    final title = data['title'] ?? 'Unknown';
    final totalAmount = (data['totalAmount'] as num).toDouble();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final dateStr = createdAt != null ? "${createdAt.day}/${createdAt.month}/${createdAt.year}" : "";
    
    // Determine status (simplified logic)
    final createdBy = data['createdBy'];
    final isOwed = createdBy == userEmail;
    final statusText = isOwed ? "You are owed" : "You owe";
    final statusColor = isOwed ? Colors.green : Colors.red;
    
    // Calculate amount (simplified)
    // In a real app, you'd calculate the exact amount owed/owing based on split type and payments
    final amountDisplay = "₹${(totalAmount / (data['participants'] as List).length).toStringAsFixed(2)}";

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SplitBillDetailScreen(splitId: splitId)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.receipt_long, color: Colors.orange),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("₹${totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "$statusText $amountDisplay", // Simplified
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendItem(Friend friend) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: friend.photoUrl != null ? NetworkImage(friend.photoUrl!) : null,
          child: friend.photoUrl == null ? const Icon(Icons.person) : null,
        ),
        title: Text(friend.name ?? "User", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Owes you ₹0.00", style: TextStyle(color: Colors.green[700], fontSize: 12)), // Placeholder logic
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
