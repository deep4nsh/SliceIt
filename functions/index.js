'use strict';

const admin = require('firebase-admin');
const sgMail = require('@sendgrid/mail');
const { onCall } = require('firebase-functions/v2/https');
const { defineSecret, defineString } = require('firebase-functions/params');

// Initialize Admin SDK (idempotent)
try { admin.app(); } catch (e) { admin.initializeApp(); }

// Secrets and params
const SENDGRID_API_KEY = defineSecret('SENDGRID_API_KEY');
const SEND_FROM_EMAIL = defineString('SEND_FROM_EMAIL'); // e.g. verified sender
const SEND_FROM_NAME = defineString('SEND_FROM_NAME');   // e.g. "SliceIt"

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