# Quick Start: Deploy Settlement Reminders Feature

## ⚡ TL;DR - 30 Second Setup

### App Side ✅
**Already done!** The Flutter app has been updated:
- Notification preferences in Profile screen
- "Send Settlement Reminders" button in Group Details
- All preference logic implemented

### Backend Side (Firebase)
**To enable settlement reminders, run:**

```bash
cd /Users/deepansh/StudioProjects/SliceIt/functions
firebase deploy --only functions
```

**That's it!** 🎉

---

## 🔍 What Each Step Does

### Backend Deployment
```bash
firebase deploy --only functions
```

This deploys 4 Cloud Functions:
1. `notifyExpenseAdded` - Auto-notify when expense added
2. `notifyGroupInvite` - Auto-notify when member added
3. `notifySettlementReminder` - Called when "Send Reminders" button clicked
4. `notifyPaymentReceived` - Auto-notify when payment confirmed

---

## ✅ Verify It Works

### 1. Open App
- Go to any group
- Click "Balances" tab
- Click "Send Settlement Reminders" button

### 2. Check Firebase Logs
```bash
firebase functions:log
```

You should see:
```
Sent settlement reminder to userId1
Sent settlement reminder to userId2
...
```

### 3. Check Device Notifications
- If a group member has FCM token registered
- And they have "Settlement Reminders" enabled
- They'll get a notification: "You owe ₹500 in [Group Name]"

---

## 🐛 Troubleshooting

### No Notifications Received?

1. **Check FCM Token**
   - Open Firebase Console
   - Go to Firestore → users → {userId}
   - Look for `fcmToken` field
   - If empty → Token not registered yet

2. **Check Preferences**
   - Open App → Profile → Notifications
   - Is "Push Notifications" enabled?
   - Is "Settlement Reminders" enabled?

3. **Check Logs**
   ```bash
   firebase functions:log --follow
   ```
   - Should show "Sent settlement reminder to..."
   - If not → Check Cloud Function deployment

4. **Check Errors**
   ```bash
   firebase functions:log | grep -i error
   ```

---

## 📊 What Happens When Button is Clicked

```
User clicks "Send Settlement Reminders"
        ↓
App shows loading dialog
        ↓
App gets all expense IDs for group
        ↓
App calls Cloud Function: notifySettlementReminder
        ↓
Function identifies who owes money
        ↓
Function sends FCM to each debtor
        ↓
Each person's app checks preferences
        ↓
Notification displays or filters
        ↓
Success message shows count
```

---

## 🚀 Production Ready Features

✅ **Implemented:**
- Auto-notifications on expense/member addition
- User preferences per notification type
- On-demand settlement reminders
- Error handling and user feedback
- Loading states
- Firebase Cloud Functions

❌ **Not Yet Implemented (Future):**
- Scheduled reminders (daily/weekly)
- Notification history
- Do Not Disturb hours
- Custom notification sounds

---

## 💬 How to Use

### For Users
1. Open app → Go to Group Details
2. Click "Balances" tab
3. Click "Send Settlement Reminders"
4. Friends get notifications (if enabled)

### For Group Admin
- Use this to remind members to settle up
- Click once to notify all members who owe
- They can disable reminder notifications if they want

---

## 📱 Behind the Scenes

The system works like this:

1. **Backend sends notifications to all members**
2. **Client app receives them**
3. **App checks if that notification type is enabled**
4. **App displays or filters based on preference**

This is **privacy-focused** because:
- Filtering happens on device (not server)
- No tracking of preferences on backend
- Each phone controls its own notifications

---

## ✨ Done!

Your SliceIt app now has:
✅ Automatic notifications
✅ User preference controls
✅ On-demand settlement reminders
✅ Full Firebase integration

Enjoy! 🎉
