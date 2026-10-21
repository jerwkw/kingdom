/// Text limits enforced by firestore.rules and LIMITS in
/// functions/lib/domain.js. Used for maxLength on input fields.
class TextLimits {
  static const name = 40;
  static const goalTask = 80;
  static const goalText = 280;
  static const buildingName = 60;
  static const buildingDescription = 200;
  static const inviteCodeMax = 16;
  static const bulletinText = 1000;
}
