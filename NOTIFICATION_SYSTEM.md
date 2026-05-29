# SliceIt Notification System

## Overview
Complete automatic notification system with client-side preference controls.

## How It Works

### 1. **Automatic Triggers** (Backend - Firebase Cloud Functions)

#### `notifyExpenseAdded` ✅ EXISTING
- **Triggered:** When a new expense is added to a group
- **Type:** `expense_update`
- **Recipients:** All group members except the expense creator
- **Message:** "New expense in [Group Name] - [Creator Name] added ₹[Amount]"

#### `notifyGroupInvite` ✅ NEW
- **Triggered:** When members are added to a group
- **Type:** `group_invite`
- **Recipients:** Newly added members
- **Message:** "You were added to [Group Name]"

#### `notifySettlementReminder` ✅ NEW
- **Triggered:** Manual call when settling bills
- **Type:** `settlement_reminder`
- **Recipients:** Members who owe money
- **Message:** "You owe ₹[Amount] in [Group Name]"
- **Usage:** Call this Cloud Function when generating settlement reports

#### `notifyPaymentReceived` ✅ NEW
- **Triggered:** When a transaction status changes to SUCCESS
- **Type:** `payment_reminder`
- **Recipients:** Payer of the transaction
- **Message:** "Payment Received - ₹[Amount] payment confirmed"

### 2. **User Preferences** (Client - Flutter App)

Located in Profile Screen under "Notifications":

- **Push Notifications** (Master toggle)
  - When OFF: All notifications are disabled
  - When ON: Individual categories can be controlled

- **Settlement Reminders** (settlement_reminder)
  - Controls when payment reminders appear
  - Default: Enabled

- **Group Invites** (group_invite)
  - Controls group invitation notifications
  - Default: Enabled

- **Expense Updates** (expense_update)
  - Controls when new expenses trigger notifications
  - Default: Enabled

- **Payment Reminders** (payment_reminder)
  - Controls payment confirmation notifications
  - Default: Enabled

## Complete Flow Example

### When You Add a Friend to a Split:

1. **You** create a new group and add friend
   ↓
2. **Cloud Function** `notifyGroupInvite` triggers
   ↓
3. System checks friend's FCM token and sends notification with:
   - `type: "group_invite"`
   - Group name
   ↓
4. **Friend's app** receives notification
   ↓
5. App checks friend's preferences:
   - Is "Push Notifications" enabled? Yes
   - Is "Group Invites" enabled? Yes
   ↓
6. **Notification displays** on friend's device ✅

### If Friend Disabled "Group Invites":
- Notification is sent to their device
- App filters it based on preferences
- **Notification is silently discarded** ✅

## Notification Types & Preference Keys

| Type | Preference Key | Description |
|------|---|---|
| `expense_update` | `expense_updates_enabled` | New expenses in group |
| `group_invite` | `group_invites_enabled` | Added to group |
| `settlement_reminder` | `settlement_reminders_enabled` | Payment reminders |
| `payment_reminder` | `payment_reminders_enabled` | Payment confirmations |

## Deployment

### Deploy to Firebase:

```bash
cd functions
firebase deploy --only functions
```

### Local Testing:

```bash
cd functions
npm install
firebase emulators:start --only functions
```

## Data Flow

```
Firestore Event
    ↓
Cloud Function Triggered
    ↓
Fetch User FCM Token
    ↓
Build Message with Type
    ↓
Send via Firebase Cloud Messaging
    ↓
Device receives notification
    ↓
App checks NotificationPreferences
    ↓
Display or Filter notification
```

## Files Modified

- `lib/services/notification_preferences.dart` - Preference provider
- `lib/services/notification_service.dart` - Preference checking
- `lib/screens/profile_screen.dart` - UI controls
- `lib/main.dart` - Provider integration
- `functions/index.js` - Cloud Function triggers

## Future Enhancements

- [ ] Scheduled reminders (recurring notifications)
- [ ] Notification history
- [ ] Do Not Disturb hours
- [ ] Notification sound customization
- [ ] Notification badges
