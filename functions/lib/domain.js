const catalog = require('./store-catalog.json');
const achievementCatalog = require('./achievements.json');

const STORE_ITEMS = Object.freeze(
  Object.fromEntries(
    Object.entries(catalog.items).map(([id, item]) => [id, Object.freeze({ ...item })])
  )
);

// Guild achievements are display-only milestones: unlocking one records a
// history event but does not change gameplay. Display copy lives in
// lib/config/achievements_config.dart, keyed by these ids.
const ACHIEVEMENTS = Object.freeze(achievementCatalog.achievements.map((a) => Object.freeze({ ...a })));

const LIMITS = Object.freeze({
  name: 40,
  goalTask: 80,
  goalText: 280,
  buildingName: 60,
  buildingDescription: 200,
  inviteCodeMin: 4,
  inviteCodeMax: 16,
  bulletinText: 1000,
  maxDeposit: 10000
});

const BULLETIN_TYPES = Object.freeze(['prayer', 'thanksgiving', 'sharing']);

// Business-day policy: every period key is computed in UTC. The Flutter client
// (lib/utils/period_keys.dart) uses the same policy, and both sides are tested
// against functions/test/fixtures/period-keys.json.
function getIsoWeekKey(date = new Date()) {
  const utcDate = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  const day = utcDate.getUTCDay() || 7;
  utcDate.setUTCDate(utcDate.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(utcDate.getUTCFullYear(), 0, 1));
  const week = Math.ceil((((utcDate - yearStart) / 86400000) + 1) / 7);
  return `${utcDate.getUTCFullYear()}-W${String(week).padStart(2, '0')}`;
}

function getPeriodKey(frequency, date = new Date()) {
  if (frequency === 'weekly') return getIsoWeekKey(date);
  if (frequency === 'monthly') return date.toISOString().slice(0, 7);
  return date.toISOString().slice(0, 10);
}

function getStoreItem(itemId) {
  return Object.prototype.hasOwnProperty.call(STORE_ITEMS, itemId) ? STORE_ITEMS[itemId] : null;
}

// Achievements whose threshold lies in (previousFund, newFund]. 'founded' is
// recorded at creation, so it is never returned here.
function achievementsCrossed(previousFund, newFund) {
  return ACHIEVEMENTS.filter((a) => a.threshold > 0 && a.threshold > previousFund && a.threshold <= newFund);
}

// Expected goal completions over a trailing 7-day window for a member's
// active goal schedule: each daily goal expects 7, each weekly goal 1, and
// each monthly goal 7/30. Daily reflections are excluded from both sides.
function weeklyCompletionTarget(goalCounts = {}) {
  return (goalCounts.daily || 0) * 7 + (goalCounts.weekly || 0) + (goalCounts.monthly || 0) * (7 / 30);
}

function completionPercent(completions, goalCounts) {
  const target = weeklyCompletionTarget(goalCounts);
  if (target <= 0) return 0;
  return Math.min(100, Math.round((completions / target) * 100));
}

module.exports = {
  ACHIEVEMENTS,
  BULLETIN_TYPES,
  LIMITS,
  STORE_ITEMS,
  achievementsCrossed,
  completionPercent,
  getIsoWeekKey,
  getPeriodKey,
  getStoreItem,
  weeklyCompletionTarget
};
