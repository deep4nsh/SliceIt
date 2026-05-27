# SliceIt Feature Implementation Guide

## Priority 1: Percentage-Based Splits (Quickest Win)

### Changes Needed:

#### 1. Update `participant_model.dart`
```dart
class Participant {
  final String email;
  bool isIncluded;
  double amount;
  double? percentage;  // NEW: Add percentage field
  
  Participant({
    required this.email,
    this.isIncluded = true,
    this.amount = 0.0,
    this.percentage,
  });
}
```

#### 2. Update `create_split_bill_screen.dart`
```dart
enum SplitType { equal, unequal, percentage, itemized }  // ADD percentage

// In _createSplit(), add validation:
if (_splitType == SplitType.percentage) {
  double totalPercent = 0;
  for (final p in includedParticipants) {
    totalPercent += (p.percentage ?? 0);
  }
  if ((totalPercent - 100).abs() > 0.1) {
    _showSnackBar('Percentages must sum to 100% (current: ${totalPercent.toStringAsFixed(1)}%)');
    return;
  }
  // Calculate amounts from percentages
  final total = double.parse(_amountController.text);
  for (final p in includedParticipants) {
    p.amount = (total * (p.percentage ?? 0)) / 100;
  }
}

// When saving to Firestore:
'splitType': _splitType.toString(),
'amounts': {for (var p in includedParticipants) p.email.trim(): p.amount},
'percentages': (_splitType == SplitType.percentage) 
    ? {for (var p in includedParticipants) p.email.trim(): p.percentage ?? 0} 
    : {},
```

#### 3. Update Split Bill UI
Add a percentage input field in the unequal section:
```dart
if (_splitType == SplitType.percentage) {
  TextFormField(
    initialValue: p.percentage?.toStringAsFixed(1) ?? '0',
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onChanged: (val) {
      setState(() {
        p.percentage = double.tryParse(val) ?? 0;
      });
    },
    decoration: InputDecoration(
      suffixText: '%',
      label: Text('${p.email.split('@').first} Share'),
    ),
  );
}
```

---

## Priority 2: Real-Time Notifications (High Impact)

### Required Changes:

#### 1. Update `notification_service.dart`
Complete the notification service implementation:
```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> initialize() async {
    // Request permissions
    await _messaging.requestPermission();
    
    // Get FCM token and save to user's Firestore doc
    final token = await _messaging.getToken();
    if (token != null) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _firestore.collection('users').doc(uid).update({
          'fcmToken': token,
        });
      }
    }
    
    // Listen for messages in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Show local notification
      _showLocalNotification(message);
    });
  }

  static Future<void> sendExpenseNotification({
    required String expenseTitle,
    required double amount,
    required String creatorName,
    required List<String> groupMemberTokens,
  }) async {
    // Use Cloud Function to send notifications
    // This prevents exposing FCM credentials on client
  }

  static void _showLocalNotification(RemoteMessage message) {
    // Show in-app notification
  }
}
```

#### 2. Create Cloud Function for sending notifications
In `functions/index.js`:
```javascript
const functions = require("firebase-functions");
const admin = require("firebase-admin");

exports.notifyExpenseAdded = functions.firestore
  .document('groups/{groupId}/expenses/{expenseId}')
  .onCreate(async (snap, context) => {
    const expense = snap.data();
    const groupId = context.params.groupId;
    
    // Get group members
    const groupDoc = await admin.firestore()
      .collection('groups').doc(groupId).get();
    const members = groupDoc.data().members || [];
    
    // Get FCM tokens for all members except creator
    const tokens = [];
    for (const memberId of members) {
      if (memberId !== expense.paidBy) {
        const userDoc = await admin.firestore()
          .collection('users').doc(memberId).get();
        if (userDoc.data()?.fcmToken) {
          tokens.push(userDoc.data().fcmToken);
        }
      }
    }
    
    if (tokens.length === 0) return;
    
    // Get creator name
    const creatorDoc = await admin.firestore()
      .collection('users').doc(expense.paidBy).get();
    const creatorName = creatorDoc.data()?.name || 'Someone';
    
    // Send notifications
    const message = {
      notification: {
        title: `New expense in group: ${groupDoc.data().name}`,
        body: `${creatorName} added ₹${expense.amount} - ${expense.title}`,
      },
      data: {
        groupId: groupId,
        expenseId: snap.id,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
    };
    
    return admin.messaging().sendMulticast({
      tokens: tokens,
      notification: message.notification,
      data: message.data,
    });
  });
```

