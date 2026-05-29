import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfExportService {
  static final _dateFormat = DateFormat('dd MMM yyyy');
  static final _currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  static String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'N/A';
    try {
      if (dateValue is String) {
        return _dateFormat.format(DateTime.parse(dateValue));
      }
      if (dateValue.toString().contains('toDate')) {
        return _dateFormat.format(dateValue.toDate?.call() ?? DateTime.now());
      }
      return _dateFormat.format(dateValue as DateTime);
    } catch (_) {
      return 'N/A';
    }
  }

  static Future<void> exportGroupInvoice({
    required String groupName,
    required List<Map<String, dynamic>> expenses,
    required Map<String, double> balances,
    bool share = true,
  }) async {
    final totalAmount = expenses.fold<double>(0, (sum, exp) => sum + ((exp['amount'] as num?)?.toDouble() ?? 0));

    final pdf = pw.Document();
    final inter = await PdfGoogleFonts.interRegular();
    final interBold = await PdfGoogleFonts.interBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 35),
        build: (context) => [
          // Header with logo area
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromHex('3C78D8'), width: 3)),
            ),
            padding: const pw.EdgeInsets.only(bottom: 20),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'SliceIt',
                      style: pw.TextStyle(
                        fontSize: 32,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('3C78D8'),
                        font: interBold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Group Expense Report',
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColor.fromHex('64748b'),
                        font: inter,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Generated',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('94a3b8'),
                        font: inter,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      _dateFormat.format(DateTime.now()),
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('1e293b'),
                        font: interBold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 25),

          // Group info card with gradient effect
          pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('f0f4ff'),
              border: pw.Border.all(color: PdfColor.fromHex('3C78D8'), width: 2),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  groupName.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('3C78D8'),
                    font: interBold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'MEMBERS',
                          style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('64748b'), fontWeight: pw.FontWeight.bold, font: inter),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '${balances.length}',
                          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('1e293b'), font: interBold),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'EXPENSES',
                          style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('64748b'), fontWeight: pw.FontWeight.bold, font: inter),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '${expenses.length}',
                          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('1e293b'), font: interBold),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'TOTAL SPENT',
                          style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('64748b'), fontWeight: pw.FontWeight.bold, font: inter),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          _formatCurrency(totalAmount),
                          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('3C78D8'), font: interBold),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 30),

          // Stats grid
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildEnhancedStatCard(
                'Total Spent',
                _formatCurrency(totalAmount),
                PdfColor.fromHex('3c78d8'),
                inter,
                interBold,
              ),
              _buildEnhancedStatCard(
                'Average',
                _formatCurrency(expenses.isEmpty ? 0.0 : totalAmount / expenses.length),
                PdfColor.fromHex('34a853'),
                inter,
                interBold,
              ),
              _buildEnhancedStatCard(
                'Members',
                '${balances.length}',
                PdfColor.fromHex('ea4335'),
                inter,
                interBold,
              ),
            ],
          ),
          pw.SizedBox(height: 30),

          // Expenses table
          pw.Text(
            'EXPENSE BREAKDOWN',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('1e293b'),
              font: interBold,
            ),
          ),
          pw.SizedBox(height: 12),
          _buildEnhancedExpensesTable(expenses, inter, interBold),
          pw.SizedBox(height: 28),

          // Members table
          pw.Text(
            'MEMBER SETTLEMENT',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('1e293b'),
              font: interBold,
            ),
          ),
          pw.SizedBox(height: 12),
          _buildEnhancedMembersTable(balances, inter, interBold),
          pw.SizedBox(height: 35),

          // Footer
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColor.fromHex('e2e8f0'), width: 1)),
            ),
            padding: const pw.EdgeInsets.only(top: 15),
            child: pw.Text(
              'Generated by SliceIt • Split bills effortlessly',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColor.fromHex('94a3b8'),
                font: inter,
              ),
            ),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();

    if (share) {
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'sliceit_${groupName.toLowerCase().replaceAll(' ', '_')}_invoice_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } else {
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'sliceit_${groupName.toLowerCase().replaceAll(' ', '_')}_invoice_${DateTime.now().millisecondsSinceEpoch}',
      );
    }
  }

  static String _formatCurrency(double amount) {
    if (amount >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(1)}Cr';
    } else if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(1)}L';
    }
    return _currencyFormat.format(amount);
  }

  static pw.Widget _buildEnhancedStatCard(
    String label,
    String value,
    PdfColor color,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Expanded(
      child: pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: color, width: 2),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          color: PdfColor.fromHex('ffffff'),
        ),
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('64748b'),
                font: font,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              value,
              textAlign: pw.TextAlign.center,
              maxLines: 2,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: color,
                font: fontBold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildEnhancedExpensesTable(
    List<Map<String, dynamic>> expenses,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(0.8),
        1: const pw.FlexColumnWidth(2.5),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.8),
        4: const pw.FlexColumnWidth(1.4),
      },
      border: pw.TableBorder(
        top: pw.BorderSide(color: PdfColor.fromHex('cbd5e1'), width: 1),
        bottom: pw.BorderSide(color: PdfColor.fromHex('cbd5e1'), width: 1),
        horizontalInside: pw.BorderSide(color: PdfColor.fromHex('e2e8f0'), width: 0.5),
      ),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('f1f5f9')),
          children: [
            _buildEnhancedTableHeader('#', font),
            _buildEnhancedTableHeader('Description', font),
            _buildEnhancedTableHeader('Amount', font),
            _buildEnhancedTableHeader('Paid By', font),
            _buildEnhancedTableHeader('Date', font),
          ],
        ),
        ...expenses.asMap().entries.map((entry) {
          final i = entry.key;
          final exp = entry.value;
          final title = (exp['title'] as String?) ?? 'Unknown';
          final amount = (exp['amount'] as num?)?.toDouble() ?? 0;
          final paidBy = ((exp['paidBy'] as String?) ?? 'Unknown').split('@').first;
          final date = _formatDate(exp['date']);
          final isEven = i.isEven;

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: isEven ? PdfColor.fromHex('ffffff') : PdfColor.fromHex('f8fafc')),
            children: [
              _buildEnhancedTableCell('${i + 1}', font),
              _buildEnhancedTableCell(title, font),
              _buildEnhancedTableCell(_formatCurrency(amount), font, align: pw.TextAlign.right),
              _buildEnhancedTableCell(paidBy, font),
              _buildEnhancedTableCell(date, font),
            ],
          );
        }).toList(),
      ],
    );
  }

  static pw.Widget _buildEnhancedMembersTable(
    Map<String, double> balances,
    pw.Font font,
    pw.Font fontBold,
  ) {
    final entries = balances.entries.toList();
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(1.5),
      },
      border: pw.TableBorder(
        top: pw.BorderSide(color: PdfColor.fromHex('cbd5e1'), width: 1),
        bottom: pw.BorderSide(color: PdfColor.fromHex('cbd5e1'), width: 1),
        horizontalInside: pw.BorderSide(color: PdfColor.fromHex('e2e8f0'), width: 0.5),
      ),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('f1f5f9')),
          children: [
            _buildEnhancedTableHeader('Member', font),
            _buildEnhancedTableHeader('Balance', font),
            _buildEnhancedTableHeader('Status', font),
          ],
        ),
        ...entries.asMap().entries.map((entry) {
          final idx = entry.key;
          final mapEntry = entry.value;
          final name = mapEntry.key;
          final val = mapEntry.value;

          final statusText = val > 0.01 ? 'Gets Back' : (val < -0.01 ? 'Pays' : 'Settled');
          final statusColor = val > 0.01 ? PdfColor.fromHex('34a853') : (val < -0.01 ? PdfColor.fromHex('ea4335') : PdfColor.fromHex('64748b'));
          final isEven = idx.isEven;

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: isEven ? PdfColor.fromHex('ffffff') : PdfColor.fromHex('f8fafc')),
            children: [
              _buildEnhancedTableCell(name, font),
              _buildEnhancedTableCell(_formatCurrency(val.abs()), font, align: pw.TextAlign.right),
              _buildStatusCell(statusText, statusColor, font),
            ],
          );
        }).toList(),
      ],
    );
  }

  static pw.Widget _buildEnhancedTableHeader(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('475569'),
          font: font,
        ),
      ),
    );
  }

  static pw.Widget _buildEnhancedTableCell(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          color: PdfColor.fromHex('1e293b'),
          font: font,
        ),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _buildStatusCell(String text, PdfColor color, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: pw.Container(
        decoration: pw.BoxDecoration(
          color: color.withAlpha(0.1),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: color,
            font: font,
          ),
          textAlign: pw.TextAlign.center,
        ),
      ),
    );
  }

  static Future<void> exportGroupStatement({
    required String groupName,
    required List<Map<String, dynamic>> expenses,
    required Map<String, double> balances,
    bool share = true,
  }) async {
    return exportGroupInvoice(
      groupName: groupName,
      expenses: expenses,
      balances: balances,
      share: share,
    );
  }

  static Future<void> exportPersonalStatement({
    required String userName,
    required List<Map<String, dynamic>> expenses,
    required double totalSpent,
    bool share = true,
  }) async {
    final pdf = pw.Document();
    final inter = await PdfGoogleFonts.interRegular();
    final interBold = await PdfGoogleFonts.interBold();
    final avgExpense = expenses.isEmpty ? 0.0 : totalSpent / expenses.length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 35),
        build: (context) => [
          // Header
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromHex('3C78D8'), width: 3)),
            ),
            padding: const pw.EdgeInsets.only(bottom: 20),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'SliceIt',
                      style: pw.TextStyle(
                        fontSize: 32,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('3C78D8'),
                        font: interBold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Personal Expense Report',
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColor.fromHex('64748b'),
                        font: inter,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Generated',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('94a3b8'),
                        font: inter,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      _dateFormat.format(DateTime.now()),
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('1e293b'),
                        font: interBold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 25),

          // User info card
          pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('f0f4ff'),
              border: pw.Border.all(color: PdfColor.fromHex('3C78D8'), width: 2),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  userName.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('3C78D8'),
                    font: interBold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'TOTAL SPENT',
                          style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('64748b'), fontWeight: pw.FontWeight.bold, font: inter),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          _formatCurrency(totalSpent),
                          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('3C78D8'), font: interBold),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'EXPENSES',
                          style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('64748b'), fontWeight: pw.FontWeight.bold, font: inter),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '${expenses.length}',
                          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('1e293b'), font: interBold),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'AVERAGE',
                          style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('64748b'), fontWeight: pw.FontWeight.bold, font: inter),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          _formatCurrency(avgExpense),
                          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('1e293b'), font: interBold),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 30),

          // Stats grid
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildEnhancedStatCard(
                'Total Spent',
                _formatCurrency(totalSpent),
                PdfColor.fromHex('3c78d8'),
                inter,
                interBold,
              ),
              _buildEnhancedStatCard(
                'Expenses Count',
                '${expenses.length}',
                PdfColor.fromHex('34a853'),
                inter,
                interBold,
              ),
              _buildEnhancedStatCard(
                'Per Expense',
                _formatCurrency(avgExpense),
                PdfColor.fromHex('ea4335'),
                inter,
                interBold,
              ),
            ],
          ),
          pw.SizedBox(height: 30),

          // Expenses table
          pw.Text(
            'EXPENSE DETAILS',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('1e293b'),
              font: interBold,
            ),
          ),
          pw.SizedBox(height: 12),
          _buildPersonalExpensesTable(expenses, inter, interBold),
          pw.SizedBox(height: 35),

          // Footer
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColor.fromHex('e2e8f0'), width: 1)),
            ),
            padding: const pw.EdgeInsets.only(top: 15),
            child: pw.Text(
              'Generated by SliceIt • Split bills effortlessly',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColor.fromHex('94a3b8'),
                font: inter,
              ),
            ),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();

    if (share) {
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'sliceit_${userName.toLowerCase().replaceAll(' ', '_')}_statement_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } else {
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'sliceit_${userName.toLowerCase().replaceAll(' ', '_')}_statement_${DateTime.now().millisecondsSinceEpoch}',
      );
    }
  }

  static pw.Widget _buildPersonalExpensesTable(
    List<Map<String, dynamic>> expenses,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(0.8),
        1: const pw.FlexColumnWidth(2.5),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.8),
        4: const pw.FlexColumnWidth(1.4),
      },
      border: pw.TableBorder(
        top: pw.BorderSide(color: PdfColor.fromHex('cbd5e1'), width: 1),
        bottom: pw.BorderSide(color: PdfColor.fromHex('cbd5e1'), width: 1),
        horizontalInside: pw.BorderSide(color: PdfColor.fromHex('e2e8f0'), width: 0.5),
      ),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('f1f5f9')),
          children: [
            _buildEnhancedTableHeader('#', font),
            _buildEnhancedTableHeader('Description', font),
            _buildEnhancedTableHeader('Amount', font),
            _buildEnhancedTableHeader('Category', font),
            _buildEnhancedTableHeader('Date', font),
          ],
        ),
        ...expenses.asMap().entries.map((entry) {
          final i = entry.key;
          final exp = entry.value;
          final title = (exp['title'] as String?) ?? 'Unknown';
          final amount = (exp['amount'] as num?)?.toDouble() ?? 0;
          final category = (exp['category'] as String?) ?? 'Other';
          final date = _formatDate(exp['date']);
          final isEven = i.isEven;

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: isEven ? PdfColor.fromHex('ffffff') : PdfColor.fromHex('f8fafc')),
            children: [
              _buildEnhancedTableCell('${i + 1}', font),
              _buildEnhancedTableCell(title, font),
              _buildEnhancedTableCell(_formatCurrency(amount), font, align: pw.TextAlign.right),
              _buildEnhancedTableCell(category, font),
              _buildEnhancedTableCell(date, font),
            ],
          );
        }).toList(),
      ],
    );
  }
}
