import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfExportService {
  static final _dateFormat = DateFormat('dd MMM yyyy');
  static final _timeFormat = DateFormat('HH:mm');
  static final _currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

  static Future<void> exportGroupInvoice({
    required String groupName,
    required List<Map<String, dynamic>> expenses,
    required Map<String, double> balances,
  }) async {
    final totalAmount = expenses.fold<double>(0, (sum, exp) => sum + ((exp['amount'] as num?)?.toDouble() ?? 0));

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '🍕 SliceIt',
                      style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('0x3C78D8')),
                    ),
                    pw.Text(
                      'Group Expense Report',
                      style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Report Date',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                    pw.Text(
                      _dateFormat.format(DateTime.now()),
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Divider(),
            pw.SizedBox(height: 12),
          ],
        ),
        build: (context) => [
          // Group Header
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('0xF3F3F3'),
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'GROUP: $groupName',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('0x1F2937'),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Members: ${balances.length}', style: const pw.TextStyle(fontSize: 11)),
                    pw.Text('Total Expenses: ${expenses.length}', style: const pw.TextStyle(fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Summary Cards
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildSummaryCard(
                  'TOTAL SPENT',
                  _currencyFormat.format(totalAmount),
                  PdfColor.fromHex('0x3C78D8'),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _buildSummaryCard(
                  'AVG PER EXPENSE',
                  _currencyFormat.format(expenses.isEmpty ? 0 : totalAmount / expenses.length),
                  PdfColor.fromHex('0x34A853'),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _buildSummaryCard(
                  'MEMBERS',
                  '${balances.length}',
                  PdfColor.fromHex('0xEA4335'),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 24),

          // Detailed Expenses Table
          pw.Text(
            'EXPENSE BREAKDOWN',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ['#', 'Title', 'Amount', 'Paid By', 'Date'],
            data: [
              for (int i = 0; i < expenses.length; i++)
                [
                  '${i + 1}',
                  (expenses[i]['title'] as String?)?.substring(0, 20) ?? 'Unknown',
                  _currencyFormat.format((expenses[i]['amount'] as num?)?.toDouble() ?? 0),
                  ((expenses[i]['paidBy'] as String?) ?? 'Unknown').split('@').first,
                  _formatDate(expenses[i]['date']),
                ],
            ],
            headerStyle: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex('0x1F2937'),
            ),
            rowDecoration: pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
            ),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.all(8),
            cellHeight: 24,
            columnWidths: {
              0: const pw.FixedColumnWidth(30),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.3),
            },
          ),
          pw.SizedBox(height: 20),

          // Member Settlement Summary
          pw.Text(
            'MEMBER SUMMARY',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ['Member', 'Balance', 'Status'],
            data: [
              for (var entry in balances.entries) ...[
                [
                  entry.key.split('@').first,
                  _currencyFormat.format(entry.value),
                  entry.value > 0 ? 'Owed Money' : (entry.value < 0 ? 'Owes Money' : 'Settled'),
                ],
              ],
            ],
            headerStyle: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex('0x1F2937'),
            ),
            rowDecoration: pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
            ),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.all(8),
          ),
          pw.SizedBox(height: 30),

          // Footer
          pw.Divider(),
          pw.Text(
            'Generated by SliceIt • Split bills effortlessly',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            textAlign: pw.TextAlign.center,
          ),
        ],
        footer: (context) => pw.SizedBox.shrink(),
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'sliceit_${groupName.toLowerCase().replaceAll(' ', '_')}_invoice_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static Future<void> exportGroupStatement({
    required String groupName,
    required List<Map<String, dynamic>> expenses,
    required Map<String, double> balances,
  }) async {
    return exportGroupInvoice(
      groupName: groupName,
      expenses: expenses,
      balances: balances,
    );
  }

  static pw.Widget _buildSummaryCard(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: color),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
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

  static Future<void> exportPersonalStatement({
    required String userName,
    required List<Map<String, dynamic>> expenses,
    required double totalSpent,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '🍕 SliceIt',
                      style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('0x3C78D8')),
                    ),
                    pw.Text(
                      'Personal Expense Report',
                      style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Report Date',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                    pw.Text(
                      _dateFormat.format(DateTime.now()),
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Divider(),
            pw.SizedBox(height: 12),
          ],
        ),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('0xF3F3F3'),
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'USER: $userName',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('0x1F2937'),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Personal Expense Tracking Report',
                  style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          pw.Row(
            children: [
              pw.Expanded(
                child: _buildSummaryCard(
                  'TOTAL SPENT',
                  _currencyFormat.format(totalSpent),
                  PdfColor.fromHex('0x3C78D8'),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _buildSummaryCard(
                  'EXPENSE COUNT',
                  '${expenses.length}',
                  PdfColor.fromHex('0x34A853'),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _buildSummaryCard(
                  'AVG EXPENSE',
                  _currencyFormat.format(expenses.isEmpty ? 0 : totalSpent / expenses.length),
                  PdfColor.fromHex('0xEA4335'),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 24),

          pw.Text(
            'EXPENSE DETAILS',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ['#', 'Title', 'Amount', 'Category', 'Date'],
            data: [
              for (int i = 0; i < expenses.length; i++)
                [
                  '${i + 1}',
                  (expenses[i]['title'] as String?)?.substring(0, 20) ?? 'Unknown',
                  _currencyFormat.format((expenses[i]['amount'] as num?)?.toDouble() ?? 0),
                  (expenses[i]['category'] as String?) ?? 'Other',
                  _formatDate(expenses[i]['date']),
                ],
            ],
            headerStyle: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex('0x1F2937'),
            ),
            rowDecoration: pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
            ),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.all(8),
            cellHeight: 24,
            columnWidths: {
              0: const pw.FixedColumnWidth(30),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(1.3),
            },
          ),
          pw.SizedBox(height: 30),
          pw.Divider(),
          pw.Text(
            'Generated by SliceIt • Split bills effortlessly',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            textAlign: pw.TextAlign.center,
          ),
        ],
        footer: (context) => pw.SizedBox.shrink(),
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'sliceit_${userName.toLowerCase().replaceAll(' ', '_')}_statement_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}