#### 3. Initialize in `main.dart`
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.initialize();  // ADD THIS
  runApp(const MyApp());
}
```

---

## Priority 3: Phone Book/Contact Sync

### Implementation:

#### 1. Add to `pubspec.yaml`
```yaml
dependencies:
  contacts_service: ^0.6.3
  permission_handler: ^11.4.4
```

#### 2. Create `services/contact_sync_service.dart`
```dart
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactSyncService {
  static Future<List<Contact>> getPhoneContacts() async {
    final status = await Permission.contacts.request();
    
    if (status.isDenied) {
      throw Exception('Contact permission denied');
    }
    
    if (status.isPermanentlyDenied) {
      openAppSettings();
      throw Exception('Contact permission permanently denied');
    }
    
    return await ContactsService.getContacts();
  }

  static Future<List<Map<String, String>>> getContactEmails() async {
    try {
      final contacts = await getPhoneContacts();
      final emails = <Map<String, String>>[];
      
      for (var contact in contacts) {
        if (contact.emails?.isNotEmpty == true) {
          for (var email in contact.emails ?? []) {
            emails.add({
              'name': contact.displayName ?? '',
              'email': email.value ?? '',
            });
          }
        }
      }
      
      return emails;
    } catch (e) {
      debugPrint('Error fetching contacts: $e');
      return [];
    }
  }
}
```

#### 3. Update `add_friend_screen.dart`
```dart
// Add button to sync contacts
CustomButton(
  text: 'Sync Phone Contacts',
  icon: Icons.contacts,
  onPressed: () async {
    try {
      final contacts = await ContactSyncService.getContactEmails();
      setState(() {
        suggestedContacts = contacts;
      });
    } catch (e) {
      _showSnackBar('Failed to sync contacts: $e');
    }
  },
)
```

---

## Priority 4: Offline Mode with Local-First Sync

### Implementation:

#### 1. Add to `pubspec.yaml`
```yaml
dependencies:
  hive: ^2.2.3
  hive_flutter: ^1.1.0

dev_dependencies:
  hive_generator: ^2.0.0
  build_runner: ^2.4.0
```

#### 2. Create `services/offline_service.dart`
```dart
import 'package:hive_flutter/hive_flutter.dart';

class OfflineService {
  static late Box<Map> _expensesBox;
  static late Box<String> _syncStatusBox;

  static Future<void> initialize() async {
    await Hive.initFlutter();
    _expensesBox = await Hive.openBox<Map>('offline_expenses');
    _syncStatusBox = await Hive.openBox<String>('sync_status');
  }

  static Future<void> saveExpenseOffline(Map<String, dynamic> expense) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    await _expensesBox.put(timestamp, expense);
    await _syncStatusBox.put(timestamp, 'pending');
  }

  static Future<List<Map>> getPendingExpenses() async {
    final pending = <Map>[];
    for (var entry in _expensesBox.toMap().entries) {
      if (_syncStatusBox.get(entry.key) == 'pending') {
        pending.add(entry.value);
      }
    }
    return pending;
  }

  static Future<void> markAsSynced(String timestamp) async {
    await _syncStatusBox.put(timestamp, 'synced');
    await _expensesBox.delete(timestamp);
  }
}

// In CreateSplitBillScreen._createSplit():
try {
  // Try to save to Firestore
  await _firestore.collection('split_bills').add(billData);
} catch (e) {
  // If offline, save locally
  if (e.toString().contains('PlatformException') || !await _isConnected()) {
    await OfflineService.saveExpenseOffline(billData);
    _showSnackBar('Saved offline. Will sync when online.');
  }
}
```

#### 3. Sync Background Task
```dart
class SyncManager {
  static Future<void> syncPendingExpenses() async {
    final pending = await OfflineService.getPendingExpenses();
    
    for (var expense in pending) {
      try {
        await _firestore.collection('split_bills').add(expense);
        await OfflineService.markAsSynced(expense['_timestamp']);
      } catch (e) {
        debugPrint('Sync failed: $e');
      }
    }
  }
}
```

---

## Priority 5: PDF Export & Statements

### Implementation:

#### 1. Add to `pubspec.yaml`
```yaml
dependencies:
  pdf: ^3.10.4
  printing: ^5.11.0
  path_provider: ^2.1.0
