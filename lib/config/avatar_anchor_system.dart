import 'package:flutter/material.dart';

/// Computed geometry and anchor points for a specific head shape.
///
/// Every facial feature, hair style, and body attachment reads from this
/// object instead of computing positions independently. This guarantees
/// cohesion: when the head shape changes, all dependent parts move with it.
///
/// **To add a new head shape:**
///   1. Add a case to [HeadGeometry.compute].
///   2. Define the clip path, upper head path, anchors, and scale factors.
///   3. Everything else (renderer, hair caps, future SVG assets) adapts automatically.
class HeadGeometry {
  // ── Core shape ──────────────────────────────────────────────────────────
  /// The centre of the head in canvas coordinates.
  final Offset center;

  /// The base radius used to derive all proportions.
  final double radius;

  /// The face shape id (e.g. 'round', 'oval', 'square').
  final String faceShape;

  /// A closed [Path] describing the head outline. Used for clipping features
  /// so nothing renders outside the face, and for drawing the head fill/stroke.
  final Path clipPath;

  /// A [Path] describing ONLY the top half / upper contour of the head
  /// (from left ear level up over skull to right ear level).
  /// Used to generate skull-conforming hair caps generically.
  final Path upperHeadPath;

  /// The axis-aligned bounding rectangle of [clipPath].
  final Rect boundingRect;

  // ── Feature anchors ─────────────────────────────────────────────────────
  /// Left-eye centre position.
  final Offset eyeLeft;

  /// Right-eye centre position.
  final Offset eyeRight;

  /// Nose centre position.
  final Offset noseCenter;

  /// Mouth centre position.
  final Offset mouthCenter;

  /// Left-ear centre position.
  final Offset earLeft;

  /// Right-ear centre position.
  final Offset earRight;

  // ── Protected Zone & Hair Anchors ───────────────────────────────────────
  /// A protected zone encompassing eyes, nose, and mouth. Front hair layers
  /// must NEVER fill into this path.
  final Path faceFeatureProtectionMask;

  /// The mid-forehead Y position. Hair bangs sit at or above this Y line.
  final double foreheadY;

  /// The topmost point of the hairline (where hair caps originate).
  final Offset hairlineTop;

  /// Half-width of the hair at the hairline level.
  final double hairHalfWidth;

  /// The vertical position where hair side-draping starts (ear level).
  final double hairSideY;

  /// Half-width of the hair at ear/side level for styles that wrap around.
  final double hairSideHalfWidth;

  // ── Body / neck ─────────────────────────────────────────────────────────
  /// Top-centre of the neck column.
  final Offset neckTop;

  /// Half-width of the neck.
  final double neckHalfWidth;

  // ── Proportion multipliers ──────────────────────────────────────────────
  /// Scale multiplier for eye size (1.0 = baseline round).
  final double eyeScale;

  /// Scale multiplier for nose size.
  final double noseScale;

  /// Scale multiplier for mouth width.
  final double mouthScale;

  const HeadGeometry._({
    required this.center,
    required this.radius,
    required this.faceShape,
    required this.clipPath,
    required this.upperHeadPath,
    required this.boundingRect,
    required this.eyeLeft,
    required this.eyeRight,
    required this.noseCenter,
    required this.mouthCenter,
    required this.earLeft,
    required this.earRight,
    required this.faceFeatureProtectionMask,
    required this.foreheadY,
    required this.hairlineTop,
    required this.hairHalfWidth,
    required this.hairSideY,
    required this.hairSideHalfWidth,
    required this.neckTop,
    required this.neckHalfWidth,
    required this.eyeScale,
    required this.noseScale,
    required this.mouthScale,
  });

  /// Compute anchors for a given [faceShape] placed at [headCenter] with
  /// the given base [headRadius] within canvas [size].
  factory HeadGeometry.compute({
    required String faceShape,
    required Offset headCenter,
    required double headRadius,
    required Size canvasSize,
  }) {
    switch (faceShape) {
      case 'oval':
        return _computeOval(headCenter, headRadius, canvasSize);
      case 'square':
        return _computeSquare(headCenter, headRadius, canvasSize);
      default: // 'round'
        return _computeRound(headCenter, headRadius, canvasSize);
    }
  }

