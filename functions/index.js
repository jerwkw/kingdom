const functions = require("firebase-functions/v1");
const express = require("express");
const cors = require("cors");
const { admin } = require('./lib/firebase');
const { log, requestContext } = require('./lib/http');
const goals = require('./lib/routes/goals');
const buildings = require('./lib/routes/buildings');
const store = require('./lib/routes/store');
const bulletin = require('./lib/routes/bulletin');

// Production traffic arrives same-origin through the Hosting /api rewrite, so
// CORS only matters for direct invocation. Defaults to the deploying project's
// Hosting domains; override with a comma-separated ALLOWED_ORIGINS in
// functions/.env.<project>.
const projectId = process.env.GCLOUD_PROJECT || 'church-app-f8a55';
const DEFAULT_ORIGINS = [`https://${projectId}.web.app`, `https://${projectId}.firebaseapp.com`];
const allowedOrigins = (process.env.ALLOWED_ORIGINS || DEFAULT_ORIGINS.join(','))
  .split(',').map((o) => o.trim()).filter(Boolean);
const isEmulator = process.env.FUNCTIONS_EMULATOR === 'true';

const app = express();
app.use(requestContext);
app.use(cors({
  origin(origin, callback) {
    const allowed = !origin || allowedOrigins.includes(origin) ||
      (isEmulator && /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin));
    callback(null, allowed);
  }
}));
app.use(express.json({ limit: '16kb' }));

// -----------------------------------------------------------------------------
// Authentication Middleware
// -----------------------------------------------------------------------------
async function authenticateToken(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, code: 'UNAUTHENTICATED', error: 'Missing or malformed token.' });
  }

  try {
    const decodedToken = await admin.auth().verifyIdToken(authHeader.slice('Bearer '.length));
    req.uid = decodedToken.uid;
    next();
  } catch (error) {
    log('WARNING', req, 'Rejected ID token', { errorCode: error.code });
    return res.status(401).json({ success: false, code: 'UNAUTHENTICATED', error: 'Your session has expired. Please sign in again.' });
  }
}

// -----------------------------------------------------------------------------
// Endpoints (each registered under both `/path` and `/api/path`)
// -----------------------------------------------------------------------------
app.get(['/health', '/api/health'], authenticateToken, (req, res) => {
  res.json({ ok: true, message: 'Kingdom Cloud Function operational', verifiedUid: req.uid });
});

goals.register(app, authenticateToken);
buildings.register(app, authenticateToken);
store.register(app, authenticateToken);
bulletin.register(app, authenticateToken);

// Malformed JSON bodies and other middleware errors.
app.use((err, req, res, next) => {
  if (res.headersSent) return next(err);
  if (err.type === 'entity.parse.failed' || err.type === 'entity.too.large') {
    return res.status(400).json({ success: false, code: 'INVALID_INPUT', error: 'Malformed request body.' });
  }
  log('ERROR', req, 'Unhandled middleware error', { errorMessage: err.message });
  return res.status(500).json({ success: false, code: 'INTERNAL', error: 'Something went wrong. Please try again.' });
});

// Export as 1st Gen Cloud Function (matches existing project generation)
exports.api = functions.https.onRequest((req, res) => {
  return app(req, res);
});

// Scheduled Cron Job: Runs every day at 00:01 Midnight UTC
exports.dailyChallengeCron = functions.pubsub.schedule("1 0 * * *").onRun(async () => {
  await goals.ensureDailyChallenge();
});

// Keeps the per-member goal schedule used by building statistics current.
exports.goalScheduleSync = functions.firestore.document('goals/{goalId}').onWrite(async (change) => {
  const uid = (change.after.exists ? change.after.data() : change.before.data()).userId;
  if (uid) await goals.recomputeGoalCounts(uid);
});
