'use strict';

const admin = require('firebase-admin');
const sgMail = require('@sendgrid/mail');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret, defineString } = require('firebase-functions/params');

// Initialize Admin SDK (idempotent)
try { admin.app(); } catch (e) { admin.initializeApp(); }

// Secrets and params
const SENDGRID_API_KEY = defineSecret('SENDGRID_API_KEY');
const SEND_FROM_EMAIL = defineString('SEND_FROM_EMAIL'); // e.g. verified sender
const SEND_FROM_NAME = defineString('SEND_FROM_NAME');   // e.g. "SliceIt"
const SETU_SCHEME_ID = defineSecret('35c19b57-7a04-4a7d-bf07-e0fd7da0f887');
const SETU_SECRET = defineSecret('HWkgcTK9vTrH1rBpIjA1sB8p7BYYbRHP');

function isValidEmail(email) {
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email);
}

exports.sendGroupInvites = onCall({
  region: 'us-central1',
  secrets: [SENDGRID_API_KEY],
  cors: true,
}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new Error('unauthenticated');
  }

  const data = request.data || {};
  const to = Array.isArray(data.to) ? data.to.filter(Boolean) : [];
  const subject = (data.subject || '').toString().slice(0, 200);
  const body = (data.body || '').toString();
  const groupId = (data.groupId || '').toString();
  const inviterUid = (data.inviterUid || '').toString();

  if (!to.length) throw new Error('invalid-argument: to[] required');
  const invalid = to.filter((e) => !isValidEmail(e));
  if (invalid.length) throw new Error(`invalid-argument: invalid emails: ${invalid.join(', ')}`);
  if (!groupId) throw new Error('invalid-argument: groupId required');

  // Optionally ensure inviter matches caller
  if (inviterUid && inviterUid !== uid) {
    // Not fatal, but log mismatch
    console.warn(`sendGroupInvites: inviterUid ${inviterUid} != auth uid ${uid}`);
  }

  // Compose message
  const from = {
    email: SEND_FROM_EMAIL.value() || 'no-reply@sliceit.app',
    name: SEND_FROM_NAME.value() || 'SliceIt',
  };

  // Set API key and send
  sgMail.setApiKey(SENDGRID_API_KEY.value());

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
// DIRECT SETTLEMENT API
// ==================================================================

const { onRequest } = require('firebase-functions/v2/https');
const { FieldValue } = require('firebase-admin/firestore');

/**
 * POST /verifyVpa
 * Validates the VPA string using Setu UPI DeepLinks API.
 */
exports.verifyVpa = onCall({
  region: 'us-central1',
  secrets: [SETU_SCHEME_ID, SETU_SECRET],
}, async (request) => {
  const { vpa } = request.data;

  if (!vpa || typeof vpa !== 'string') {
    throw new HttpsError('invalid-argument', 'VPA is required');
  }

  const schemeId = SETU_SCHEME_ID.value();
  const secret = SETU_SECRET.value();

  // Fallback to mock if secrets are missing (for local dev without env vars)
  if (!schemeId || !secret) {
    console.warn("WARNING: Setu secrets (SETU_SCHEME_ID, SETU_SECRET) not found. Using MOCK verification.");
    if (vpa.includes('@')) {
      return { valid: true, name: "Mock User (Setu Secrets Missing)", vpa };
    }
    return { valid: false, message: "Invalid VPA format" };
  }

  try {
    // Generate JWT
    const token = jwt.sign(
      {
        aud: schemeId,
        iat: Math.floor(Date.now() / 1000),
        jti: uuidv4(),
      },
      secret,
      { algorithm: 'HS256' }
    );

    // Call Setu API
    // Production: https://umap.setu.co/api/v1/merchants/customer-vpas/verify
    // Sandbox: https://umap.setu.co/api/v1/merchants/customer-vpas/verify (Setu uses same endpoint, auth determines env)
    const response = await axios.post(
      'https://umap.setu.co/api/v1/merchants/customer-vpas/verify',
      {
        customerVpa: vpa,
        merchantReferenceId: uuidv4()
      },
      {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        }
      }
    );

    const result = response.data;

    // Check response structure based on Setu docs
    if (result.success && result.data && result.data.valid) {
      return {
        valid: true,
        name: result.data.customerName || "Verified User",
        vpa: vpa
      };
    } else {
      return { valid: false, message: "VPA not found or invalid" };
    }

  } catch (error) {
    console.error("Setu API Error:", error.response?.data || error.message);
    // Return a user-friendly error, don't crash
    throw new HttpsError('internal', 'VPA Verification Failed: ' + (error.response?.data?.message || error.message));
  }
});

/**
 * POST /initiatePay
 * Creates a transaction record and returns UPI Intent payload.
 */
exports.initiatePay = onCall({ region: 'us-central1' }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new Error('unauthenticated');

  const { expenseId, amount, receiverUid } = request.data;

  if (!expenseId || !amount || !receiverUid) {
    throw new Error('invalid-argument: Missing required fields');
  }

  // 1. Fetch Receiver's VPA
  const receiverDoc = await admin.firestore().collection('users').doc(receiverUid).get();
  if (!receiverDoc.exists) throw new Error('not-found: Receiver not found');

  const receiverData = receiverDoc.data();
  const receiverVpa = receiverData.vpa;

  if (!receiverVpa) throw new Error('failed-precondition: Receiver has no VPA linked');

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
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
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
exports.paymentWebhook = onRequest(async (req, res) => {
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
        updatedAt: FieldValue.serverTimestamp()
      });

      // Update Expense Status if Success
      if (newStatus === 'SUCCESS') {
        const expenseRef = admin.firestore().collection('expenses').doc(doc.data().expenseId);
        t.update(expenseRef, {
          paymentStatus: 'SETTLED',
          settledAt: FieldValue.serverTimestamp(),
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