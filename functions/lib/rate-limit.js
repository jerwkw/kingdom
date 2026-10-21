const { db, Timestamp } = require('./firebase');
const { ApiError } = require('./http');

const HOUR = 60 * 60 * 1000;
const DAY = 24 * HOUR;

// Fixed-window quotas per user and action. Counters live in the server-only
// `rateLimits` collection; `expiresAt` is intended for a Firestore TTL policy.
const RATE_LIMITS = Object.freeze({
  completeGoal: { limit: 60, windowMs: HOUR },
  completeDailyChallenge: { limit: 10, windowMs: HOUR },
  depositFish: { limit: 30, windowMs: HOUR },
  createBuilding: { limit: 5, windowMs: 7 * DAY },
  joinBuilding: { limit: 10, windowMs: HOUR },
  membershipAdmin: { limit: 120, windowMs: HOUR },
  purchaseItem: { limit: 30, windowMs: HOUR },
  equipItem: { limit: 120, windowMs: HOUR },
  createBulletinPost: { limit: 20, windowMs: DAY }
});

async function consumeRateLimit(uid, action, now = Date.now()) {
  const config = RATE_LIMITS[action];
  if (!config) throw new Error(`Unknown rate-limit action ${action}`);
  const windowStart = Math.floor(now / config.windowMs) * config.windowMs;
  const ref = db.collection('rateLimits').doc(`${uid}_${action}_${windowStart}`);

  await db.runTransaction(async (transaction) => {
    const doc = await transaction.get(ref);
    const count = doc.exists ? doc.data().count || 0 : 0;
    if (count >= config.limit) {
      throw new ApiError(429, 'RATE_LIMITED', 'Too many requests. Please wait a little and try again.');
    }
    transaction.set(ref, {
      uid,
      action,
      count: count + 1,
      expiresAt: Timestamp.fromMillis(windowStart + config.windowMs + DAY)
    });
  });
}

// Middleware form for routes whose quota does not depend on the payload.
function rateLimit(action) {
  return async (req, res, next) => {
    try {
      await consumeRateLimit(req.uid, action);
      next();
    } catch (err) {
      if (err instanceof ApiError) {
        return res.status(err.status).json({ success: false, code: err.code, error: err.message });
      }
      next(err);
    }
  };
}

module.exports = { RATE_LIMITS, consumeRateLimit, rateLimit };
