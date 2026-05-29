# Complete SliceIt Notification System Guide

## 🎯 Overview

SliceIt now has a **complete automatic notification system** with user preferences and on-demand reminders.

---

## 📱 Client-Side (Flutter App)

### 1. Notification Preferences
**Location:** Profile Screen → Notifications

Users can control:
- **Push Notifications** (Master toggle) - Turns all notifications on/off
- **Settlement Reminders** - Payment due notifications
- **Group Invites** - When added to a group
- **Expense Updates** - New expenses in groups
- **Payment Reminders** - Payment confirmations

### 2. How It Works
```
Firebase sends notification
        ↓
App receives FCM message
        ↓
Check user's preferences
        ↓
Display notification (if enabled)
        ↓
OR silently filter (if disabled)
```

### 3. Key Files Modified
- `lib/services/notification_preferences.dart` - Preference provider
- `lib/services/notification_service.dart` - Preference checking logic
- `lib/screens/profile_screen.dart` - Settings UI
- `lib/main.dart` - Provider integration
- `lib/screens/group_detail_screen.dart` - Send reminders button

---

## ⚙️ Backend (Firebase Cloud Functions)

### 1. Automatic Triggers

#### `notifyExpenseAdded`
- **When:** New expense added to group
- **Who:** All group members except creator
- **Type:** `expense_update`
- **Message:** "New expense in [Group] - [Creator] added ₹[Amount]"

#### `notifyGroupInvite`
- **When:** Members added to group
- **Who:** Newly added members
- **Type:** `group_invite`
- **Message:** "You were added to [Group Name]"

#### `notifyPaymentReceived`
- **When:** Transaction marked as SUCCESS
- **Who:** Payment payer
- **Type:** `payment_reminder`
- **Message:** "Payment Received - ₹[Amount] payment confirmed"

### 2. On-Demand Trigger

#### `notifySettlementReminder` (Callable)
- **Where:** Group Detail Screen → Balances Tab → "Send Settlement Reminders"
- **Type:** `settlement_reminder`
- **Recipients:** Members who owe money
- **Message:** "You owe ₹[Amount] in [Group Name]"

---

## 🚀 Complete Feature Flow

### Scenario 1: Friend Added to Group
```
You add friend to group
    ↓
Cloud Function: notifyGroupInvite triggers
    ↓
Sends FCM with type: "group_invite"
    ↓
Friend's app receives notification
    ↓
Checks preference: "Group Invites" enabled?
    ↓
YES → Shows notification ✅
NO → Silently discarded ✅
```

### Scenario 2: Send Settlement Reminders
```
You open Group Details
    ↓
Go to "Balances" tab
    ↓
Click "Send Settlement Reminders" button
    ↓
App collects all expense IDs
    ↓
Calls Cloud Function: notifySettlementReminder
    ↓
Function identifies who owes money
    ↓
Sends notifications to debtors
    ↓
Each person's app checks their preferences
    ↓
Notifications display (if enabled)
```

### Scenario 3: New Expense Added
```
Member A adds expense to group
    ↓
Cloud Function: notifyExpenseAdded triggers
    ↓
Sends to all members except Member A
    ↓
Members' apps receive with type: "expense_update"
    ↓
Each checks "Expense Updates" preference
    ↓
Notifications display (if enabled)
```

---

## 📊 Notification Types Reference

| Type | Preference | Default | Cloud Function |
|------|-----------|---------|-----------------|
| `expense_update` | Expense Updates | Enabled | notifyExpenseAdded |
| `group_invite` | Group Invites | Enabled | notifyGroupInvite |
| `settlement_reminder` | Settlement Reminders | Enabled | notifySettlementReminder |
| `payment_reminder` | Payment Reminders | Enabled | notifyPaymentReceived |

---

## 🔧 Implementation Details

### Data Flow
```
Firestore Event/Function Call
        ↓
Cloud Functions process event
        ↓
Fetch user FCM tokens
        ↓
Build notification payload with type
        ↓
Send via Firebase Cloud Messaging
        ↓
Device receives notification
        ↓
App checks NotificationPreferences
        ↓
App displays or filters based on type
```

### Storage
- **Preferences:** Local device (SharedPreferences)
- **FCM Tokens:** Firestore (`users/{uid}/fcmToken`)
- **Notification History:** App logs (optional future feature)

---

## 📋 Files Changed

### Flutter App
1. **NEW:** `lib/services/notification_preferences.dart`
   - NotificationPreferences provider
   - Handles preference loading/saving
   - Checks if notification should display

2. **UPDATED:** `lib/services/notification_service.dart`
   - Integrated NotificationPreferences
   - Added preference checking before display

3. **UPDATED:** `lib/screens/profile_screen.dart`
   - Added Notifications settings UI
   - Toggle switches for each notification type

4. **UPDATED:** `lib/main.dart`
   - Added NotificationPreferences to providers
   - Initialize preferences on app start

5. **UPDATED:** `lib/screens/group_detail_screen.dart`
   - Added "Send Settlement Reminders" button
   - Added _sendSettlementReminders() method

### Backend
1. **UPDATED:** `functions/index.js`
   - Enhanced `notifyExpenseAdded` with type field
   - Added `notifyGroupInvite` trigger
   - Added `notifySettlementReminder` callable function
   - Added `notifyPaymentReceived` trigger

---

## 🚀 Deployment

### Step 1: Deploy Cloud Functions
```bash
cd /Users/deepansh/StudioProjects/SliceIt
firebase deploy --only functions
```

### Step 2: Rebuild App
The app code is already updated. Just rebuild/redeploy the Flutter app to devices.

### Step 3: Verify
1. Open Profile → Notifications
2. Toggle preferences
3. Settings persist after restart
4. When friends are added to groups, they receive notifications

---

## ✅ Testing Checklist

### Automatic Notifications
- [ ] Add expense to group → Others receive notification
- [ ] Add member to group → New member gets notification
- [ ] Mark payment as SUCCESS → Payer gets notification

### Preferences
- [ ] Disable "Expense Updates" → No notification for new expenses
- [ ] Disable "Group Invites" → No notification when added to group
- [ ] Master toggle OFF → No notifications at all
- [ ] Settings persist after app restart

### On-Demand Reminders
- [ ] Open group detail → Balances tab
- [ ] Click "Send Settlement Reminders"
- [ ] See loading dialog
- [ ] Get success message with count
- [ ] Members receive notifications (if preferences enabled)

---

## 🔐 Security Notes

- Notifications filtered on **client-side** for privacy
- Backend always sends (doesn't know user preferences)
- FCM tokens are secure and device-specific
- No sensitive data in notification body

---

## 🎨 User Experience

### What Users See

**In Profile Screen:**
```
Notifications
├── Push Notifications [Toggle]
├── When ON:
│   ├── Settlement Reminders [Toggle]
│   ├── Group Invites [Toggle]
│   ├── Expense Updates [Toggle]
│   └── Payment Reminders [Toggle]
└── When OFF: (All sub-toggles hidden)
```

**In Group Detail Screen (Balances Tab):**
```
[Send Settlement Reminders] (Button)
├── Pending Settlements
├── User A owes User B ₹500
├── User C owes User B ₹200
└── ...
```

---

## 📈 Future Enhancements

- [ ] Notification history/log
- [ ] Do Not Disturb hours
- [ ] Sound/vibration customization
- [ ] Notification badges
- [ ] Email notifications as fallback
- [ ] Scheduled reminders
- [ ] Notification priority levels
- [ ] Read receipts
