const { db, FieldValue } = require('../firebase');
const { BULLETIN_TYPES, LIMITS } = require('../domain');
const { badRequest, forbidden, notFound, requireString, route } = require('../http');
const { rateLimit } = require('../rate-limit');

// Posts are created through the API so they can be rate limited and carry a
// server-verified author name. Authors edit/delete their own posts directly
// (text-only, length-limited in firestore.rules).
function register(app, authenticateToken) {
  app.post(['/createBulletinPost', '/api/createBulletinPost'], authenticateToken, rateLimit('createBulletinPost'), route(async (req) => {
    const uid = req.uid;
    const type = req.body && req.body.type;
    if (!BULLETIN_TYPES.includes(type)) throw badRequest('INVALID_INPUT', 'Unknown post type.');
    const text = requireString(req.body.text, 'Post', { max: LIMITS.bulletinText });

    const userDoc = await db.collection('users').doc(uid).get();
    if (!userDoc.exists) throw notFound('USER_NOT_FOUND', 'User profile not found.');
    const buildingId = userDoc.data().buildingId;
    if (!buildingId) throw forbidden('NOT_A_MEMBER', 'Join a neighbourhood before posting.');

    const ref = await db.collection('bulletinPosts').add({
      userId: uid,
      authorName: userDoc.data().name || 'Church Member',
      buildingId,
      type,
      text,
      reactions: {},
      createdAt: FieldValue.serverTimestamp()
    });
    return { postId: ref.id };
  }));
}

module.exports = { register };
