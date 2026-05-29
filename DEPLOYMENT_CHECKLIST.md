# Deployment Checklist

## ✅ Completed

### Client-Side (Flutter App)
- [x] NotificationPreferences provider created
- [x] NotificationService updated with preference checking
- [x] Profile screen UI with notification settings
- [x] App provider integration
- [x] Local persistence with shared_preferences
- [x] Code compiled successfully on Android device

### Backend (Firebase Cloud Functions)
- [x] Added `notifyGroupInvite` trigger
- [x] Enhanced `notifyExpenseAdded` with type field
- [x] Added `notifySettlementReminder` callable function
- [x] Added `notifyPaymentReceived` trigger
- [x] Syntax validation passed
- [x] All dependencies installed

---

## 📋 Pre-Deployment Steps

### 1. Test Locally (Optional)
```bash
cd functions
firebase emulators:start --only functions
```

### 2. Verify Firebase Project
```bash
firebase projects:list
firebase use <project-id>
```

### 3. Check Function Permissions
Ensure your Firebase project has:
- [ ] Cloud Messaging enabled
- [ ] Firestore database enabled
- [ ] Firebase Auth configured

---

## 🚀 Deploy Cloud Functions

### Deploy to Firebase:
```bash
cd /Users/deepansh/StudioProjects/SliceIt
firebase deploy --only functions
```

### Expected Output:
```
✔ functions[notifyExpenseAdded] deployed successfully
✔ functions[notifyGroupInvite] deployed successfully
✔ functions[notifySettlementReminder] deployed successfully
✔ functions[notifyPaymentReceived] deployed successfully
```

---

## 🧪 Testing After Deployment

### 1. Test Expense Notification
- Create a group with test users
- Add an expense as User A
- User B should receive notification with type: `expense_update`
- Check User B's preferences in Profile → Notifications

### 2. Test Group Invite
- Add User C to the group
- User C should receive notification with type: `group_invite`
- Disable "Group Invites" in preferences
- Add User D → notification should not display

### 3. Test Settlement Reminder (Manual)
```javascript
// In Firebase Console → Functions → notifySettlementReminder
// Call with test data
{
  "groupId": "test-group-id",
  "expenseIds": ["expense-id-1", "expense-id-2"]
}
```

### 4. Test Payment Notification
- Create a transaction
- Mark as SUCCESS
- Payer should receive type: `payment_reminder`

---

## 📊 Monitoring

### Check Logs:
```bash
firebase functions:log
```

### View Real-Time Logs:
```bash
firebase functions:log --follow
```

---

## 🔄 Rollback (If Needed)

### Revert to Previous Version:
```bash
firebase deploy --only functions --force
```

### Delete Specific Function:
```bash
firebase functions:delete notifyGroupInvite
```

---

## ✨ Success Indicators

- [x] App compiles without errors
- [x] Profile screen shows notification settings
- [x] Settings persist after app restart
- [x] Cloud Functions syntax valid
- [x] All notification types have data.type field

---

## 📝 Notes

- Notifications are sent to FCM tokens stored in `users/{userId}/fcmToken`
- Preferences are stored locally in SharedPreferences
- Backend always sends notifications; filtering happens on client
- FCM token is auto-saved when NotificationService initializes
