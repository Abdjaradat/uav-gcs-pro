const admin = require('firebase-admin');
const path = require('path');

let db, auth;

function initFirebase() {
  const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH
    || path.join(__dirname, '..', 'service-account.json');

  try {
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  } catch {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId: process.env.FIREBASE_PROJECT_ID || 'uav-gcs-pro',
    });
  }

  db = admin.firestore();
  auth = admin.auth();
  console.log('Firebase initialized');
}

function getDb() { return db; }
function getAuth() { return auth; }

module.exports = { initFirebase, getDb, getAuth };
