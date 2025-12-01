import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sliceit/models/participant_model.dart';
import 'package:sliceit/screens/split_bills_screen.dart';
import 'package:sliceit/utils/colors.dart';
import 'package:sliceit/utils/text_styles.dart';
import 'package:sliceit/services/friend_service.dart';
import 'package:sliceit/models/friend_model.dart';
import 'package:sliceit/models/line_model.dart';

enum SplitType { equal, unequal }

class CreateSplitBillScreen extends StatefulWidget {
  final List<Line> lines;
  final File? receiptImage;

  const CreateSplitBillScreen({
    super.key,
    required this.lines,
    this.receiptImage,
  });

  @override
  State<CreateSplitBillScreen> createState() => _CreateSplitBillScreenState();
}

class _CreateSplitBillScreenState extends State<CreateSplitBillScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isSaving = false;
  SplitType _splitType = SplitType.equal;
  List<Participant> _participants = [];

  @override
  void initState() {
    super.initState();
    _parseTotalAmount();
    if (widget.lines.isEmpty) {
      _titleController.text = "New Split Bill";
    } else {
      _titleController.text = "Scanned Receipt";
    }
    final currentUserEmail = _auth.currentUser?.email;
    if (currentUserEmail != null) {
      _participants.add(Participant(email: currentUserEmail, isIncluded: true));
    }
  }

  void _parseTotalAmount() {
    double? bestCandidate;
    final RegExp regex = RegExp(r'(\d+[.,]\d{2})');

    for (final line in widget.lines.reversed) {
      final text = line.text.toLowerCase().replaceAll(',', '.');
      if (text.contains('total') || text.contains('subtotal') || text.contains('amount') || text.contains('due')) {
        final Iterable<RegExpMatch> matches = regex.allMatches(text);
        if (matches.isNotEmpty) {
          for (final match in matches) {
            final value = double.tryParse(match.group(1)!);
            if (value != null) {
              if (bestCandidate == null || value > bestCandidate) {
                bestCandidate = value;
              }
            }
          }
        }
      }
    }

    if (bestCandidate == null) {
      for (final line in widget.lines) {
        final text = line.text.replaceAll(',', '.');
        final Iterable<RegExpMatch> matches = regex.allMatches(text);
        if (matches.isNotEmpty) {
          for (final match in matches) {
            final value = double.tryParse(match.group(1)!);
            if (value != null) {
              if (bestCandidate == null || value > bestCandidate) {
                bestCandidate = value;
              }
            }
          }
        }
      }
    }

    if (bestCandidate != null) {
      _amountController.text = bestCandidate.toStringAsFixed(2);
    }
  }

  void _addParticipant() {
    setState(() {
      _participants.add(Participant(email: '', isIncluded: true));
    });
  }

  void _removeParticipant(int index) {
    setState(() {
      _participants.removeAt(index);
    });
  }

  Future<void> _createSplit() async {
    if (_titleController.text.isEmpty || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    final includedParticipants = _participants.where((p) => p.isIncluded).toList();
    if (includedParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please include at least one participant')));
      return;
    }

    if (_splitType == SplitType.unequal) {
      double total = 0;
      for (final p in includedParticipants) {
        total += p.amount;
      }
      if (total != double.parse(_amountController.text)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The sum of the unequal split must equal the total amount')));
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final currentUserEmail = _auth.currentUser?.email;
      if (currentUserEmail == null) throw Exception("User not logged in");

      final participantsEmails = includedParticipants.map((p) => p.email).toSet().toList();
      final paidStatus = {for (var p in participantsEmails) p: false};

      String? receiptUrl;
      if (widget.receiptImage != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('receipts/${_auth.currentUser!.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await storageRef.putFile(widget.receiptImage!);
        receiptUrl = await storageRef.getDownloadURL();
      }

      await _firestore.collection('split_bills').add({
        'title': _titleController.text,
        'totalAmount': double.parse(_amountController.text),
        'createdBy': currentUserEmail,
        'participants': participantsEmails,
        'paidStatus': paidStatus,
        'splitType': _splitType.toString(),
        'amounts': _splitType == SplitType.unequal ? {for (var p in includedParticipants) p.email: p.amount} : {},
        'createdAt': FieldValue.serverTimestamp(),
        'receiptUrl': receiptUrl,
      });

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Split created successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create split: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Split Bill')),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _amountController,
                    decoration: const InputDecoration(labelText: 'Total Amount', border: OutlineInputBorder(), prefixText: '₹'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<SplitType>(
                    segments: const [
                      ButtonSegment(value: SplitType.equal, label: Text('Equal')),
                      ButtonSegment(value: SplitType.unequal, label: Text('Unequal')),
                    ],
                    selected: {_splitType},
                    onSelectionChanged: (newSelection) {
                      setState(() {
                        _splitType = newSelection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<List<Friend>>(
                    stream: FriendService().getFriendsStream(),
                    builder: (context, snapshot) {
                      final friends = snapshot.data ?? [];
                      if (friends.isEmpty) return const SizedBox.shrink();
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Quick Add Friends", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: friends.map((friend) {
                              final alreadyAdded = _participants.any((p) => p.email == friend.email);
                              return InputChip(
                                avatar: friend.photoUrl != null 
                                  ? CircleAvatar(backgroundImage: NetworkImage(friend.photoUrl!))
                                  : null,
                                label: Text(friend.name ?? friend.email),
                                selected: alreadyAdded,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      if (!alreadyAdded) {
                                        _participants.add(Participant(email: friend.email, isIncluded: true));
                                      }
                                    } else {
                                      _participants.removeWhere((p) => p.email == friend.email);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _participants.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _participants[index].isIncluded,
                              onChanged: (value) {
                                setState(() {
                                  _participants[index].isIncluded = value!;
                                });
                              },
                            ),
                            Expanded(
                              child: TextFormField(
                                initialValue: _participants[index].email,
                                onChanged: (value) {
                                  _participants[index].email = value;
                                },
                                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                              ),
                            ),
                            if (_splitType == SplitType.unequal)
                              SizedBox(
                                width: 100,
                                child: TextFormField(
                                  initialValue: _participants[index].amount.toString(),
                                  onChanged: (value) {
                                    _participants[index].amount = double.tryParse(value) ?? 0;
                                  },
                                  decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => _removeParticipant(index),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _addParticipant,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Participant'),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _createSplit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNavy,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: AppTextStyles.button,
                    ),
                    child: const Text('Create Split'),
                  )
                ],
              ),
            ),
    );
  }
}
