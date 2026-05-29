'use strict';

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const sgMail = require('@sendgrid/mail');

// Initialize Admin SDK (idempotent)
try { admin.app(); } catch (e) { admin.initializeApp(); }

// Secrets and params
// Note: defineSecret/defineString are v2 features. For v1, we use functions.config().
// But for simplicity in this revert, we'll just use process.env or hardcoded values if needed, 
// or rely on the fact that functions.config() is the standard way for v1.
// However, since the user was struggling with secrets, we will use process.env for SendGrid if available,
// or just skip email if not configured.

function isValidEmail(email) {
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email);
}

// exports.sendGroupInvites = functions
//   .runWith({ memory: '256MB' })
//   .https.onCall(async (data, context) => {
//   const uid = context.auth?.uid;
//   if (!uid) {
//     throw new functions.https.HttpsError('unauthenticated', 'The function must be called while authenticated.');
//   }
//
//   const to = Array.isArray(data.to) ? data.to.filter(Boolean) : [];
//   const subject = (data.subject || '').toString().slice(0, 200);
//   const body = (data.body || '').toString();
//   const groupId = (data.groupId || '').toString();
//   const inviterUid = (data.inviterUid || '').toString();
//
//   if (!to.length) throw new functions.https.HttpsError('invalid-argument', 'to[] required');
//   const invalid = to.filter((e) => !isValidEmail(e));
//   if (invalid.length) throw new functions.https.HttpsError('invalid-argument', `invalid emails: ${invalid.join(', ')}`);
//   if (!groupId) throw new functions.https.HttpsError('invalid-argument', 'groupId required');
//
//   // Optionally ensure inviter matches caller
//   if (inviterUid && inviterUid !== uid) {
//     console.warn(`sendGroupInvites: inviterUid ${inviterUid} != auth uid ${uid}`);
//   }
//
//   // Compose message
//   const from = {
//     email: 'no-reply@sliceit.app', // Hardcoded fallback
//     name: 'SliceIt',
//   };
//
//   // Set API key and send
//   // For v1, we typically use functions.config().sendgrid.key
//   // But we'll try process.env first as a bridge
//   const apiKey = process.env.SENDGRID_API_KEY || functions.config().sendgrid?.key;
//
//   if (apiKey) {
//     sgMail.setApiKey(apiKey);
//     const html = body
//       .split('\n')
//       .map((line) => line.trim().length ? `<p>${escapeHtml(line)}</p>` : '<br/>')
//       .join('');
//
//     const messages = to.map((email) => ({
//       to: email,
//       from,
//       subject,
//       text: body,
//       html,
//     }));
//
//     await sgMail.send(messages, false);
//   } else {
//     console.warn("SendGrid API Key not found. Skipping email send.");
//   }
//
//   // Optionally mark invites as sent in Firestore
//   try {
//     const batch = admin.firestore().batch();
//     to.forEach((email) => {
//       const ref = admin.firestore()
//         .collection('groups')
//         .doc(groupId)
//         .collection('invites')
//         .doc(email);
//       batch.set(ref, { status: 'sent', sentByFunctionAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
//     });
//     await batch.commit();
//   } catch (e) {
//     console.warn('Failed to update invite docs:', e);
//   }
//
//   return { ok: true, sent: to.length };
// });

function escapeHtml(str) {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

// ==================================================================
// DIRECT SETTLEMENT API (Mock Implementation)
// ==================================================================

/**
 * POST /verifyVpa
 * Validates the VPA string.
 * MOCK Implementation: Checks if VPA contains '@'.
 */
exports.verifyVpa = functions.https.onCall(async (data, context) => {
  const { vpa } = data;

  if (!vpa || typeof vpa !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'VPA is required');
  }

  // MOCK Validation Logic
  if (vpa.includes('@')) {
    return {
      valid: true,
      name: "Mock Verified Name",
      vpa: vpa
    };
  }

  return { valid: false, message: "Invalid VPA format" };
});

