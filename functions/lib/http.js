const crypto = require('node:crypto');
const logger = require('firebase-functions/logger');

// Every API error carries a stable machine-readable `code`. The Flutter client
// maps codes to user-facing copy (lib/services/api_client.dart); `error` stays
// a readable English fallback.
class ApiError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

const badRequest = (code, message) => new ApiError(400, code, message);
const forbidden = (code, message) => new ApiError(403, code, message);
const notFound = (code, message) => new ApiError(404, code, message);
const conflict = (code, message) => new ApiError(409, code, message);

function requestContext(req, res, next) {
  req.id = req.get('x-request-id') || crypto.randomUUID();
  res.set('x-request-id', req.id);
  next();
}

// Structured logs carry only identifiers and error metadata. Never pass goal
// text, bulletin text, prayer requests or tokens here.
function log(severity, req, message, context = {}) {
  logger.write({ severity, message, requestId: req && req.id, uid: req && req.uid, path: req && req.path, ...context });
}

// Wraps an async route so thrown ApiErrors become JSON responses and anything
// else becomes a logged 500 with a generic message.
function route(handler) {
  return async (req, res) => {
    try {
      const result = await handler(req, res);
      if (!res.headersSent) res.json({ success: true, ...(result || {}) });
    } catch (err) {
      if (err instanceof ApiError) {
        if (err.status >= 500) log('ERROR', req, err.message, { code: err.code });
        return res.status(err.status).json({ success: false, code: err.code, error: err.message });
      }
      log('ERROR', req, 'Unhandled route error', { errorName: err && err.name, errorMessage: err && err.message, stack: err && err.stack });
      return res.status(500).json({ success: false, code: 'INTERNAL', error: 'Something went wrong. Please try again.', requestId: req.id });
    }
  };
}

// --- Validation -------------------------------------------------------------

function requireString(value, field, { max, min = 1, pattern } = {}) {
  if (typeof value !== 'string') throw badRequest('INVALID_INPUT', `${field} is required.`);
  const trimmed = value.trim();
  if (trimmed.length < min) throw badRequest('INVALID_INPUT', `${field} is required.`);
  if (max && trimmed.length > max) throw badRequest('TEXT_TOO_LONG', `${field} must be at most ${max} characters.`);
  if (pattern && !pattern.test(trimmed)) throw badRequest('INVALID_INPUT', `${field} has an invalid format.`);
  return trimmed;
}

function optionalString(value, field, { max } = {}) {
  if (value === undefined || value === null || value === '') return '';
  return requireString(value, field, { max });
}

// Firestore document ids supplied by clients: non-empty, no slashes, bounded.
function requireId(value, field) {
  return requireString(value, field, { max: 128, pattern: /^[A-Za-z0-9_-]+$/ });
}

module.exports = {
  ApiError,
  badRequest,
  conflict,
  forbidden,
  log,
  notFound,
  optionalString,
  requestContext,
  requireId,
  requireString,
  route
};
