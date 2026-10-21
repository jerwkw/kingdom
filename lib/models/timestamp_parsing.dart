import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads a Firestore timestamp field that may also arrive as a DateTime or an
/// ISO-8601 string. Returns null for missing or pending server timestamps.
DateTime? parseTimestamp(Object? raw) {
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}