/**
 * POST /initiatePay
 * Creates a transaction record and returns UPI Intent payload.
 */
exports.initiatePay = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');

  const { expenseId, amount, receiverUid } = data;

  if (!expenseId || !amount || !receiverUid) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
  }

  // 1. Fetch Receiver's VPA
  const receiverDoc = await admin.firestore().collection('users').doc(receiverUid).get();
  if (!receiverDoc.exists) throw new functions.https.HttpsError('not-found', 'Receiver not found');

  const receiverData = receiverDoc.data();
  const receiverVpa = receiverData.vpa;

  if (!receiverVpa) throw new functions.https.HttpsError('failed-precondition', 'Receiver has no VPA linked');

  // 2. Generate Transaction ID
  const txnId = `TRX_${Date.now()}_${Math.floor(Math.random() * 1000)}`;

  // 3. Create Transaction Record
  await admin.firestore().collection('transactions').doc(txnId).set({
    txnId,
    payerUid: uid,
    receiverUid,
    expenseId,
    amount: Number(amount),
    currency: 'INR',
    vpa: receiverVpa,
    status: 'CREATED',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // 4. Return UPI Intent Payload
  return {
    txnId,
    vpa: receiverVpa,
    name: receiverData.vpaVerifiedName || "SliceIt User",
    amount: Number(amount),
    note: `Payment for ${expenseId}`
  };
});

/**
 * POST /paymentWebhook
 * Receives S2S callbacks from PSP.
 */