```

#### 2. Create `services/pdf_export_service.dart`
```dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfExportService {
  static Future<void> exportGroupStatement({
    required String groupName,
    required List<Map<String, dynamic>> expenses,
    required Map<String, double> balances,
  }) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Group Statement: $groupName',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              
              pw.Text('Balances:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              ...balances.entries.map((e) => pw.Text('${e.key}: ₹${e.value.toStringAsFixed(2)}')),
              
              pw.SizedBox(height: 30),
              pw.Text('Expenses:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              ...expenses.map((exp) => pw.Text(
                '${exp['title']} - ₹${exp['amount']} (${exp['paidBy']})'
              )),
            ],
          );
        },
      ),
    );
    
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'group_statement.pdf');
  }
}
```

#### 3. Use in Group Detail Screen
```dart
// Add button in AppBar or FAB
IconButton(
  icon: const Icon(Icons.download),
  onPressed: () async {
    await PdfExportService.exportGroupStatement(
      groupName: groupName,
      expenses: groupExpenses,
      balances: calculations.balances,
    );
  },
)
```

---

## Priority 6: Group Analytics Dashboard

### Implementation:

#### 1. Create `services/group_analytics_service.dart`
```dart
class GroupAnalyticsService {
  static Map<String, dynamic> calculateGroupAnalytics(List<Map<String, dynamic>> expenses) {
    // Total spending by person
    final spendingByPerson = <String, double>{};
    
    for (var expense in expenses) {
      final amount = (expense['amount'] as num).toDouble();
      final paidBy = expense['paidBy'] as String;
      
      spendingByPerson[paidBy] = (spendingByPerson[paidBy] ?? 0) + amount;
    }
    
    // Percentage contribution
    final totalSpent = spendingByPerson.values.fold(0.0, (a, b) => a + b);
    final percentageByPerson = spendingByPerson.map(
      (person, amount) => MapEntry(person, (amount / totalSpent) * 100),
    );
    
    return {
      'spendingByPerson': spendingByPerson,
      'percentageByPerson': percentageByPerson,
      'totalSpent': totalSpent,
      'expenseCount': expenses.length,
    };
  }
}
```

#### 2. Add Analytics Tab in Group Detail
```dart
// In GroupDetailScreen, add PieChart from fl_chart
PieChart(
  PieChartData(
    sections: [
      for (var entry in analytics['percentageByPerson'].entries)
        PieChartSectionData(
          value: entry.value,
          title: '${entry.key}\n${entry.value.toStringAsFixed(1)}%',
        ),
    ],
  ),
)
```

---

## Priority 7: Settlement History & Proof

### Implementation:

#### 1. Create `models/settlement_model.dart`
```dart
class Settlement {
  final String id;
  final String fromUser;
  final String toUser;
  final double amount;
  final DateTime settledAt;
  final String? proofUrl;
  final String? note;

  Settlement({
    required this.id,
    required this.fromUser,
    required this.toUser,
    required this.amount,
    required this.settledAt,
    this.proofUrl,
    this.note,
  });

  Map<String, dynamic> toMap() => {
    'fromUser': fromUser,
    'toUser': toUser,
    'amount': amount,
    'settledAt': Timestamp.fromDate(settledAt),
    'proofUrl': proofUrl,
    'note': note,
  };
}
```

#### 2. Create Settlement Screen
```dart
// Create new screen: settlement_history_screen.dart
// Show all past settlements with timestamps
// Allow marking new settlements as paid with optional proof upload
```

---

## Testing Checklist

- [ ] Percentage splits sum correctly
- [ ] Notifications arrive for all group members
- [ ] Contact sync shows proper contacts
- [ ] Offline expenses sync when online
- [ ] PDF exports contain correct data
- [ ] Group analytics display properly
- [ ] Settlement history is accurate
