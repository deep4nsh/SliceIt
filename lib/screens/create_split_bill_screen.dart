import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sliceit/models/participant_model.dart';
import 'package:sliceit/utils/colors.dart';
import 'package:sliceit/utils/text_styles.dart';
import 'package:sliceit/services/friend_service.dart';
import 'package:sliceit/models/friend_model.dart';
import 'package:sliceit/models/line_model.dart';
import 'package:sliceit/services/bill_parser_service.dart';
import 'package:sliceit/models/split_item_model.dart';
import 'package:sliceit/screens/itemized_split_screen.dart';
import 'package:sliceit/widgets/custom_button.dart';

enum SplitType { equal, unequal, itemized }

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
  final List<Participant> _participants = [];

  List<SplitItem>? _parsedItems;
  double? _taxAmount;
  double? _tipAmount;

  @override
  void initState() {
    super.initState();
    _parseReceiptData();
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

  void _parseReceiptData() {
    final parser = BillParserService();
    final amount = parser.parseTotalAmount(widget.lines);
    if (amount != null) {
      _amountController.text = amount.toStringAsFixed(2);
    }

    final items = parser.parseLineItems(widget.lines);
    if (items.isNotEmpty) {
      _parsedItems = items;
      _splitType = SplitType.itemized; // Auto default to itemized split if line items are detected!
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

  Future<void> _openItemizedSplitScreen() async {
    final includedEmails = _participants
        .where((p) => p.isIncluded && p.email.trim().isNotEmpty)
        .map((p) => p.email.trim())
        .toList();

    if (includedEmails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add and select at least one valid participant email first.')),
      );
      return;
    }

    final result = await Navigator.push<ItemizedSplitResult>(
      context,
      MaterialPageRoute(
        builder: (context) => ItemizedSplitScreen(
          initialItems: _parsedItems ?? [],
          participants: includedEmails,
          initialTax: _taxAmount,
          initialTip: _tipAmount,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _parsedItems = result.items;
        _taxAmount = result.taxAmount;
        _tipAmount = result.tipAmount;

        // Recompute overall total
        double itemsTotal = result.items.fold(0.0, (accSum, item) => accSum + item.price);
        double grandTotal = itemsTotal + result.taxAmount + result.tipAmount;
        _amountController.text = grandTotal.toStringAsFixed(2);

        // Apply calculated shares back to participants
        final subtotals = <String, double>{};
        for (final email in includedEmails) {
          subtotals[email] = 0.0;
        }

        for (final item in result.items) {
          if (item.assignedParticipants.isNotEmpty) {
            final splitPrice = item.price / item.assignedParticipants.length;
            for (final p in item.assignedParticipants) {
              if (subtotals.containsKey(p)) {
                subtotals[p] = subtotals[p]! + splitPrice;
              }
            }
          }
        }

        final extraTotal = result.taxAmount + result.tipAmount;
        final validSubtotalSum = subtotals.values.fold(0.0, (a, b) => a + b);

        for (final p in _participants) {
          if (p.isIncluded && includedEmails.contains(p.email.trim())) {
            final sub = subtotals[p.email.trim()] ?? 0.0;
            double extraShare = 0.0;
            if (validSubtotalSum > 0) {
              extraShare = (sub / validSubtotalSum) * extraTotal;
            } else {
              extraShare = extraTotal / includedEmails.length;
            }
            p.amount = double.parse((sub + extraShare).toStringAsFixed(2));
          } else {
            p.amount = 0.0;
          }
        }
      });
    }
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

    if (_splitType == SplitType.unequal || _splitType == SplitType.itemized) {
      double total = 0;
      for (final p in includedParticipants) {
        total += p.amount;
      }
      // Tolerate minor rounding differences of a few cents
      final parsedAmount = double.tryParse(_amountController.text) ?? 0.0;
      if ((total - parsedAmount).abs() > 0.1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('The assigned amounts (sum: ${total.toStringAsFixed(2)}) must equal the Total Amount (${parsedAmount.toStringAsFixed(2)})')),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final currentUserEmail = _auth.currentUser?.email;
      if (currentUserEmail == null) throw Exception("User not logged in");

      final participantsEmails = includedParticipants.map((p) => p.email.trim()).toSet().toList();
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
        'amounts': (_splitType == SplitType.unequal || _splitType == SplitType.itemized) 
            ? {for (var p in includedParticipants) p.email.trim(): p.amount} 
            : {},
        'createdAt': FieldValue.serverTimestamp(),
        'receiptUrl': receiptUrl,
        if (_splitType == SplitType.itemized && _parsedItems != null)
          'items': _parsedItems!.map((i) => i.toMap()).toList(),
        if (_splitType == SplitType.itemized && _taxAmount != null)
          'taxAmount': _taxAmount,
        if (_splitType == SplitType.itemized && _tipAmount != null)
          'tipAmount': _tipAmount,
        'isItemized': _splitType == SplitType.itemized,
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
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Create Split Bill', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                          style: AppTextStyles.body,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _amountController,
                          decoration: InputDecoration(
                            labelText: 'Total Amount',
                            border: const OutlineInputBorder(),
                            prefixText: '₹',
                            helperText: _splitType == SplitType.itemized ? 'Total is calculated from item allocations' : null,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: AppTextStyles.body,
                          // Disable editing total directly if itemized, since it's driven by line items
                          readOnly: _splitType == SplitType.itemized,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  const Text('Split Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  SegmentedButton<SplitType>(
                    style: SegmentedButton.styleFrom(
                      selectedForegroundColor: AppColors.surfaceWhite,
                      selectedBackgroundColor: AppColors.primaryOrange,
                    ),
                    segments: const [
                      ButtonSegment(value: SplitType.equal, label: Text('Equal')),
                      ButtonSegment(value: SplitType.unequal, label: Text('Unequal')),
                      ButtonSegment(value: SplitType.itemized, label: Text('Itemized')),
                    ],
                    selected: {_splitType},
                    onSelectionChanged: (newSelection) {
                      setState(() {
                        _splitType = newSelection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  if (_splitType == SplitType.itemized) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.secondaryTeal.withValues(alpha: 0.1), AppColors.secondaryTeal.withValues(alpha: 0.2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.secondaryTeal.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.assignment_ind_outlined, color: AppColors.secondaryTeal.withValues(alpha: 0.8)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _parsedItems != null && _parsedItems!.isNotEmpty
                                      ? '${_parsedItems!.length} Line Items Allocated'
                                      : 'Assign Line Items to Participants',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          CustomButton(
                            height: 44,
                            borderRadius: 12,
                            backgroundColor: AppColors.secondaryTeal,
                            text: 'Assign Items & Extra Costs',
                            icon: Icons.edit_note,
                            onPressed: _openItemizedSplitScreen,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  StreamBuilder<List<Friend>>(
                    stream: FriendService().getFriendsStream(),
                    builder: (context, snapshot) {
                      final friends = snapshot.data ?? [];
                      if (friends.isEmpty) return const SizedBox.shrink();
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Quick Add Friends", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: friends.map((friend) {
                              final alreadyAdded = _participants.any((p) => p.email.trim() == friend.email.trim());
                              return InputChip(
                                avatar: friend.photoUrl != null 
                                  ? CircleAvatar(backgroundImage: NetworkImage(friend.photoUrl!))
                                  : null,
                                label: Text(friend.name ?? friend.email.split('@').first),
                                selected: alreadyAdded,
                                selectedColor: AppColors.primaryPeach.withValues(alpha: 0.3),
                                checkmarkColor: AppColors.primaryOrange,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      if (!alreadyAdded) {
                                        _participants.add(Participant(email: friend.email, isIncluded: true));
                                      }
                                    } else {
                                      _participants.removeWhere((p) => p.email.trim() == friend.email.trim());
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
                  
                  const Text("Participants", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _participants.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          child: Row(
                            children: [
                              Checkbox(
                                activeColor: AppColors.primaryOrange,
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
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                              ),
                              if (_splitType == SplitType.unequal || _splitType == SplitType.itemized)
                                SizedBox(
                                  width: 100,
                                  child: TextFormField(
                                    key: ValueKey('${_participants[index].email}_${_participants[index].amount}'),
                                    initialValue: _participants[index].amount.toStringAsFixed(2),
                                    onChanged: (value) {
                                      if (_splitType == SplitType.unequal) {
                                        _participants[index].amount = double.tryParse(value) ?? 0;
                                      }
                                    },
                                    readOnly: _splitType == SplitType.itemized,
                                    decoration: InputDecoration(
                                      labelText: 'Amount',
                                      prefixText: '₹',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _splitType == SplitType.itemized ? AppColors.primaryOrange : AppColors.textPrimary,
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.black38),
                                onPressed: () => _removeParticipant(index),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppColors.primaryOrange),
                    onPressed: _addParticipant,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Participant Manually'),
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: 'Create Split Bill',
                    isLoading: _isSaving,
                    onPressed: _createSplit,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