exports.paymentWebhook = functions.https.onRequest(async (req, res) => {
  // TODO: Verify HMAC Signature here

  const { merchantTransactionId, providerReferenceId, status } = req.body;

  if (!merchantTransactionId || !status) {
    return res.status(400).send('Bad Request');
  }

  const txnRef = admin.firestore().collection('transactions').doc(merchantTransactionId);

  try {
    await admin.firestore().runTransaction(async (t) => {
      const doc = await t.get(txnRef);
      if (!doc.exists) throw new Error("Transaction not found");

      // Idempotency Check
      if (doc.data().status === 'SUCCESS') return;

      const newStatus = status === 'SUCCESS' ? 'SUCCESS' : 'FAILED';

      t.update(txnRef, {
        status: newStatus,
        providerReferenceId: providerReferenceId || null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Update Expense Status if Success
      if (newStatus === 'SUCCESS') {
        const expenseRef = admin.firestore().collection('expenses').doc(doc.data().expenseId);
        t.update(expenseRef, {
          paymentStatus: 'SETTLED',
          settledAt: admin.firestore.FieldValue.serverTimestamp(),
          transactionId: merchantTransactionId
        });
      }
    });

    res.json({ status: 'ok' });
  } catch (error) {
    console.error('Webhook Error:', error);
    res.status(500).send('Internal Server Error');
  }
});

// ==================================================================
// NOTIFICATION SERVICE
// ==================================================================

/**
 * Trigger: When a new expense is added to a group
 * Action: Send push notifications to all group members
 */
exports.notifyExpenseAdded = functions
  .runWith({ memory: '256MB' })
  .firestore
  .document('groups/{groupId}/expenses/{expenseId}')
  .onCreate(async (snap, context) => {
    const expense = snap.data();
    const groupId = context.params.groupId;
    const expenseId = context.params.expenseId;

    try {
      // Fetch group data
      const groupDoc = await admin.firestore()
        .collection('groups')
        .doc(groupId)
        .get();

      if (!groupDoc.exists) {
        console.log('Group not found:', groupId);
        return;
      }

      const groupData = groupDoc.data();
      const groupName = groupData.name || 'a group';
      const members = groupData.members || [];

      // Fetch creator's name
      const creatorDoc = await admin.firestore()
        .collection('users')
        .doc(expense.paidBy)
        .get();

      const creatorName = creatorDoc.exists
        ? (creatorDoc.data().name || 'Someone')
        : 'Someone';

      // Get FCM tokens for all members except the creator
      const tokens = [];
      for (const memberId of members) {
        if (memberId !== expense.paidBy) {
          const userDoc = await admin.firestore()
            .collection('users')
            .doc(memberId)
            .get();

          if (userDoc.exists && userDoc.data().fcmToken) {
            tokens.push(userDoc.data().fcmToken);
          }
        }
      }

      if (tokens.length === 0) {
        console.log('No FCM tokens found for group members');
        return;
      }

      // Prepare notification payload with type for preference filtering
      const message = {
        notification: {
          title: `New expense in ${groupName}`,
          body: `${creatorName} added ₹${expense.amount.toFixed(2)} - ${expense.title}`,
        },
        data: {
          type: 'expense_update',
          groupId: groupId,
          expenseId: expenseId,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
      };

      // Send multicast message
      const response = await admin.messaging().sendMulticast({
        tokens: tokens,
        notification: message.notification,
        data: message.data,
        android: {
          priority: 'high',
        },
        apns: {
          headers: {
            'apns-priority': '10',
          },
        },
      });

      console.log(`Sent ${response.successCount} notifications for expense ${expenseId}`);

      if (response.failureCount > 0) {
        console.log(`Failed to send ${response.failureCount} notifications`);
      }

      return { success: true, sent: response.successCount };
    } catch (error) {
      console.error('Error sending notifications:', error);
      throw error;
    }
  });

/**
 * Trigger: When a user is added to a group
 * Action: Send push notification to the new member
 * NOTE: This function requires a clean deployment. For now, use notifySettlementReminder pattern.
 */
// exports.notifyGroupInvite = functions.firestore
//   .document('groups/{groupId}')
//   .onUpdate(async (change, context) => {
//     const before = change.before.data();
//     const after = change.after.data();
//     const groupId = context.params.groupId;
//
//     // Check if members array was updated
//     const beforeMembers = before.members || [];
//     const afterMembers = after.members || [];
//
//     // Find newly added members
//     const newMembers = afterMembers.filter(m => !beforeMembers.includes(m));
//
//     if (newMembers.length === 0) {
//       return; // No new members added
//     }
//
//     try {
//       const groupName = after.name || 'a group';
//
//       // Get FCM tokens for newly added members
//       for (const memberId of newMembers) {
//         const userDoc = await admin.firestore()
//           .collection('users')
//           .doc(memberId)
//           .get();
//
//         if (userDoc.exists && userDoc.data().fcmToken) {
//           const token = userDoc.data().fcmToken;
//
//           // Prepare notification for group invite
//           const message = {
//             notification: {
//               title: 'Added to Group',
//               body: `You were added to ${groupName}`,
//             },
//             data: {
//               type: 'group_invite',
//               groupId: groupId,
//               click_action: 'FLUTTER_NOTIFICATION_CLICK',
//             },
//           };
//
//           // Send notification
//           await admin.messaging().send({
//             token: token,
//             notification: message.notification,
//             data: message.data,
//             android: {
//               priority: 'high',
//             },
//             apns: {
//               headers: {
//                 'apns-priority': '10',
//               },
//             },
//           });
//
//           console.log(`Sent group invite notification to ${memberId}`);
//         }
//       }
//
//       return { success: true, notified: newMembers.length };
//     } catch (error) {
//       console.error('Error sending group invite notifications:', error);
//       throw error;
//     }
//   });

/**
 * Trigger: When an expense payment is overdue
 * Action: Send settlement reminder to members who owe money
 */
exports.notifySettlementReminder = functions
  .runWith({ memory: '256MB' })
  .https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  }

  const { groupId, expenseIds } = data;

  if (!groupId || !Array.isArray(expenseIds) || expenseIds.length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'groupId and expenseIds[] required');
  }

  try {
    const groupDoc = await admin.firestore()
      .collection('groups')
      .doc(groupId)
      .get();

    if (!groupDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Group not found');
    }

    const groupName = groupDoc.data().name || 'a group';
    const members = groupDoc.data().members || [];

    // Track who owes money
    const debtorsMap = {};

    // Check each expense
    for (const expenseId of expenseIds) {
      const expenseDoc = await admin.firestore()
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .doc(expenseId)
        .get();

      if (expenseDoc.exists) {
        const expense = expenseDoc.data();
        const splits = expense.splits || {};
        const paidBy = expense.paidBy;

        // Calculate who owes money
        for (const [memberId, amount] of Object.entries(splits)) {
          if (memberId !== paidBy && amount > 0) {
            debtorsMap[memberId] = (debtorsMap[memberId] || 0) + amount;
          }
        }
      }
    }

    // Send notifications to debtors
    const sentTo = [];
    for (const [memberId, amount] of Object.entries(debtorsMap)) {
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(memberId)
        .get();

      if (userDoc.exists && userDoc.data().fcmToken) {
        const token = userDoc.data().fcmToken;

        const message = {
          notification: {
            title: 'Settlement Due',
            body: `You owe ₹${amount.toFixed(2)} in ${groupName}`,
          },
          data: {
            type: 'settlement_reminder',
            groupId: groupId,
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
        };

        await admin.messaging().send({
          token: token,
          notification: message.notification,
          data: message.data,
          android: {
            priority: 'high',
          },
          apns: {
            headers: {
              'apns-priority': '10',
            },
          },
        });

        sentTo.push(memberId);
        console.log(`Sent settlement reminder to ${memberId}`);
      }
    }

    return { success: true, notified: sentTo.length };
  } catch (error) {
    console.error('Error sending settlement reminders:', error);
    throw error;
  }
});

