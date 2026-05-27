import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfExportService {
  static final _dateFormat = DateFormat('dd MMM yyyy');
  static final _currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

  static Future<void> exportGroupStatement({
    required String groupName,
    required List<Map<String, dynamic>> expenses,
    required Map<String, double> balances,
  }) async {
    final pdf = pw.Document();

    // Calculate totals
    final totalAmount = expenses.fold<double>(
      0,
      (sum, exp) => sum + ((exp['amount'] as num?)?.toDouble() ?? 0),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Group Expense Statement',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Group: $groupName',
              style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
            ),
            pw.Text(
              'Generated: ${_dateFormat.format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
            pw.Divider(margin: const pw.EdgeInsets.symmetric(vertical: 12)),
          ],
        ),
        build: (context) => [
          // Summary Section
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Summary',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Expenses:', style: const pw.TextStyle(fontSize: 12)),
                    pw.Text(
                      _currencyFormat.format(totalAmount),
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Number of Expenses:', style: const pw.TextStyle(fontSize: 12)),
                    pw.Text(
                      '${expenses.length}',
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Members:', style: const pw.TextStyle(fontSize: 12)),
                    pw.Text(
                      '${balances.length}',
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // Balances Section
          pw.Text(
            'Member Balances',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Member', 'Balance'],
            data: [
              for (var entry in balances.entries)
                [
                  entry.key,
                  _currencyFormat.format(entry.value),
                ],
            ],
            headerStyle: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blue900,
            ),
            rowDecoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300),
              ),
            ),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.all(8),
          ),
          pw.SizedBox(height: 24),

          // Expenses List
          pw.Text(
            'Expense Details',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          if (expenses.isEmpty)
            pw.Text('No expenses recorded', style: const pw.TextStyle(fontSize: 11))
          else
            pw.TableHelper.fromTextArray(
              headers: ['Title', 'Amount', 'Paid By', 'Date'],
              data: [
                for (var exp in expenses)
                  [
                    (exp['title'] as String?) ?? 'Unknown',
                    _currencyFormat.format((exp['amount'] as num?)?.toDouble() ?? 0),
                    (exp['paidBy'] as String?) ?? 'Unknown',
                    exp['date'] != null
                        ? _dateFormat.format((exp['date'] as dynamic) is String
                            ? DateTime.parse(exp['date'] as String)
                            : (exp['date'] as dynamic).toDate?.call() ?? DateTime.now())
                        : 'N/A',
                  ],
              ],
              headerStyle: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue900,
              ),
              rowDecoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300),
                ),
              ),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.all(8),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(1.5),
              },
            ),
        ],
        footer: (context) => pw.Divider(),
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'sliceit_${groupName.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
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
        margin: const pw.EdgeInsets.all(40),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Personal Expense Statement',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'User: $userName',
              style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
            ),
            pw.Text(
              'Generated: ${_dateFormat.format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
            pw.Divider(margin: const pw.EdgeInsets.symmetric(vertical: 12)),
          ],
        ),
        build: (context) => [
          // Summary
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Summary',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Amount Spent:', style: const pw.TextStyle(fontSize: 12)),
                    pw.Text(
                      _currencyFormat.format(totalSpent),
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Number of Expenses:', style: const pw.TextStyle(fontSize: 12)),
                    pw.Text(
                      '${expenses.length}',
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // Expense List
          pw.Text(
            'Expense Details',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          if (expenses.isEmpty)
            pw.Text('No expenses recorded', style: const pw.TextStyle(fontSize: 11))
          else
            pw.TableHelper.fromTextArray(
              headers: ['Title', 'Amount', 'Category', 'Date'],
              data: [
                for (var exp in expenses)
                  [
                    (exp['title'] as String?) ?? 'Unknown',
                    _currencyFormat.format((exp['amount'] as num?)?.toDouble() ?? 0),
                    (exp['category'] as String?) ?? 'Other',
                    exp['date'] != null
                        ? _dateFormat.format((exp['date'] as dynamic) is String
                            ? DateTime.parse(exp['date'] as String)
                            : (exp['date'] as dynamic).toDate?.call() ?? DateTime.now())
                        : 'N/A',
                  ],
              ],
              headerStyle: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue900,
              ),
              rowDecoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300),
                ),
              ),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.all(8),
            ),
        ],
        footer: (context) => pw.Divider(),
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'sliceit_${userName.toLowerCase().replaceAll(' ', '_')}_statement_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}
