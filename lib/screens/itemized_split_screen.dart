import 'package:flutter/material.dart';
import '../models/split_item_model.dart';
import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/modern_card.dart';

class ItemizedSplitResult {
  final List<SplitItem> items;
  final double taxAmount;
  final double tipAmount;

  ItemizedSplitResult({
    required this.items,
    required this.taxAmount,
    required this.tipAmount,
  });
}

class ItemizedSplitScreen extends StatefulWidget {
  final List<SplitItem> initialItems;
  final List<String> participants;
  final double? initialTax;
  final double? initialTip;

  const ItemizedSplitScreen({
    super.key,
    required this.initialItems,
    required this.participants,
    this.initialTax,
    this.initialTip,
  });

  @override
  State<ItemizedSplitScreen> createState() => _ItemizedSplitScreenState();
}

class _ItemizedSplitScreenState extends State<ItemizedSplitScreen> {
  late List<SplitItem> _items;
  final TextEditingController _taxController = TextEditingController();
  final TextEditingController _tipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Deep copy the initial items to avoid mutating original references before confirmation
    _items = widget.initialItems.map((item) => item.copyWith(
      assignedParticipants: List.from(item.assignedParticipants),
    )).toList();

    // If items have no assigned participants initially, assign everyone by default to be helpful!
    for (int i = 0; i < _items.length; i++) {
      if (_items[i].assignedParticipants.isEmpty && widget.participants.isNotEmpty) {
        _items[i] = _items[i].copyWith(assignedParticipants: List.from(widget.participants));
      }
    }

    if (widget.initialTax != null && widget.initialTax! > 0) {
      _taxController.text = widget.initialTax!.toStringAsFixed(2);
    }
    if (widget.initialTip != null && widget.initialTip! > 0) {
      _tipController.text = widget.initialTip!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _taxController.dispose();
    _tipController.dispose();
    super.dispose();
  }

  double get _taxAmount => double.tryParse(_taxController.text) ?? 0.0;
  double get _tipAmount => double.tryParse(_tipController.text) ?? 0.0;

  double get _itemsTotal => _items.fold(0.0, (sum, item) => sum + item.price);
  double get _grandTotal => _itemsTotal + _taxAmount + _tipAmount;

  Map<String, double> _calculateShares() {
    final shares = <String, double>{};
    for (final p in widget.participants) {
      shares[p] = 0.0;
    }

    if (_itemsTotal == 0 || widget.participants.isEmpty) return shares;

    // First calculate subtotal share for each participant based on assigned items
    final subtotals = <String, double>{};
    for (final p in widget.participants) {
      subtotals[p] = 0.0;
    }

    for (final item in _items) {
      if (item.assignedParticipants.isNotEmpty) {
        final splitPrice = item.price / item.assignedParticipants.length;
        for (final p in item.assignedParticipants) {
          if (subtotals.containsKey(p)) {
            subtotals[p] = subtotals[p]! + splitPrice;
          }
        }
      }
    }

    // Now distribute tax and tip proportionally to their subtotal share
    final extraTotal = _taxAmount + _tipAmount;
    final validSubtotalSum = subtotals.values.fold(0.0, (a, b) => a + b);

    for (final p in widget.participants) {
      final sub = subtotals[p] ?? 0.0;
      double extraShare = 0.0;
      if (validSubtotalSum > 0) {
        extraShare = (sub / validSubtotalSum) * extraTotal;
      } else {
        // Fallback: split extra evenly if no items assigned
        extraShare = extraTotal / widget.participants.length;
      }
      shares[p] = sub + extraShare;
    }

    return shares;
  }

  void _addNewItem() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Line Item', style: AppTextStyles.heading2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Item Name',
                border: OutlineInputBorder(),
              ),
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: 'Price',
                border: OutlineInputBorder(),
                prefixText: '₹',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: AppTextStyles.body,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: AppColors.surfaceWhite,
            ),
            onPressed: () {
              final name = nameController.text.trim();
              final price = double.tryParse(priceController.text) ?? 0.0;
              if (name.isNotEmpty && price > 0) {
                setState(() {
                  _items.add(SplitItem(
                    id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                    name: name,
                    price: price,
                    assignedParticipants: List.from(widget.participants),
                  ));
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _toggleParticipant(int itemIndex, String participantEmail) {
    setState(() {
      final item = _items[itemIndex];
      final list = List<String>.from(item.assignedParticipants);
      if (list.contains(participantEmail)) {
        list.remove(participantEmail);
      } else {
        list.add(participantEmail);
      }
      _items[itemIndex] = item.copyWith(assignedParticipants: list);
    });
  }

  @override
  Widget build(BuildContext context) {
    final shares = _calculateShares();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Itemized Split', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Header Summary Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ModernCard(
              gradient: const LinearGradient(
                colors: [AppColors.primaryOrange, AppColors.primaryPeach],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'Total Allocated',
                    style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${_grandTotal.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Items: ₹${_itemsTotal.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Tax/Tip: ₹${(_taxAmount + _tipAmount).toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Main Content Area
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 80, color: AppColors.textSecondary.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        const Text('No line items parsed or added.', style: AppTextStyles.heading2),
                        const SizedBox(height: 8),
                        Text('Add line items manually to divide costs proportionally.', style: TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 24),
                        CustomButton(
                          width: 200,
                          text: 'Add Line Item',
                          icon: Icons.add,
                          onPressed: _addNewItem,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return ModernCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                ),
                                Text(
                                  '₹${item.price.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryOrange),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 20, color: Colors.black38),
                                  onPressed: () => _removeItem(index),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            const Text(
                              'Assigned to:',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: widget.participants.map((pEmail) {
                                final isAssigned = item.assignedParticipants.contains(pEmail);
                                // Extract simple short name from email
                                final shortName = pEmail.split('@').first;
                                return FilterChip(
                                  selected: isAssigned,
                                  label: Text(shortName),
                                  selectedColor: AppColors.secondaryTeal.withValues(alpha: 0.25),
                                  checkmarkColor: AppColors.successGreen,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  onSelected: (_) => _toggleParticipant(index, pEmail),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Settings & Actions Panel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _taxController,
                          decoration: InputDecoration(
                            labelText: 'Tax Amount',
                            prefixText: '₹',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _tipController,
                          decoration: InputDecoration(
                            labelText: 'Tip Amount',
                            prefixText: '₹',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.backgroundLight,
                          padding: const EdgeInsets.all(14),
                        ),
                        icon: const Icon(Icons.add, color: AppColors.primaryOrange),
                        onPressed: _addNewItem,
                        tooltip: 'Add custom line item',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Live Shares Preview Scroll
                  if (widget.participants.isNotEmpty) ...[
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.participants.length,
                        itemBuilder: (context, index) {
                          final p = widget.participants[index];
                          final share = shares[p] ?? 0.0;
                          final shortName = p.split('@').first;
                          return Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceDark.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('$shortName: ', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                                Text('₹${share.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryOrange)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  CustomButton(
                    text: 'Confirm Itemized Split',
                    icon: Icons.check_circle_outline,
                    onPressed: () {
                      // Validate if any items are unassigned
                      final unassigned = _items.where((item) => item.assignedParticipants.isEmpty).toList();
                      if (unassigned.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${unassigned.length} items have no participants assigned!'),
                            backgroundColor: AppColors.warningOrange,
                          ),
                        );
                        return;
                      }

                      Navigator.pop(
                        context,
                        ItemizedSplitResult(
                          items: _items,
                          taxAmount: _taxAmount,
                          tipAmount: _tipAmount,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
