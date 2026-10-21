const test = require('node:test');
const assert = require('node:assert/strict');
const {
  STORE_ITEMS, achievementsCrossed, completionPercent, getPeriodKey, getStoreItem, weeklyCompletionTarget
} = require('../lib/domain');
const periodKeyFixtures = require('./fixtures/period-keys.json');

test('period keys enforce daily, ISO-weekly, and monthly reward windows', () => {
  const date = new Date('2026-09-08T12:00:00Z');
  assert.equal(getPeriodKey('daily', date), '2026-09-08');
  assert.equal(getPeriodKey('weekly', date), '2026-W37');
  assert.equal(getPeriodKey('monthly', date), '2026-09');
});

test('period keys match the shared UTC fixtures around midnight and year boundaries', () => {
  for (const c of periodKeyFixtures.cases) {
    const date = new Date(c.instant);
    for (const frequency of ['daily', 'weekly', 'monthly']) {
      assert.equal(getPeriodKey(frequency, date), c[frequency], `${frequency} @ ${c.instant}`);
    }
  }
});

test('store prices are authoritative and unknown items are rejected', () => {
  assert.deepEqual(getStoreItem('head_crown'), { category: 'headpiece', cost: 30 });
  assert.equal(getStoreItem('invented_item'), null);
  assert.equal(getStoreItem('__proto__'), null);
  assert.equal(getStoreItem('constructor'), null);
  assert.ok(Object.isFrozen(STORE_ITEMS.head_crown));
});

test('achievements unlock once when a fund threshold is crossed', () => {
  assert.deepEqual(achievementsCrossed(0, 9).map((a) => a.id), []);
  assert.deepEqual(achievementsCrossed(9, 10).map((a) => a.id), ['first_fish']);
  assert.deepEqual(achievementsCrossed(10, 11).map((a) => a.id), []);
  assert.deepEqual(achievementsCrossed(5, 120).map((a) => a.id), ['first_fish', 'playground', 'fountain']);
});

test('completion target follows the member goal schedule', () => {
  assert.equal(weeklyCompletionTarget({ daily: 1 }), 7);
  assert.equal(weeklyCompletionTarget({ daily: 2, weekly: 1 }), 15);
  assert.equal(completionPercent(7, { daily: 1 }), 100);
  assert.equal(completionPercent(1, { weekly: 1 }), 100);
  assert.equal(completionPercent(3, { daily: 2 }), 21);
  assert.equal(completionPercent(30, { daily: 1 }), 100);
  assert.equal(completionPercent(3, {}), 0);
});
