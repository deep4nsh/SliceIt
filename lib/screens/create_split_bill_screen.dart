import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

import '../models/participant_model.dart';
import '../models/friend_model.dart';
import '../models/line_model.dart';
import '../models/split_item_model.dart';
import '../services/friend_service.dart';
import '../services/bill_parser_service.dart';
import '../services/offline_service.dart';
import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../utils/app_spacing.dart';
import '../widgets/custom_button.dart';
import '../widgets/modern_card.dart';
import '../widgets/mesh_background.dart';

enum SplitType { equal, unequal, percentage, itemized }

/// A state-of-the-art bill creation interface adhering to the dark-first minimalist
/// design system. Features real-time reactive split calculations, stunning custom
/// segment inputs, and comprehensive runtime safety.
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

  List<SplitItem> _parsedItems = [];
  double? _taxAmount;
  double? _tipAmount;
  bool _isParsing = false;

  @override
  void initState() {
    super.initState();
    if (widget.lines.isNotEmpty) {
      _parseReceiptData();
    }
    
    if (widget.lines.isEmpty) {
      _titleController.text = "New Split Bill";
    } else {
      _titleController.text = "Scanned Receipt";
    }
    
    final currentUserEmail = _auth.currentUser?.email;
    if (currentUserEmail != null) {
      _participants.add(Participant(email: currentUserEmail, isIncluded: true));
    }

    // Reactively rebuild to instantly display calculated equal shares as the user types
    _amountController.addListener(() {
      if (_splitType == SplitType.equal && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
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

  Future<void> _runOcrHelper() async {
    if (widget.receiptImage == null) return;
    setState(() => _isParsing = true);
    try {
      final textRecognizer = GoogleMlKit.vision.textRecognizer();
      final inputImage = InputImage.fromFile(widget.receiptImage!);
      final recognizedText = await textRecognizer.processImage(inputImage);
      
      List<Line> extractedLines = [];
      for (var block in recognizedText.blocks) {
        for (var line in block.lines) {
          extractedLines.add(Line(line.text, line.boundingBox));
        }
      }
      textRecognizer.close();

      final parser = BillParserService();
      final amount = parser.parseTotalAmount(extractedLines);
      if (amount != null) {
        _amountController.text = amount.toStringAsFixed(2);
      }

      final items = parser.parseLineItems(extractedLines);
      if (items.isNotEmpty) {
        _parsedItems = items;
        _splitType = SplitType.itemized;
        
        final validEmails = _participants
            .where((p) => p.isIncluded && p.email.trim().isNotEmpty)
            .map((p) => p.email.trim())
            .toList();
        
        for (int i = 0; i < _parsedItems.length; i++) {
          if (_parsedItems[i].assignedParticipants.isEmpty) {
            _parsedItems[i] = _parsedItems[i].copyWith(assignedParticipants: validEmails);
          }
        }
        _recalculateItemizedShares();
      }
      _showSnackBar("Receipt auto-filled successfully!", isError: false);
    } catch (e) {
      _showSnackBar("Failed to parse receipt: $e");
    } finally {
      if (mounted) setState(() => _isParsing = false);
    }
  }

  void _recalculateItemizedShares() {
    if (_splitType != SplitType.itemized) return;

    final includedEmails = _participants
        .where((p) => p.isIncluded && p.email.trim().isNotEmpty)
        .map((p) => p.email.trim())
        .toList();

    double itemsTotal = _parsedItems.fold(0.0, (accSum, item) => accSum + item.price);
    double grandTotal = itemsTotal + (_taxAmount ?? 0.0) + (_tipAmount ?? 0.0);
    _amountController.text = grandTotal.toStringAsFixed(2);

    final subtotals = <String, double>{};
    for (final email in includedEmails) {
      subtotals[email] = 0.0;
    }

    for (final item in _parsedItems) {
      final validAssignees = item.assignedParticipants
          .where((email) => includedEmails.contains(email))
          .toList();

      if (validAssignees.isNotEmpty) {
        final splitPrice = item.price / validAssignees.length;
        for (final p in validAssignees) {
          subtotals[p] = subtotals[p]! + splitPrice;
        }
      }
    }

    final extraTotal = (_taxAmount ?? 0.0) + (_tipAmount ?? 0.0);
    final validSubtotalSum = subtotals.values.fold(0.0, (a, b) => a + b);

    for (final p in _participants) {
      if (p.isIncluded && includedEmails.contains(p.email.trim())) {
        final sub = subtotals[p.email.trim()] ?? 0.0;
        double extraShare = 0.0;
        if (validSubtotalSum > 0) {
          extraShare = (sub / validSubtotalSum) * extraTotal;
        } else {
          extraShare = includedEmails.isNotEmpty ? extraTotal / includedEmails.length : 0.0;
        }
        p.amount = double.parse((sub + extraShare).toStringAsFixed(2));
      } else {
        p.amount = 0.0;
      }
    }
  }

  void _addParticipant() {
    setState(() {
      _participants.add(Participant(email: '', isIncluded: true));
      _recalculateItemizedShares();
    });
  }

  void _removeParticipant(int index) {
    setState(() {
      _participants.removeAt(index);
      _recalculateItemizedShares();
    });
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTextStyles.bodyM.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
      ),
    );
  }

  Future<void> _createSplit() async {
    if (_titleController.text.isEmpty || _amountController.text.isEmpty) {
      _showSnackBar('Please fill in all bill details.');
      return;
    }

    final includedParticipants = _participants.where((p) => p.isIncluded).toList();
    if (includedParticipants.isEmpty) {
      _showSnackBar('Please include at least one participant.');
      return;
    }

    if (_splitType == SplitType.percentage) {
      double totalPercent = 0;
      for (final p in includedParticipants) {
        totalPercent += (p.percentage ?? 0);
      }
      if ((totalPercent - 100).abs() > 0.1) {
        _showSnackBar(
          'Percentages must sum to 100% (current: ${totalPercent.toStringAsFixed(1)}%)',
        );
        return;
      }
      // Calculate amounts from percentages
      final total = double.tryParse(_amountController.text) ?? 0.0;
      for (final p in includedParticipants) {
        p.amount = (total * (p.percentage ?? 0)) / 100;
      }
    } else if (_splitType == SplitType.unequal || _splitType == SplitType.itemized) {
      double total = 0;
      for (final p in includedParticipants) {
        total += p.amount;
      }
      // Tolerate minor rounding differences of a few cents
      final parsedAmount = double.tryParse(_amountController.text) ?? 0.0;
      if ((total - parsedAmount).abs() > 0.1) {
        _showSnackBar(
          'Assigned amounts (sum: ₹${total.toStringAsFixed(2)}) must equal the Total Amount (₹${parsedAmount.toStringAsFixed(2)})',
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final currentUserEmail = _auth.currentUser?.email;
      if (currentUserEmail == null) throw Exception("User session expired or not logged in.");

      final participantsEmails = includedParticipants.map((p) => p.email.trim()).toSet().toList();
      final paidStatus = {for (var p in participantsEmails) p: false};

      String? receiptUrl;
      if (widget.receiptImage != null) {
        try {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('receipts/${_auth.currentUser!.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
          await storageRef.putFile(widget.receiptImage!);
          receiptUrl = await storageRef.getDownloadURL();
        } catch (e) {
          debugPrint('Warning: Could not upload receipt image: $e');
          // Continue without receipt URL - will retry when online
        }
      }

      final billData = {
        'title': _titleController.text,
        'totalAmount': double.parse(_amountController.text),
        'createdBy': currentUserEmail,
        'participants': participantsEmails,
        'paidStatus': paidStatus,
        'splitType': _splitType.toString(),
        'amounts': (_splitType == SplitType.unequal || _splitType == SplitType.percentage || _splitType == SplitType.itemized)
            ? {for (var p in includedParticipants) p.email.trim(): p.amount}
            : {},
        'percentages': (_splitType == SplitType.percentage)
            ? {for (var p in includedParticipants) p.email.trim(): (p.percentage ?? 0)}
            : {},
        'createdAt': FieldValue.serverTimestamp(),
        if (receiptUrl != null) 'receiptUrl': receiptUrl,
        if (_splitType == SplitType.itemized && _parsedItems.isNotEmpty)
          'items': _parsedItems.map((i) => i.toMap()).toList(),
        if (_splitType == SplitType.itemized && _taxAmount != null)
          'taxAmount': _taxAmount,
        if (_splitType == SplitType.itemized && _tipAmount != null)
          'tipAmount': _tipAmount,
        'isItemized': _splitType == SplitType.itemized,
      };

      try {
        await _firestore.collection('split_bills').add(billData);
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
        _showSnackBar('Split bill created successfully!', isError: false);
      } catch (e) {
        // Save offline if sync fails
        debugPrint('Could not sync to Firestore: $e, saving offline...');
        billData['_timestamp'] = DateTime.now().millisecondsSinceEpoch.toString();
        await OfflineService.savePendingSplitBill(billData);

        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
        _showSnackBar('Saved offline. Will sync when online.', isError: false);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to create split: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildItemizedSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.receiptImage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ModernCard(
              color: Colors.transparent,
              child: _isParsing 
                  ? Center(child: CircularProgressIndicator(color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent))
                  : CustomButton(
                      text: "⚡ Auto-fill from Receipt",
                      icon: Icons.document_scanner_rounded,
                      onPressed: _runOcrHelper,
                      backgroundColor: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                      textColor: isDark ? AppColors.textDarkPrimary : Colors.white,
                    ),
            ),
          ),
        
        if (_parsedItems.isNotEmpty) ...[
          Text(
            "Line Items",
            style: AppTextStyles.h3.copyWith(
              color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ..._parsedItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return ModernCard(
              margin: const EdgeInsets.only(bottom: 8),
              color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: item.name,
                          style: AppTextStyles.bodyL.copyWith(
                            color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (val) {
                            _parsedItems[index] = item.copyWith(name: val);
                          },
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          initialValue: item.price.toStringAsFixed(2),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.right,
                          style: AppTextStyles.bodyL.copyWith(
                            color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            prefixText: "₹",
                            prefixStyle: AppTextStyles.bodyL.copyWith(
                              color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                              fontWeight: FontWeight.bold,
                            ),
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (val) {
                            final newPrice = double.tryParse(val) ?? 0.0;
                            _parsedItems[index] = item.copyWith(price: newPrice);
                            _recalculateItemizedShares();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _participants.where((p) => p.isIncluded).map((p) {
                      final isAssigned = item.assignedParticipants.contains(p.email.trim());
                      return InkWell(
                        onTap: () {
                          setState(() {
                            final newAssignees = List<String>.from(item.assignedParticipants);
                            if (isAssigned) {
                              newAssignees.remove(p.email.trim());
                            } else {
                              newAssignees.add(p.email.trim());
                            }
                            _parsedItems[index] = item.copyWith(assignedParticipants: newAssignees);
                            _recalculateItemizedShares();
                          });
                        },
                        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                        child: AnimatedContainer(
                          duration: 150.ms,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isAssigned 
                                ? (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent).withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                            border: Border.all(
                              color: isAssigned 
                                  ? (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent)
                                  : (isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder),
                            ),
                          ),
                          child: Text(
                            p.email.split('@').first,
                            style: AppTextStyles.label.copyWith(
                              color: isAssigned
                                  ? (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent)
                                  : (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 10),
          CustomButton(
            text: "Add Line Item",
            icon: Icons.add_rounded,
            onPressed: () {
              setState(() {
                _parsedItems.add(SplitItem(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: "New Item",
                  price: 0.0,
                  assignedParticipants: _participants.where((p) => p.isIncluded).map((p) => p.email.trim()).toList(),
                ));
                _recalculateItemizedShares();
              });
            },
            variant: ButtonVariant.outline,
            backgroundColor: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
            textColor: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
          ),
          const SizedBox(height: 20),
          Text(
            "Taxes & Tips",
            style: AppTextStyles.h3.copyWith(
              color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ModernCard(
            color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Tax Amount",
                        style: AppTextStyles.bodyM.copyWith(
                          color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: TextFormField(
                        initialValue: _taxAmount?.toStringAsFixed(2) ?? "",
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.right,
                        style: AppTextStyles.bodyL.copyWith(
                          color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                        ),
                        decoration: InputDecoration(
                          prefixText: "₹",
                          prefixStyle: AppTextStyles.bodyL.copyWith(
                            color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                          ),
                          hintText: "0.00",
                          isDense: true,
                          border: InputBorder.none,
                        ),
                        onChanged: (val) {
                          _taxAmount = double.tryParse(val);
                          _recalculateItemizedShares();
                        },
                      ),
                    ),
                  ],
                ),
                Divider(color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Tip Amount",
                        style: AppTextStyles.bodyM.copyWith(
                          color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: TextFormField(
                        initialValue: _tipAmount?.toStringAsFixed(2) ?? "",
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.right,
                        style: AppTextStyles.bodyL.copyWith(
                          color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                        ),
                        decoration: InputDecoration(
                          prefixText: "₹",
                          prefixStyle: AppTextStyles.bodyL.copyWith(
                            color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                          ),
                          hintText: "0.00",
                          isDense: true,
                          border: InputBorder.none,
                        ),
                        onChanged: (val) {
                          _tipAmount = double.tryParse(val);
                          _recalculateItemizedShares();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else ...[
           if (widget.receiptImage == null)
             ModernCard(
               color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
               child: Column(
                 children: [
                   Icon(
                     Icons.receipt_long_outlined,
                     size: 48,
                     color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary).withValues(alpha: 0.5),
                   ),
                   const SizedBox(height: 16),
                   Text(
                     "No Line Items Yet",
                     style: AppTextStyles.bodyL.copyWith(
                       color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                       fontWeight: FontWeight.bold,
                     ),
                   ),
                   const SizedBox(height: 8),
                   Text(
                     "Add line items manually or attach a receipt to auto-fill.",
                     textAlign: TextAlign.center,
                     style: AppTextStyles.bodyM.copyWith(
                       color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary),
                     ),
                   ),
                   const SizedBox(height: 16),
                   CustomButton(
                     text: "Add First Item",
                     icon: Icons.add_rounded,
                     onPressed: () {
                       setState(() {
                         _parsedItems.add(SplitItem(
                           id: DateTime.now().millisecondsSinceEpoch.toString(),
                           name: "New Item",
                           price: 0.0,
                           assignedParticipants: _participants.where((p) => p.isIncluded).map((p) => p.email.trim()).toList(),
                         ));
                         _recalculateItemizedShares();
                       });
                     },
                     variant: ButtonVariant.primary,
                     backgroundColor: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                     textColor: isDark ? AppColors.textDarkPrimary : Colors.white,
                   ),
                 ],
               ),
             ),
        ],
      ],
    );
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String labelText,
    String? prefixText,
    bool readOnly = false,
    TextInputType? keyboardType,
    String? helperText,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: AppTextStyles.label.copyWith(
            color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary).withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          style: AppTextStyles.bodyL.copyWith(
            color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            prefixText: prefixText,
            prefixStyle: AppTextStyles.bodyL.copyWith(
              color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
              fontWeight: FontWeight.bold,
            ),
            filled: true,
            fillColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: BorderSide(
                color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent).withValues(alpha: 0.8),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  helperText,
                  style: AppTextStyles.label.copyWith(
                    color: (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent).withValues(alpha: 0.8),
                    fontSize: 11,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final activeColor = isDark ? AppColors.secondaryAccent : AppColors.primaryAccent;
    final inactiveBg = isDark ? AppColors.darkSurface2 : AppColors.lightSurface2;
    final inactiveText = (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary).withValues(alpha: 0.8);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: AnimatedContainer(
          duration: 200.ms,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: isDark ? 0.15 : 0.08) : inactiveBg,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: isSelected ? activeColor : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: isSelected ? activeColor : inactiveText),
              const SizedBox(height: 4),
              Text(
                title,
                style: AppTextStyles.label.copyWith(
                  color: isSelected ? (isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary) : inactiveText,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFriendChip(Friend friend, bool isSelected, bool isDark) {
    final name = friend.name ?? friend.email.split('@').first;
    final accent = isDark ? AppColors.secondaryAccent : AppColors.primaryAccent;

    return InkWell(
      onTap: () {
        setState(() {
          if (!isSelected) {
            _participants.add(Participant(email: friend.email, isIncluded: true));
          } else {
            _participants.removeWhere((p) => p.email.trim() == friend.email.trim());
          }
        });
      },
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      child: AnimatedContainer(
        duration: 150.ms,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? accent.withValues(alpha: 0.15) 
              : (isDark ? AppColors.darkSurface2 : AppColors.lightSurface2),
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          border: Border.all(
            color: isSelected ? accent : (isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
              backgroundImage: friend.photoUrl != null ? NetworkImage(friend.photoUrl!) : null,
              child: friend.photoUrl == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: AppTextStyles.label.copyWith(fontSize: 10, color: accent),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              name,
              style: AppTextStyles.label.copyWith(
                color: isSelected 
                    ? (isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary)
                    : (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Icon(Icons.check_circle_rounded, size: 14, color: accent),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Calculate dynamic equal share for previewing
    final includedCount = _participants.where((p) => p.isIncluded).length;
    final totalAmountVal = double.tryParse(_amountController.text) ?? 0.0;
    final equalShareVal = includedCount > 0 ? totalAmountVal / includedCount : 0.0;
    final equalShareFormatted = equalShareVal.toStringAsFixed(2);

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          title: Text(
            'Create Split Bill',
            style: AppTextStyles.h2.copyWith(
              color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: _isSaving
            ? Center(
                child: ModernCard(
                  color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Creating Split Bill...",
                        style: AppTextStyles.label.copyWith(
                          color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Bento Card 1: Main Bill Info
                    ModernCard(
                      color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCustomTextField(
                            controller: _titleController,
                            labelText: "Bill Title",
                            isDark: isDark,
                          ),
                          const SizedBox(height: 16),
                          _buildCustomTextField(
                            controller: _amountController,
                            labelText: "Total Amount",
                            prefixText: "₹ ",
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            readOnly: _splitType == SplitType.itemized,
                            helperText: _splitType == SplitType.itemized
                                ? "Total amount is calculated automatically from line items"
                                : null,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ).animate().fade(duration: 300.ms).slideY(begin: 0.05, end: 0),

                    // Bento Card 2: Split Strategy Selection
                    Text(
                      "Split Method",
                      style: AppTextStyles.h3.copyWith(
                        color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildTabButton(
                            title: "Equal",
                            icon: Icons.pie_chart_outline_rounded,
                            isSelected: _splitType == SplitType.equal,
                            onTap: () => setState(() => _splitType = SplitType.equal),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildTabButton(
                            title: "Unequal",
                            icon: Icons.splitscreen_rounded,
                            isSelected: _splitType == SplitType.unequal,
                            onTap: () => setState(() => _splitType = SplitType.unequal),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildTabButton(
                            title: "Percentage",
                            icon: Icons.percent_rounded,
                            isSelected: _splitType == SplitType.percentage,
                            onTap: () => setState(() => _splitType = SplitType.percentage),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildTabButton(
                            title: "Itemized",
                            icon: Icons.receipt_long_rounded,
                            isSelected: _splitType == SplitType.itemized,
                            onTap: () => setState(() => _splitType = SplitType.itemized),
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ).animate().fade(duration: 350.ms).slideY(begin: 0.05, end: 0),
                    const SizedBox(height: 20),

                    if (_splitType == SplitType.percentage) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          border: Border.all(
                            color: (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Builder(
                          builder: (_) {
                            final includedParticipants = _participants.where((p) => p.isIncluded).toList();
                            final totalPercent = includedParticipants.fold<double>(0, (sum, p) => sum + (p.percentage ?? 0));
                            final isValid = (totalPercent - 100).abs() < 0.1;
                            return Text(
                              'Total: ${totalPercent.toStringAsFixed(1)}% ${isValid ? '✓' : '(must be 100%)'}',
                              style: AppTextStyles.label.copyWith(
                                color: isValid
                                    ? (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent)
                                    : AppColors.error,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_splitType == SplitType.itemized) ...[
                      _buildItemizedSection(isDark).animate().fade(duration: 400.ms),
                      const SizedBox(height: 16),
                    ],

                    // Quick Add Friends Feed
                    StreamBuilder<List<Friend>>(
                      stream: FriendService().getFriendsStream(),
                      builder: (context, snapshot) {
                        final friends = snapshot.data ?? [];
                        if (friends.isEmpty) return const SizedBox.shrink();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Quick Add Friends",
                              style: AppTextStyles.h3.copyWith(
                                color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: friends.map((friend) {
                                final isSelected = _participants.any((p) => p.email.trim() == friend.email.trim());
                                return _buildFriendChip(friend, isSelected, isDark);
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ).animate().fade(duration: 400.ms);
                      },
                    ),

                    // Participants Listing Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Participants",
                          style: AppTextStyles.h3.copyWith(
                            color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addParticipant,
                          icon: Icon(
                            Icons.add_rounded,
                            size: 18,
                            color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                          ),
                          label: Text(
                            "Add Manually",
                            style: AppTextStyles.label.copyWith(
                              color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Participants List Rows
                    ModernCard(
                      padding: EdgeInsets.zero,
                      color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _participants.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
                        ),
                        itemBuilder: (context, index) {
                          final participant = _participants[index];
                          return Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                // Custom interactive checkbox
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      participant.isIncluded = !participant.isIncluded;
                                    });
                                  },
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: participant.isIncluded
                                          ? (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: participant.isIncluded
                                            ? (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent)
                                            : (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                                                .withValues(alpha: 0.5),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: participant.isIncluded
                                        ? Icon(
                                            Icons.check_rounded,
                                            size: 16,
                                            color: isDark ? AppColors.darkBackground : Colors.white,
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: participant.email,
                                    onChanged: (val) => participant.email = val,
                                    style: AppTextStyles.bodyM.copyWith(
                                      color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: "participant@example.com",
                                      hintStyle: AppTextStyles.bodyM.copyWith(
                                        color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                                            .withValues(alpha: 0.5),
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Share amount preview or input field
                                if (_splitType == SplitType.equal)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                    ),
                                    child: Text(
                                      participant.isIncluded ? "₹$equalShareFormatted" : "₹0.00",
                                      style: AppTextStyles.label.copyWith(
                                        color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                                      ),
                                    ),
                                  )
                                else if (_splitType == SplitType.percentage)
                                  SizedBox(
                                    width: 95,
                                    child: TextFormField(
                                      key: ValueKey('${participant.email}_${participant.percentage}'),
                                      initialValue: (participant.percentage ?? 0).toStringAsFixed(1),
                                      onChanged: (val) {
                                        setState(() {
                                          participant.percentage = double.tryParse(val) ?? 0.0;
                                        });
                                      },
                                      textAlign: TextAlign.right,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: AppTextStyles.label.copyWith(
                                        color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                                        fontSize: 13,
                                      ),
                                      decoration: InputDecoration(
                                        suffixText: "%",
                                        suffixStyle: AppTextStyles.label.copyWith(
                                          color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                                              .withValues(alpha: 0.5),
                                        ),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        filled: true,
                                        fillColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  SizedBox(
                                    width: 95,
                                    child: TextFormField(
                                      key: ValueKey('${participant.email}_${participant.amount}'),
                                      initialValue: participant.amount.toStringAsFixed(2),
                                      onChanged: (val) {
                                        if (_splitType == SplitType.unequal) {
                                          participant.amount = double.tryParse(val) ?? 0.0;
                                        }
                                      },
                                      readOnly: _splitType == SplitType.itemized,
                                      textAlign: TextAlign.right,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: AppTextStyles.label.copyWith(
                                        color: _splitType == SplitType.itemized
                                            ? (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent)
                                            : (isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary),
                                        fontSize: 13,
                                      ),
                                      decoration: InputDecoration(
                                        prefixText: "₹",
                                        prefixStyle: AppTextStyles.label.copyWith(
                                          color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                                              .withValues(alpha: 0.5),
                                        ),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        filled: true,
                                        fillColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                                        .withValues(alpha: 0.6),
                                  ),
                                  onPressed: () => _removeParticipant(index),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ).animate().fade(duration: 450.ms),
                    const SizedBox(height: 24),

                    // Main Action Submission Button
                    CustomButton(
                      text: "Finalize Split Bill",
                      icon: Icons.check_circle_outline_rounded,
                      isLoading: _isSaving,
                      backgroundColor: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                      textColor: isDark ? AppColors.textDarkPrimary : Colors.white,
                      onPressed: _createSplit,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }
}

