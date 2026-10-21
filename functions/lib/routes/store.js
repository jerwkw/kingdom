const { db, FieldValue } = require('../firebase');
const { getStoreItem } = require('../domain');
const { badRequest, conflict, forbidden, notFound, requireId, route } = require('../http');
const { rateLimit } = require('../rate-limit');

function register(app, authenticateToken) {
  app.post(['/purchaseItem', '/api/purchaseItem'], authenticateToken, rateLimit('purchaseItem'), route(async (req) => {
    const uid = req.uid;
    const itemId = requireId(req.body && req.body.itemId, 'itemId');
    const storeItem = getStoreItem(itemId);
    if (!storeItem) throw badRequest('UNKNOWN_ITEM', 'Unknown store item.');

    const userRef = db.collection('users').doc(uid);
    const itemRef = db.collection('inventory').doc(uid).collection('items').doc(itemId);
    let newBalance = 0;

    await db.runTransaction(async (transaction) => {
      const [userDoc, itemDoc] = await Promise.all([transaction.get(userRef), transaction.get(itemRef)]);
      if (!userDoc.exists) throw notFound('USER_NOT_FOUND', 'User profile not found.');
      if (itemDoc.exists) throw conflict('ALREADY_OWNED', 'You already own this item.');
      const balance = userDoc.data().fishBalance || 0;
      if (balance < storeItem.cost) throw badRequest('INSUFFICIENT_FUNDS', 'Not enough fish to purchase this item.');

      newBalance = balance - storeItem.cost;
      transaction.update(userRef, { fishBalance: newBalance });
      transaction.set(itemRef, {
        category: storeItem.category,
        cost: storeItem.cost,
        acquiredAt: FieldValue.serverTimestamp()
      });
    });

    return { newBalance };
  }));

  // Equipping is server-side so avatarConfig can only reference owned items.
  // `equip: false` (or equipping the item already worn) clears the slot.
  app.post(['/equipItem', '/api/equipItem'], authenticateToken, rateLimit('equipItem'), route(async (req) => {
    const uid = req.uid;
    const itemId = requireId(req.body && req.body.itemId, 'itemId');
    const storeItem = getStoreItem(itemId);
    if (!storeItem) throw badRequest('UNKNOWN_ITEM', 'Unknown store item.');
    const userRef = db.collection('users').doc(uid);
    const itemRef = db.collection('inventory').doc(uid).collection('items').doc(itemId);
    let equipped;

    await db.runTransaction(async (transaction) => {
      const [userDoc, itemDoc] = await Promise.all([transaction.get(userRef), transaction.get(itemRef)]);
      if (!userDoc.exists) throw notFound('USER_NOT_FOUND', 'User profile not found.');
      if (!itemDoc.exists) throw forbidden('NOT_OWNED', 'Purchase this item before equipping it.');

      const avatarConfig = { ...(userDoc.data().avatarConfig || {}) };
      const wantEquip = req.body.equip !== undefined ? req.body.equip === true : avatarConfig[storeItem.category] !== itemId;
      if (wantEquip) avatarConfig[storeItem.category] = itemId;
      else if (avatarConfig[storeItem.category] === itemId) delete avatarConfig[storeItem.category];
      equipped = wantEquip;
      transaction.update(userRef, { avatarConfig });
    });

    return { equipped, category: storeItem.category };
  }));
}

module.exports = { register };