/**
 * Trigger: When a payment is marked as complete
 * Action: Send notification to payer that payment was received
 * NOTE: Commented out due to Firebase billing restrictions. Can be enabled after account upgrade.
 */
// exports.notifyPaymentReceived = functions.firestore
//   .document('transactions/{transactionId}')
//   .onUpdate(async (change, context) => {
//     const before = change.before.data();
//     const after = change.after.data();
//
//     // Check if payment was just marked as SUCCESS
//     if (before.status !== 'SUCCESS' && after.status === 'SUCCESS') {
//       const transactionId = context.params.transactionId;
//       const receiverUid = after.receiverUid;
//       const payerUid = after.payerUid;
//       const amount = after.amount;
//
//       try {
//         // Get payer's FCM token to notify them
//         const payerDoc = await admin.firestore()
//           .collection('users')
//           .doc(payerUid)
//           .get();
//
//         if (payerDoc.exists && payerDoc.data().fcmToken) {
//           const token = payerDoc.data().fcmToken;
//
//           // Get receiver's name
//           const receiverDoc = await admin.firestore()
//             .collection('users')
//             .doc(receiverUid)
//             .get();
//
//           const receiverName = receiverDoc.exists
//             ? (receiverDoc.data().name || 'Someone')
//             : 'Someone';
//
//           const message = {
//             notification: {
//               title: 'Payment Received',
//               body: `₹${amount.toFixed(2)} payment confirmed`,
//             },
//             data: {
//               type: 'payment_reminder',
//               transactionId: transactionId,
//               click_action: 'FLUTTER_NOTIFICATION_CLICK',
//             },
//           };
//
//           await admin.messaging().send({
//             token: token,
//             notification: message.notification,
//             data: message.data,
//             android: {
//               priority: 'high',
//             },
//             apns: {
//               headers: {
//                 'apns-priority': '10',
//               },
//             },
//           });
//
//           console.log(`Sent payment confirmation to payer ${payerUid}`);
//         }
//
//         return { success: true };
//       } catch (error) {
//         console.error('Error sending payment notification:', error);
//         throw error;
//       }
//     }
//   });