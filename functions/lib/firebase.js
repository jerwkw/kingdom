const admin = require('firebase-admin');
const { FieldValue, Timestamp, getFirestore } = require('firebase-admin/firestore');

if (admin.apps.length === 0) admin.initializeApp();

const db = getFirestore();

module.exports = { admin, db, FieldValue, Timestamp };
