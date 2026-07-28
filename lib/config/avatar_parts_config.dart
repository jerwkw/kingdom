import 'package:flutter/material.dart';

/// A single selectable option within an avatar customization category.
///
/// To add a new option (e.g., a new hairstyle):
///   1. Add an [AvatarOption] entry to the relevant list in [AvatarPartsConfig].
///   2. If using SVG assets, place the file at [assetPath] and the renderer
///      will load it instead of using the built-in CustomPainter fallback.
///   3. If using the built-in painter, add a drawing case in [AvatarPainter].
class AvatarOption {
  final String id;
  final String label;
  final Color? color;
  final String? genderRestriction;

  /// Path to an SVG/image asset. When non-null the renderer uses this file
  /// instead of the procedural painter. Set to null for built-in placeholders.
  final String? assetPath;

  const AvatarOption({
    required this.id,
    required this.label,
    this.color,
    this.genderRestriction,
    this.assetPath,
  });
}

/// Central, modular registry of every avatar customisation option.
///
/// **Adding new parts is a two-step process:**
/// 1. Append an [AvatarOption] to the list below.
/// 2. (Optional) Drop an SVG into `assets/avatar/<category>/` and set
///    [AvatarOption.assetPath]. If omitted the built-in painter is used.
///
/// Nothing else in the app needs to change — the creation screen and renderer
/// both read from this registry dynamically.
class AvatarPartsConfig {
  AvatarPartsConfig._();

  // ---------------------------------------------------------------------------
  // Gender
  // ---------------------------------------------------------------------------
  static const List<AvatarOption> genders = [
    AvatarOption(id: 'male', label: 'Male'),
    AvatarOption(id: 'female', label: 'Female'),
    AvatarOption(id: 'neutral', label: 'Neutral'),
  ];

  // ---------------------------------------------------------------------------
  // Body Type  (genderRestriction filters display in the creation UI)
  // ---------------------------------------------------------------------------
  static const List<AvatarOption> bodyTypes = [
    AvatarOption(id: 'standard', label: 'Standard'),
    AvatarOption(id: 'broad', label: 'Broad', genderRestriction: 'male'),
    AvatarOption(id: 'slim', label: 'Slim', genderRestriction: 'female'),
    AvatarOption(id: 'athletic', label: 'Athletic'),
  ];

  /// Returns body types available for the given [gender], plus any universal.
  static List<AvatarOption> bodyTypesForGender(String gender) {
    return bodyTypes
        .where((o) => o.genderRestriction == null || o.genderRestriction == gender)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Skin Tone  (6 tones, matching emoji skin-modifier palette)
  // ---------------------------------------------------------------------------
  static const List<AvatarOption> skinTones = [
    AvatarOption(id: 'light', label: 'Light', color: Color(0xFFFDEBD3)),
    AvatarOption(id: 'fair', label: 'Fair', color: Color(0xFFF5C5A3)),
    AvatarOption(id: 'medium', label: 'Medium', color: Color(0xFFD4A574)),
    AvatarOption(id: 'tan', label: 'Tan', color: Color(0xFFC68642)),
    AvatarOption(id: 'dark', label: 'Dark', color: Color(0xFF8D5524)),
    AvatarOption(id: 'deep', label: 'Deep', color: Color(0xFF5C3317)),
  ];

  static Color getSkinToneColor(String id) {
    return skinTones.firstWhere((o) => o.id == id, orElse: () => skinTones[2]).color!;
  }

  // ---------------------------------------------------------------------------
  // Face Shape
  // ---------------------------------------------------------------------------
  static const List<AvatarOption> faceShapes = [
    AvatarOption(id: 'round', label: 'Round'),
    AvatarOption(id: 'oval', label: 'Oval'),
    AvatarOption(id: 'square', label: 'Square'),
  ];

  // ---------------------------------------------------------------------------
  // Eyes
  // ---------------------------------------------------------------------------
  static const List<AvatarOption> eyeStyles = [
    AvatarOption(id: 'friendly', label: 'Friendly'),
    AvatarOption(id: 'gentle', label: 'Gentle'),
    AvatarOption(id: 'bright', label: 'Bright'),
    AvatarOption(id: 'calm', label: 'Calm'),
  ];

  // ---------------------------------------------------------------------------
  // Nose
  // ---------------------------------------------------------------------------
  static const List<AvatarOption> noseStyles = [
    AvatarOption(id: 'small', label: 'Small'),
    AvatarOption(id: 'button', label: 'Button'),
    AvatarOption(id: 'medium', label: 'Medium'),
  ];

  // ---------------------------------------------------------------------------
  // Mouth
  // ---------------------------------------------------------------------------
  static const List<AvatarOption> mouthStyles = [
    AvatarOption(id: 'smile', label: 'Smile'),
    AvatarOption(id: 'grin', label: 'Grin'),
    AvatarOption(id: 'neutral', label: 'Neutral'),
    AvatarOption(id: 'gentle', label: 'Gentle'),
  ];

  // ---------------------------------------------------------------------------
  // Hair Style  (gender-restricted where it makes sense visually)
  // ---------------------------------------------------------------------------
  static const List<AvatarOption> hairStyles = [
    AvatarOption(id: 'short_classic', label: 'Short Classic'),
    AvatarOption(id: 'short_side', label: 'Side Part'),
    AvatarOption(id: 'buzz', label: 'Buzz Cut'),
    AvatarOption(id: 'medium_wavy', label: 'Medium Wavy'),
    AvatarOption(id: 'long_straight', label: 'Long Straight'),
    AvatarOption(id: 'long_wavy', label: 'Long Wavy'),
    AvatarOption(id: 'curly', label: 'Curly'),
    AvatarOption(id: 'bun', label: 'Bun', genderRestriction: 'female'),
    AvatarOption(id: 'none', label: 'None'),
  ];

  static List<AvatarOption> hairStylesForGender(String gender) {
    return hairStyles
        .where((o) => o.genderRestriction == null || o.genderRestriction == gender)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Hair Color
  // ---------------------------------------------------------------------------
  static const List<AvatarOption> hairColors = [
    AvatarOption(id: 'black', label: 'Black', color: Color(0xFF1A1A2E)),
    AvatarOption(id: 'dark_brown', label: 'Dark Brown', color: Color(0xFF3E2723)),
    AvatarOption(id: 'brown', label: 'Brown', color: Color(0xFF5D4037)),
    AvatarOption(id: 'auburn', label: 'Auburn', color: Color(0xFF8B4513)),
    AvatarOption(id: 'blonde', label: 'Blonde', color: Color(0xFFD4A76A)),
    AvatarOption(id: 'grey', label: 'Grey', color: Color(0xFF9E9E9E)),
  ];

  static Color getHairColor(String id) {
    return hairColors.firstWhere((o) => o.id == id, orElse: () => hairColors[0]).color!;
  }

  // ---------------------------------------------------------------------------
  // Default configuration  (returned for new users before customisation)
  // ---------------------------------------------------------------------------
  static Map<String, String> get defaultConfig => {
        'gender': 'neutral',
        'bodyType': 'standard',
        'skinTone': 'medium',
        'faceShape': 'round',
        'eyeStyle': 'friendly',
        'noseStyle': 'small',
        'mouthStyle': 'smile',
        'hairStyle': 'short_classic',
        'hairColor': 'black',
      };
}
