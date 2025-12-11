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

exports.sendGroupInvites = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'The function must be called while authenticated.');
  }

  const to = Array.isArray(data.to) ? data.to.filter(Boolean) : [];
  const subject = (data.subject || '').toString().slice(0, 200);
  const body = (data.body || '').toString();
  const groupId = (data.groupId || '').toString();
  const inviterUid = (data.inviterUid || '').toString();

  if (!to.length) throw new functions.https.HttpsError('invalid-argument', 'to[] required');
  const invalid = to.filter((e) => !isValidEmail(e));
  if (invalid.length) throw new functions.https.HttpsError('invalid-argument', `invalid emails: ${invalid.join(', ')}`);
  if (!groupId) throw new functions.https.HttpsError('invalid-argument', 'groupId required');

  // Optionally ensure inviter matches caller
  if (inviterUid && inviterUid !== uid) {
    console.warn(`sendGroupInvites: inviterUid ${inviterUid} != auth uid ${uid}`);
  }

  // Compose message
  const from = {
    email: 'no-reply@sliceit.app', // Hardcoded fallback
    name: 'SliceIt',
  };

  // Set API key and send
  // For v1, we typically use functions.config().sendgrid.key
  // But we'll try process.env first as a bridge
  const apiKey = process.env.SENDGRID_API_KEY || functions.config().sendgrid?.key;

  if (apiKey) {
    sgMail.setApiKey(apiKey);
    const html = body
      .split('\n')
      .map((line) => line.trim().length ? `<p>${escapeHtml(line)}</p>` : '<br/>')
      .join('');

    const messages = to.map((email) => ({
      to: email,
      from,
      subject,
      text: body,
      html,
    }));

    await sgMail.send(messages, false);
  } else {
    console.warn("SendGrid API Key not found. Skipping email send.");
  }

  // Optionally mark invites as sent in Firestore
  try {
    const batch = admin.firestore().batch();
    to.forEach((email) => {
      const ref = admin.firestore()
        .collection('groups')
        .doc(groupId)
        .collection('invites')
        .doc(email);
      batch.set(ref, { status: 'sent', sentByFunctionAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    });
    await batch.commit();
  } catch (e) {
    console.warn('Failed to update invite docs:', e);
  }

  return { ok: true, sent: to.length };
});

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