  /// Generates a skull-conforming top hair cap for THIS specific head shape.
  ///
  /// Takes the upper head contour ([upperHeadPath]), scales it slightly outwards
  /// by [expansionScale] for volume, and caps it at [foreheadY].
  /// Because it uses [upperHeadPath], a square head produces a squarish hair cap,
  /// an oval head produces a tall oval hair cap, and a round head produces a round cap.
  Path getConformingHairCap({double expansionScale = 1.08}) {
    final capPath = Path();
    final matrix = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 0)
      ..scaleByDouble(expansionScale, expansionScale, 1.0, 0)
      ..translateByDouble(-center.dx, -center.dy, 0, 0);

    final expandedUpper = Path();
    expandedUpper.addPath(upperHeadPath, Offset.zero, matrix4: matrix.storage);

    capPath.addPath(expandedUpper, Offset.zero);
    // Cap bottom of hair at forehead line
    capPath.lineTo(center.dx + hairHalfWidth * expansionScale, foreheadY);
    capPath.quadraticBezierTo(
      center.dx,
      foreheadY - radius * 0.12,
      center.dx - hairHalfWidth * expansionScale,
      foreheadY,
    );
    capPath.close();

    return capPath;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Round (baseline)
  // ═══════════════════════════════════════════════════════════════════════
  static HeadGeometry _computeRound(Offset c, double r, Size size) {
    final clipPath = Path()..addOval(Rect.fromCircle(center: c, radius: r));

    final upperHeadPath = Path()
      ..arcTo(
        Rect.fromCircle(center: c, radius: r),
        0.0, // starting at 3 o'clock (right ear)
        -3.141592653589793, // sweeping counter-clockwise to 9 o'clock (left ear)
        false,
      );

    final eyeSpacing = r * 0.38;
    final eyeY = c.dy - r * 0.1;
    final eyeLeft = Offset(c.dx - eyeSpacing, eyeY);
    final eyeRight = Offset(c.dx + eyeSpacing, eyeY);
    final noseCenter = Offset(c.dx, c.dy + r * 0.15);
    final mouthCenter = Offset(c.dx, c.dy + r * 0.42);

    final eyeTopY = eyeY - r * 0.13;
    final hairlineTopY = c.dy - r * 1.0;
    final foreheadY = (hairlineTopY + eyeTopY) * 0.5;

    final protectionMask = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            eyeLeft.dx - r * 0.12,
            eyeTopY - r * 0.05,
            eyeRight.dx + r * 0.12,
            mouthCenter.dy + r * 0.15,
          ),
          Radius.circular(r * 0.2),
        ),
      );

    return HeadGeometry._(
      center: c,
      radius: r,
      faceShape: 'round',
      clipPath: clipPath,
      upperHeadPath: upperHeadPath,
      boundingRect: Rect.fromCircle(center: c, radius: r),
      eyeLeft: eyeLeft,
      eyeRight: eyeRight,
      noseCenter: noseCenter,
      mouthCenter: mouthCenter,
      earLeft: Offset(c.dx - r * 0.95, c.dy),
      earRight: Offset(c.dx + r * 0.95, c.dy),
      faceFeatureProtectionMask: protectionMask,
      foreheadY: foreheadY,
      hairlineTop: Offset(c.dx, hairlineTopY),
      hairHalfWidth: r * 1.0,
      hairSideY: c.dy,
      hairSideHalfWidth: r * 1.0,
      neckTop: Offset(c.dx, c.dy + r * 0.85),
      neckHalfWidth: r * 0.35,
      eyeScale: 1.0,
      noseScale: 1.0,
      mouthScale: 1.0,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Oval  (taller & narrower → features closer together, shifted up)
  // ═══════════════════════════════════════════════════════════════════════
  static HeadGeometry _computeOval(Offset c, double r, Size size) {
    final hw = r * 0.9;
    final hh = r * 1.1;

    final clipRect = Rect.fromCenter(center: c, width: hw * 2, height: hh * 2);
    final clipPath = Path()..addOval(clipRect);

    final upperHeadPath = Path()
      ..arcTo(clipRect, 0.0, -3.141592653589793, false);

    final eyeSpacing = r * 0.34;
    final eyeY = c.dy - r * 0.12;
    final eyeLeft = Offset(c.dx - eyeSpacing, eyeY);
    final eyeRight = Offset(c.dx + eyeSpacing, eyeY);
    final noseCenter = Offset(c.dx, c.dy + r * 0.12);
    final mouthCenter = Offset(c.dx, c.dy + r * 0.38);

    final eyeTopY = eyeY - r * 0.12;
    final hairlineTopY = c.dy - hh;
    final foreheadY = (hairlineTopY + eyeTopY) * 0.5;

    final protectionMask = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            eyeLeft.dx - r * 0.12,
            eyeTopY - r * 0.05,
            eyeRight.dx + r * 0.12,
            mouthCenter.dy + r * 0.15,
          ),
          Radius.circular(r * 0.2),
        ),
      );

    return HeadGeometry._(
      center: c,
      radius: r,
      faceShape: 'oval',
      clipPath: clipPath,
      upperHeadPath: upperHeadPath,
      boundingRect: clipRect,
      eyeLeft: eyeLeft,
      eyeRight: eyeRight,
      noseCenter: noseCenter,
      mouthCenter: mouthCenter,
      earLeft: Offset(c.dx - hw * 0.98, c.dy),
      earRight: Offset(c.dx + hw * 0.98, c.dy),
      faceFeatureProtectionMask: protectionMask,
      foreheadY: foreheadY,
      hairlineTop: Offset(c.dx, hairlineTopY),
      hairHalfWidth: hw * 1.05,
      hairSideY: c.dy,
      hairSideHalfWidth: hw * 1.05,
      neckTop: Offset(c.dx, c.dy + hh * 0.8),
      neckHalfWidth: r * 0.30,
      eyeScale: 0.92,
      noseScale: 0.90,
      mouthScale: 0.90,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Square  (wider & more angular → features spread out, squarish top)
  // ═══════════════════════════════════════════════════════════════════════
  static HeadGeometry _computeSquare(Offset c, double r, Size size) {
    final hw = r * 1.0;
    final hh = r * 1.05;
    final cornerR = r * 0.3;

    final rect = Rect.fromCenter(center: c, width: hw * 2, height: hh * 2);
    final clipPath = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(cornerR)));

    // Upper head contour capturing the squarish top corners!
    final upperHeadPath = Path()
      ..moveTo(c.dx + hw, c.dy)
      ..lineTo(c.dx + hw, c.dy - hh + cornerR)
      ..quadraticBezierTo(c.dx + hw, c.dy - hh, c.dx + hw - cornerR, c.dy - hh)
      ..lineTo(c.dx - hw + cornerR, c.dy - hh)
      ..quadraticBezierTo(c.dx - hw, c.dy - hh, c.dx - hw, c.dy - hh + cornerR)
      ..lineTo(c.dx - hw, c.dy);

    final eyeSpacing = r * 0.42;
    final eyeY = c.dy - r * 0.08;
    final eyeLeft = Offset(c.dx - eyeSpacing, eyeY);
    final eyeRight = Offset(c.dx + eyeSpacing, eyeY);
    final noseCenter = Offset(c.dx, c.dy + r * 0.18);
    final mouthCenter = Offset(c.dx, c.dy + r * 0.46);

    final eyeTopY = eyeY - r * 0.14;
    final hairlineTopY = c.dy - hh;
    final foreheadY = (hairlineTopY + eyeTopY) * 0.5;

    final protectionMask = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            eyeLeft.dx - r * 0.12,
            eyeTopY - r * 0.05,
            eyeRight.dx + r * 0.12,
            mouthCenter.dy + r * 0.15,
          ),
          Radius.circular(r * 0.2),
        ),
      );

    return HeadGeometry._(
      center: c,
      radius: r,
      faceShape: 'square',
      clipPath: clipPath,
      upperHeadPath: upperHeadPath,
      boundingRect: rect,
      eyeLeft: eyeLeft,
      eyeRight: eyeRight,
      noseCenter: noseCenter,
      mouthCenter: mouthCenter,
      earLeft: Offset(c.dx - hw * 0.98, c.dy - r * 0.05),
      earRight: Offset(c.dx + hw * 0.98, c.dy - r * 0.05),
      faceFeatureProtectionMask: protectionMask,
      foreheadY: foreheadY,
      hairlineTop: Offset(c.dx, hairlineTopY),
      hairHalfWidth: hw * 1.05,
      hairSideY: c.dy,
      hairSideHalfWidth: hw * 1.05,
      neckTop: Offset(c.dx, c.dy + hh * 0.82),
      neckHalfWidth: r * 0.38,
      eyeScale: 1.05,
      noseScale: 1.05,
      mouthScale: 1.08,
    );
  }
}
