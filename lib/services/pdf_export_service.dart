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
    final escapedGroupName = _escapeHtml(groupName);

    // Build expenses table rows
    final buffer = StringBuffer();
    for (int i = 0; i < expenses.length; i++) {
      final exp = expenses[i];
      final title = _escapeHtml((exp['title'] as String?) ?? 'Unknown');
      final amount = (exp['amount'] as num?)?.toDouble() ?? 0;
      final paidBy = _escapeHtml(((exp['paidBy'] as String?) ?? 'Unknown').split('@').first);
      final date = _formatDate(exp['date']);

      buffer.write('''
        <tr>
          <td>${i + 1}</td>
          <td>$title</td>
          <td>${_currencyFormat.format(amount)}</td>
          <td>$paidBy</td>
          <td>$date</td>
        </tr>
      ''');
    }
    final expensesRows = buffer.toString();

    // Build members summary table rows
    final membersBuffer = StringBuffer();
    for (var entry in balances.entries) {
      final name = _escapeHtml(entry.key.split('@').first);
      final val = entry.value;
      final statusText = val > 0 ? 'Owed Money' : (val < 0 ? 'Owes Money' : 'Settled');
      final badgeClass = val > 0 ? 'owed' : (val < 0 ? 'owes' : 'settled');

      membersBuffer.write('''
        <tr>
          <td>$name</td>
          <td>${_currencyFormat.format(val)}</td>
          <td><span class="badge $badgeClass">$statusText</span></td>
        </tr>
      ''');
    }
    final membersRows = membersBuffer.toString();

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      color: #1f2937;
      margin: 0;
      padding: 30px;
      font-size: 13px;
      line-height: 1.5;
    }
    .header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-bottom: 2px solid #e5e7eb;
      padding-bottom: 15px;
      margin-bottom: 25px;
    }
    .logo {
      font-size: 26px;
      font-weight: 800;
      color: #3C78D8;
    }
    .title-sub {
      font-size: 12px;
      color: #6b7280;
      margin-top: 4px;
    }
    .date-box {
      text-align: right;
    }
    .date-label {
      font-size: 10px;
      color: #6b7280;
      text-transform: uppercase;
      font-weight: bold;
      letter-spacing: 0.5px;
    }
    .date-value {
      font-size: 14px;
      font-weight: 700;
      color: #111827;
      margin-top: 2px;
    }
    .group-card {
      background-color: #f9fafb;
      border: 1px solid #e5e7eb;
      border-radius: 8px;
      padding: 16px;
      margin-bottom: 20px;
    }
    .group-title {
      font-size: 18px;
      font-weight: 700;
      color: #111827;
      margin: 0 0 8px 0;
    }
    .group-meta {
      display: flex;
      justify-content: space-between;
      font-size: 12px;
      color: #4b5563;
    }
    .bento-grid {
      display: flex;
      gap: 15px;
      margin-bottom: 30px;
    }
    .bento-card {
      flex: 1;
      border-radius: 8px;
      padding: 15px;
      text-align: center;
      background: #ffffff;
      box-shadow: 0 1px 3px rgba(0,0,0,0.05);
    }
    .bento-card.blue { border: 1.5px solid #3c78d8; border-top: 6px solid #3c78d8; }
    .bento-card.green { border: 1.5px solid #34a853; border-top: 6px solid #34a853; }
    .bento-card.red { border: 1.5px solid #ea4335; border-top: 6px solid #ea4335; }
    .bento-label {
      font-size: 9px;
      font-weight: 800;
      color: #6b7280;
      text-transform: uppercase;
      margin-bottom: 6px;
      letter-spacing: 0.5px;
    }
    .bento-value {
      font-size: 18px;
      font-weight: 800;
    }
    .bento-card.blue .bento-value { color: #3c78d8; }
    .bento-card.green .bento-value { color: #34a853; }
    .bento-card.red .bento-value { color: #ea4335; }
    
    h2 {
      font-size: 15px;
      font-weight: 700;
      margin: 25px 0 12px 0;
      color: #111827;
      border-left: 4px solid #3c78d8;
      padding-left: 8px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 25px;
      border-radius: 8px;
      overflow: hidden;
      box-shadow: 0 1px 3px rgba(0,0,0,0.02);
      border: 1px solid #e5e7eb;
    }
    th {
      background-color: #1f2937;
      color: #ffffff;
      font-weight: 600;
      text-align: left;
      padding: 12px;
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    td {
      padding: 12px;
      border-bottom: 1px solid #e5e7eb;
      color: #374151;
    }
    tr:last-child td {
      border-bottom: none;
    }
    tr:nth-child(even) {
      background-color: #fcfdfd;
    }
    .text-right {
      text-align: right;
    }
    .badge {
      display: inline-block;
      padding: 4px 8px;
      border-radius: 12px;
      font-size: 10px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.3px;
    }
    .badge.owed {
      background-color: #e6f4ea;
      color: #137333;
    }
    .badge.owes {
      background-color: #fce8e6;
      color: #c5221f;
    }
    .badge.settled {
      background-color: #f1f3f4;
      color: #5f6368;
    }
    .footer {
      border-top: 1px solid #e5e7eb;
      padding-top: 15px;
      margin-top: 40px;
      text-align: center;
      font-size: 10px;
      color: #9ca3af;
    }
  </style>
</head>
<body>
  <div class="header">
    <div>
      <div class="logo">🍕 SliceIt</div>
      <div class="title-sub">Group Expense Report</div>
    </div>
    <div class="date-box">
      <div class="date-label">Report Date</div>
      <div class="date-value">${_dateFormat.format(DateTime.now())}</div>
    </div>
  </div>

  <div class="group-card">
    <div class="group-title">GROUP: $escapedGroupName</div>
    <div class="group-meta">
      <span>Members: ${balances.length}</span>
      <span>Total Expenses: ${expenses.length}</span>
    </div>
  </div>

  <div class="bento-grid">
    <div class="bento-card blue">
      <div class="bento-label">Total Spent</div>
      <div class="bento-value">${_currencyFormat.format(totalAmount)}</div>
    </div>
    <div class="bento-card green">
      <div class="bento-label">Avg Per Expense</div>
      <div class="bento-value">${_currencyFormat.format(expenses.isEmpty ? 0 : totalAmount / expenses.length)}</div>
    </div>
    <div class="bento-card red">
      <div class="bento-label">Total Members</div>
      <div class="bento-value">${balances.length}</div>
    </div>
  </div>

  <h2>Expense Breakdown</h2>
  <table>
    <thead>
      <tr>
        <th style="width: 8%;">#</th>
        <th style="width: 42%;">Title</th>
        <th style="width: 18%;">Amount</th>
        <th style="width: 18%;">Paid By</th>
        <th style="width: 14%;">Date</th>
      </tr>
    </thead>
    <tbody>
      $expensesRows
    </tbody>
  </table>

  <h2>Member Summary</h2>
  <table>
    <thead>
      <tr>
        <th style="width: 45%;">Member</th>
        <th style="width: 30%;">Balance</th>
        <th style="width: 25%;">Status</th>
      </tr>
    </thead>
    <tbody>
      $membersRows
    </tbody>
  </table>

  <div class="footer">
    Generated by SliceIt • Split bills effortlessly
  </div>
</body>
</html>
    ''';

    final pdfBytes = await Printing.convertHtml(
      html: htmlContent,
      format: PdfPageFormat.a4,
    );

    if (share) {
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'sliceit_${groupName.toLowerCase().replaceAll(' ', '_')}_invoice_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } else {
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'sliceit_${groupName.toLowerCase().replaceAll(' ', '_')}_invoice_${DateTime.now().millisecondsSinceEpoch}',
      );
    }
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
    final escapedUserName = _escapeHtml(userName);

    // Build expenses table rows
    final buffer = StringBuffer();
    for (int i = 0; i < expenses.length; i++) {
      final exp = expenses[i];
      final title = _escapeHtml((exp['title'] as String?) ?? 'Unknown');
      final amount = (exp['amount'] as num?)?.toDouble() ?? 0;
      final category = _escapeHtml((exp['category'] as String?) ?? 'Other');
      final date = _formatDate(exp['date']);

      buffer.write('''
        <tr>
          <td>${i + 1}</td>
          <td>$title</td>
          <td>${_currencyFormat.format(amount)}</td>
          <td>$category</td>
          <td>$date</td>
        </tr>
      ''');
    }
    final expensesRows = buffer.toString();

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      color: #1f2937;
      margin: 0;
      padding: 30px;
      font-size: 13px;
      line-height: 1.5;
    }
    .header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-bottom: 2px solid #e5e7eb;
      padding-bottom: 15px;
      margin-bottom: 25px;
    }
    .logo {
      font-size: 26px;
      font-weight: 800;
      color: #3C78D8;
    }
    .title-sub {
      font-size: 12px;
      color: #6b7280;
      margin-top: 4px;
    }
    .date-box {
      text-align: right;
    }
    .date-label {
      font-size: 10px;
      color: #6b7280;
      text-transform: uppercase;
      font-weight: bold;
      letter-spacing: 0.5px;
    }
    .date-value {
      font-size: 14px;
      font-weight: 700;
      color: #111827;
      margin-top: 2px;
    }
    .user-card {
      background-color: #f9fafb;
      border: 1px solid #e5e7eb;
      border-radius: 8px;
      padding: 16px;
      margin-bottom: 20px;
    }
    .user-name {
      font-size: 18px;
      font-weight: 700;
      color: #111827;
      margin: 0 0 8px 0;
    }
    .user-meta {
      font-size: 12px;
      color: #4b5563;
    }
    .bento-grid {
      display: flex;
      gap: 15px;
      margin-bottom: 30px;
    }
    .bento-card {
      flex: 1;
      border-radius: 8px;
      padding: 15px;
      text-align: center;
      background: #ffffff;
      box-shadow: 0 1px 3px rgba(0,0,0,0.05);
    }
    .bento-card.blue { border: 1.5px solid #3c78d8; border-top: 6px solid #3c78d8; }
    .bento-card.green { border: 1.5px solid #34a853; border-top: 6px solid #34a853; }
    .bento-card.red { border: 1.5px solid #ea4335; border-top: 6px solid #ea4335; }
    .bento-label {
      font-size: 9px;
      font-weight: 800;
      color: #6b7280;
      text-transform: uppercase;
      margin-bottom: 6px;
      letter-spacing: 0.5px;
    }
    .bento-value {
      font-size: 18px;
      font-weight: 800;
    }
    .bento-card.blue .bento-value { color: #3c78d8; }
    .bento-card.green .bento-value { color: #34a853; }
    .bento-card.red .bento-value { color: #ea4335; }
    
    h2 {
      font-size: 15px;
      font-weight: 700;
      margin: 25px 0 12px 0;
      color: #111827;
      border-left: 4px solid #3c78d8;
      padding-left: 8px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 25px;
      border-radius: 8px;
      overflow: hidden;
      box-shadow: 0 1px 3px rgba(0,0,0,0.02);
      border: 1px solid #e5e7eb;
    }
    th {
      background-color: #1f2937;
      color: #ffffff;
      font-weight: 600;
      text-align: left;
      padding: 12px;
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    td {
      padding: 12px;
      border-bottom: 1px solid #e5e7eb;
      color: #374151;
    }
    tr:last-child td {
      border-bottom: none;
    }
    tr:nth-child(even) {
      background-color: #fcfdfd;
    }
    .footer {
      border-top: 1px solid #e5e7eb;
      padding-top: 15px;
      margin-top: 40px;
      text-align: center;
      font-size: 10px;
      color: #9ca3af;
    }
  </style>
</head>
<body>
  <div class="header">
    <div>
      <div class="logo">🍕 SliceIt</div>
      <div class="title-sub">Personal Expense Report</div>
    </div>
    <div class="date-box">
      <div class="date-label">Report Date</div>
      <div class="date-value">${_dateFormat.format(DateTime.now())}</div>
    </div>
  </div>

  <div class="user-card">
    <div class="user-name">USER: $escapedUserName</div>
    <div class="user-meta">
      <span>Personal Expense Tracking Report</span>
    </div>
  </div>

  <div class="bento-grid">
    <div class="bento-card blue">
      <div class="bento-label">Total Spent</div>
      <div class="bento-value">${_currencyFormat.format(totalSpent)}</div>
    </div>
    <div class="bento-card green">
      <div class="bento-label">Expense Count</div>
      <div class="bento-value">${expenses.length}</div>
    </div>
    <div class="bento-card red">
      <div class="bento-label">Avg Expense</div>
      <div class="bento-value">${_currencyFormat.format(expenses.isEmpty ? 0 : totalSpent / expenses.length)}</div>
    </div>
  </div>

  <h2>Expense Details</h2>
  <table>
    <thead>
      <tr>
        <th style="width: 8%;">#</th>
        <th style="width: 42%;">Title</th>
        <th style="width: 18%;">Amount</th>
        <th style="width: 18%;">Category</th>
        <th style="width: 14%;">Date</th>
      </tr>
    </thead>
    <tbody>
      $expensesRows
    </tbody>
  </table>

  <div class="footer">
    Generated by SliceIt • Split bills effortlessly
  </div>
</body>
</html>
    ''';

    final pdfBytes = await Printing.convertHtml(
      html: htmlContent,
      format: PdfPageFormat.a4,
    );

    if (share) {
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'sliceit_${userName.toLowerCase().replaceAll(' ', '_')}_statement_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } else {
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'sliceit_${userName.toLowerCase().replaceAll(' ', '_')}_statement_${DateTime.now().millisecondsSinceEpoch}',
      );
    }
  }
}
