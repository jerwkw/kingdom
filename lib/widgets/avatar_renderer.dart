import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../config/avatar_anchor_system.dart';
import '../config/avatar_parts_config.dart';
import '../config/roles_config.dart';
import '../config/store_config.dart';

/// Renders a character avatar by compositing drawn layers.
///
/// **Swapping to SVG assets:**
/// Each `_draw*` method in [AvatarPainter] corresponds to one future SVG layer.
/// To swap a layer, replace its draw call with an `SvgPicture.asset()` widget
/// positioned in a Stack, using the same relative coordinates. Add `flutter_svg`
/// to pubspec.yaml when ready.
class AvatarRenderer extends StatelessWidget {
  final String roleId;
  final Map<String, String> avatarConfig;
  final double size;

  const AvatarRenderer({
    super.key,
    required this.roleId,
    required this.avatarConfig,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    final role = RolesConfig.getRoleById(roleId);
    final companionItem = StoreConfig.getItemById(avatarConfig['companion'] ?? '');

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main avatar drawn on canvas
          CustomPaint(
            size: Size(size, size),
            painter: AvatarPainter(config: avatarConfig),
          ),

          // Role badge (bottom-left)
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: role.color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: role.color, width: 1.5),
              ),
              child: Text(role.emoji, style: TextStyle(fontSize: size * 0.12)),
            ),
          ),

          // Companion pet (bottom-right, if equipped)
          if (companionItem != null)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                ),
                child: Text(companionItem.emoji, style: TextStyle(fontSize: size * 0.14)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Procedural painter that draws an avatar from configuration values.
///
/// Uses [HeadGeometry] from the anchor system to position every feature
/// relative to the head shape. This ensures cohesion: changing face shape
/// automatically adjusts eye positions, hair fit, neck width, etc.
///
/// Each `_draw*` method corresponds to one visual layer. When real SVG assets
/// are available, replace individual methods with SVG compositing using the
/// same anchor points from [HeadGeometry].
class AvatarPainter extends CustomPainter {
  final Map<String, String> config;

  AvatarPainter({required this.config});

  @override
  void paint(Canvas canvas, Size size) {
    final skinColor = AvatarPartsConfig.getSkinToneColor(config['skinTone'] ?? 'medium');
    final hairColor = AvatarPartsConfig.getHairColor(config['hairColor'] ?? 'black');
    final faceShape = config['faceShape'] ?? 'round';

    // ── Compute anchors once — everything else reads from this ──────────
    final headCenter = Offset(size.width * 0.5, size.height * 0.38);
    final headRadius = size.width * 0.24;

    final geo = HeadGeometry.compute(
      faceShape: faceShape,
      headCenter: headCenter,
      headRadius: headRadius,
      canvasSize: size,
    );

    // Layers drawn bottom-to-top
    _drawBody(canvas, size, skinColor, geo);
    _drawHairBack(canvas, size, hairColor, geo);
    _drawHead(canvas, size, skinColor, geo);
    _drawEars(canvas, skinColor, geo);
    _drawFaceFeatures(canvas, size, geo);
    _drawHairFront(canvas, size, hairColor, geo);
    _drawCosmeticHeadpiece(canvas, size, geo);
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Body
  // ═══════════════════════════════════════════════════════════════════════
  void _drawBody(Canvas canvas, Size size, Color skinColor, HeadGeometry geo) {
    final bodyType = config['bodyType'] ?? 'standard';
    final paint = Paint()..color = skinColor;

    // Neck — positioned from anchor
    final neckTop = geo.neckTop;
    final neckW = geo.neckHalfWidth;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(neckTop.dx, neckTop.dy + size.height * 0.04),
        width: neckW * 2,
        height: size.height * 0.08,
      ),
      paint,
    );

    // Torso
    double shoulderWidth;
    switch (bodyType) {
      case 'broad':
        shoulderWidth = size.width * 0.44;
        break;
      case 'slim':
        shoulderWidth = size.width * 0.30;
        break;
      case 'athletic':
        shoulderWidth = size.width * 0.38;
        break;
      default:
        shoulderWidth = size.width * 0.36;
    }

    final shirtColor = _getShirtColor();
    final shirtPaint = Paint()..color = shirtColor;
    final torsoTop = neckTop.dy + size.height * 0.06;
    final cx = geo.center.dx;
    final torsoRect = RRect.fromRectAndCorners(
      Rect.fromLTRB(cx - shoulderWidth, torsoTop, cx + shoulderWidth, size.height),
      topLeft: const Radius.circular(12),
      topRight: const Radius.circular(12),
    );
    canvas.drawRRect(torsoRect, shirtPaint);
  }

  Color _getShirtColor() {
    final shirtId = config['shirt'];
    if (shirtId != null) {
      final item = StoreConfig.getItemById(shirtId);
      if (item != null) return item.color;
    }
    return const Color(0xFF5C6BC0); // Default indigo shirt
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Head (filled shape + outline)
  // ═══════════════════════════════════════════════════════════════════════
  void _drawHead(Canvas canvas, Size size, Color skinColor, HeadGeometry geo) {
    final paint = Paint()..color = skinColor;
    final outlinePaint = Paint()
      ..color = _darken(skinColor, 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw the head using the clip path from the anchor system
    canvas.drawPath(geo.clipPath, paint);
    canvas.drawPath(geo.clipPath, outlinePaint);
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Ears (positioned from anchors)
  // ═══════════════════════════════════════════════════════════════════════
  void _drawEars(Canvas canvas, Color skinColor, HeadGeometry geo) {
    final earPaint = Paint()..color = skinColor;
    final earW = geo.radius * 0.25;
    final earH = geo.radius * 0.4;

    canvas.drawOval(
      Rect.fromCenter(center: geo.earLeft, width: earW, height: earH),
      earPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: geo.earRight, width: earW, height: earH),
      earPaint,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Face features (eyes, nose, mouth) — clipped to head shape
  // ═══════════════════════════════════════════════════════════════════════
  void _drawFaceFeatures(Canvas canvas, Size size, HeadGeometry geo) {
    // Clip all facial features to the head shape so nothing bleeds outside
    canvas.save();
    canvas.clipPath(geo.clipPath);

    _drawEyes(canvas, geo);
    _drawNose(canvas, geo);
    _drawMouth(canvas, geo);

    canvas.restore();
  }

  // ── Eyes ─────────────────────────────────────────────────────────────
  void _drawEyes(Canvas canvas, HeadGeometry geo) {
    final eyeStyle = config['eyeStyle'] ?? 'friendly';
    final scale = geo.eyeScale;
    final r = geo.radius;

    final whitePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = const Color(0xFF2C2C2C);
    final highlightPaint = Paint()..color = Colors.white;

    double eyeW, eyeH, pupilR;

    switch (eyeStyle) {
      case 'gentle':
        eyeW = r * 0.28 * scale;
        eyeH = r * 0.16 * scale;
        pupilR = r * 0.06 * scale;
        break;
      case 'bright':
        eyeW = r * 0.30 * scale;
        eyeH = r * 0.26 * scale;
        pupilR = r * 0.09 * scale;
        break;
      case 'calm':
        eyeW = r * 0.28 * scale;
        eyeH = r * 0.13 * scale;
        pupilR = r * 0.055 * scale;
        break;
      default: // friendly
        eyeW = r * 0.26 * scale;
        eyeH = r * 0.22 * scale;
        pupilR = r * 0.08 * scale;
    }

    for (final pos in [geo.eyeLeft, geo.eyeRight]) {
      // White
      canvas.drawOval(Rect.fromCenter(center: pos, width: eyeW, height: eyeH), whitePaint);
      // Pupil
      canvas.drawCircle(pos, pupilR, pupilPaint);
      // Highlight
      if (eyeStyle == 'bright') {
        canvas.drawCircle(
          Offset(pos.dx + pupilR * 0.35, pos.dy - pupilR * 0.35),
          pupilR * 0.3,
          highlightPaint,
        );
      }
    }
  }

  // ── Nose ─────────────────────────────────────────────────────────────
  void _drawNose(Canvas canvas, HeadGeometry geo) {
    final noseStyle = config['noseStyle'] ?? 'small';
    final scale = geo.noseScale;
    final r = geo.radius;
    final nc = geo.noseCenter;
    final skinColor = AvatarPartsConfig.getSkinToneColor(config['skinTone'] ?? 'medium');
    final nosePaint = Paint()..color = _darken(skinColor, 0.12);

    switch (noseStyle) {
      case 'button':
        canvas.drawCircle(nc, r * 0.07 * scale, nosePaint);
        break;
      case 'medium':
        final s = scale;
        final path = Path()
          ..moveTo(nc.dx, nc.dy - r * 0.08 * s)
          ..lineTo(nc.dx - r * 0.08 * s, nc.dy + r * 0.06 * s)
          ..lineTo(nc.dx + r * 0.08 * s, nc.dy + r * 0.06 * s)
          ..close();
        canvas.drawPath(path, nosePaint);
        break;
      default: // small
        final s = scale;
        final path = Path()
          ..moveTo(nc.dx, nc.dy - r * 0.05 * s)
          ..lineTo(nc.dx - r * 0.05 * s, nc.dy + r * 0.04 * s)
          ..lineTo(nc.dx + r * 0.05 * s, nc.dy + r * 0.04 * s)
          ..close();
        canvas.drawPath(path, nosePaint);
    }
  }

  // ── Mouth ────────────────────────────────────────────────────────────
  void _drawMouth(Canvas canvas, HeadGeometry geo) {
    final mouthStyle = config['mouthStyle'] ?? 'smile';
    final scale = geo.mouthScale;
    final r = geo.radius;
    final mc = geo.mouthCenter;
    final paint = Paint()
      ..color = const Color(0xFFD32F2F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final halfW = r * 0.22 * scale;

    switch (mouthStyle) {
      case 'grin':
        final path = Path()
          ..moveTo(mc.dx - halfW * 1.2, mc.dy)
          ..quadraticBezierTo(mc.dx, mc.dy + r * 0.2 * scale, mc.dx + halfW * 1.2, mc.dy);
        canvas.drawPath(path, paint);
        // Teeth line
        canvas.drawLine(
          Offset(mc.dx - halfW * 0.6, mc.dy + r * 0.04 * scale),
          Offset(mc.dx + halfW * 0.6, mc.dy + r * 0.04 * scale),
          Paint()..color = Colors.white..strokeWidth = 1.5,
        );
        break;
      case 'neutral':
        canvas.drawLine(
          Offset(mc.dx - halfW, mc.dy),
          Offset(mc.dx + halfW, mc.dy),
          paint,
        );
        break;
      case 'gentle':
        final path = Path()
          ..moveTo(mc.dx - halfW * 0.8, mc.dy)
          ..quadraticBezierTo(mc.dx, mc.dy + r * 0.08 * scale, mc.dx + halfW * 0.8, mc.dy);
        canvas.drawPath(path, paint);
        break;
      default: // smile
        final path = Path()
          ..moveTo(mc.dx - halfW, mc.dy)
          ..quadraticBezierTo(mc.dx, mc.dy + r * 0.15 * scale, mc.dx + halfW, mc.dy);
        canvas.drawPath(path, paint);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Hair (back layer — behind the head for styles that wrap around)
  // ═══════════════════════════════════════════════════════════════════════
  void _drawHairBack(Canvas canvas, Size size, Color hairColor, HeadGeometry geo) {
    final hairStyle = config['hairStyle'] ?? 'short_classic';
    final paint = Paint()..color = hairColor;
    final c = geo.center;
    final r = geo.radius;
    final hw = geo.hairSideHalfWidth;

    switch (hairStyle) {
      case 'medium_wavy':
        // Drapes behind shoulders to mid-chest
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(c.dx, c.dy + r * 0.5),
              width: hw * 2.2,
              height: r * 1.8,
            ),
            Radius.circular(r * 0.4),
          ),
          paint,
        );
        break;

      case 'long_straight':
      case 'long_wavy':
        // Long hair draping behind shoulders
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(c.dx, c.dy + r * 0.8),
              width: hw * 2.3,
              height: r * 2.4,
            ),
            Radius.circular(r * 0.5),
          ),
          paint,
        );
        break;

      case 'curly':
        // Full curly volume behind head
        canvas.drawCircle(
          Offset(c.dx, geo.hairlineTop.dy + r * 0.3),
          hw * 1.25,
          paint,
        );
        break;

      default:
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Hair (front layer — on top of the head)
  // ═══════════════════════════════════════════════════════════════════════
  void _drawHairFront(Canvas canvas, Size size, Color hairColor, HeadGeometry geo) {
    final hairStyle = config['hairStyle'] ?? 'short_classic';
    if (hairStyle == 'none') return;

    final paint = Paint()..color = hairColor;
    final c = geo.center;
    final r = geo.radius;
    final hw = geo.hairHalfWidth;
    final topY = geo.hairlineTop.dy;
    final foreheadY = geo.foreheadY;

    // ── GENERIC FACE PROTECTION MASK ─────────────────────────────────────────
    // Clips out the eye, nose, and mouth area so NO front hair, hat, or SVG asset
    // can ever occlude facial features, regardless of head shape or hairstyle.
    canvas.save();
    final canvasRect = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final safeHairZone = Path.combine(
      PathOperation.difference,
      canvasRect,
      geo.faceFeatureProtectionMask,
    );
    canvas.clipPath(safeHairZone);

    switch (hairStyle) {
      case 'buzz':
        // Conforming hair cap following upper head contour (translucent)
        final capPath = geo.getConformingHairCap(expansionScale: 1.03);
        canvas.drawPath(capPath, paint..color = hairColor.withValues(alpha: 0.65));
        paint.color = hairColor;
        break;

      case 'short_classic':
        // Conforming hair cap that automatically adapts to round, oval, or square head shapes
        final capPath = geo.getConformingHairCap(expansionScale: 1.08);
        canvas.drawPath(capPath, paint);
        break;

      case 'short_side':
        // Conforming base cap + side part stroke
        final capPath = geo.getConformingHairCap(expansionScale: 1.08);
        canvas.drawPath(capPath, paint);

        // Accent part line
        final partLine = Path()
          ..moveTo(c.dx - hw * 0.4, foreheadY - r * 0.2)
          ..quadraticBezierTo(c.dx + hw * 0.2, topY - r * 0.3, c.dx + hw * 0.9, foreheadY);
        canvas.drawPath(
          partLine,
          Paint()
            ..color = _darken(hairColor, 0.2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0,
        );
        break;

      case 'medium_wavy':
        // Conforming top cap + outer side framing locks
        final capPath = geo.getConformingHairCap(expansionScale: 1.10);
        canvas.drawPath(capPath, paint);

        // Side locks framing cheeks
        final locksPath = Path();
        // Right side lock
        locksPath.moveTo(c.dx + hw * 0.8, foreheadY);
        locksPath.quadraticBezierTo(c.dx + hw * 1.25, c.dy + r * 0.2, c.dx + hw * 0.9, c.dy + r * 0.6);
        locksPath.quadraticBezierTo(c.dx + hw * 0.75, c.dy + r * 0.2, c.dx + hw * 0.8, foreheadY);
        // Left side lock
        locksPath.moveTo(c.dx - hw * 0.8, foreheadY);
        locksPath.quadraticBezierTo(c.dx - hw * 1.25, c.dy + r * 0.2, c.dx - hw * 0.9, c.dy + r * 0.6);
        locksPath.quadraticBezierTo(c.dx - hw * 0.75, c.dy + r * 0.2, c.dx - hw * 0.8, foreheadY);
        locksPath.close();
        canvas.drawPath(locksPath, paint);
        break;

      case 'long_straight':
        // Conforming top cap + long side strands
        final capPath = geo.getConformingHairCap(expansionScale: 1.10);
        canvas.drawPath(capPath, paint);

        final strandsPath = Path();
        // Right strand
        strandsPath.addRect(Rect.fromLTRB(c.dx + hw * 0.8, foreheadY, c.dx + hw * 1.2, c.dy + r * 0.9));
        // Left strand
        strandsPath.addRect(Rect.fromLTRB(c.dx - hw * 1.2, foreheadY, c.dx - hw * 0.8, c.dy + r * 0.9));
        canvas.drawPath(strandsPath, paint);
        break;

      case 'long_wavy':
        // Conforming top cap + wavy side strands
        final capPath = geo.getConformingHairCap(expansionScale: 1.12);
        canvas.drawPath(capPath, paint);

        final wavyPath = Path();
        // Right wavy strand
        wavyPath.moveTo(c.dx + hw * 0.8, foreheadY);
        wavyPath.quadraticBezierTo(c.dx + hw * 1.30, c.dy + r * 0.3, c.dx + hw * 0.95, c.dy + r * 0.95);
        wavyPath.quadraticBezierTo(c.dx + hw * 0.70, c.dy + r * 0.3, c.dx + hw * 0.8, foreheadY);
        // Left wavy strand
        wavyPath.moveTo(c.dx - hw * 0.8, foreheadY);
        wavyPath.quadraticBezierTo(c.dx - hw * 1.30, c.dy + r * 0.3, c.dx - hw * 0.95, c.dy + r * 0.95);
        wavyPath.quadraticBezierTo(c.dx - hw * 0.70, c.dy + r * 0.3, c.dx - hw * 0.8, foreheadY);
        wavyPath.close();
        canvas.drawPath(wavyPath, paint);
        break;

      case 'curly':
        // Cluster of curly puffs outlining upper head contour
        final puffY = topY + r * 0.15;
        for (double t = -1.0; t <= 1.0; t += 0.25) {
          final cx = c.dx + hw * t * 1.05;
          final cy = puffY - (1.0 - (t * t * 0.7)) * r * 0.22;
          canvas.drawCircle(Offset(cx, cy), r * 0.32, paint);
        }
        break;

      case 'bun':
        // Conforming top cap + high bun
        final capPath = geo.getConformingHairCap(expansionScale: 1.08);
        canvas.drawPath(capPath, paint);
        // Top bun circle (un-clipped)
        canvas.restore(); // restore before drawing bun on top of skull
        canvas.drawCircle(
          Offset(c.dx, topY - r * 0.30),
          r * 0.35,
          paint,
        );
        return; // already restored

      default:
        final capPath = geo.getConformingHairCap(expansionScale: 1.05);
        canvas.drawPath(capPath, paint);
    }

    canvas.restore();
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Cosmetic headpiece (on top of hair)
  // ═══════════════════════════════════════════════════════════════════════
  void _drawCosmeticHeadpiece(Canvas canvas, Size size, HeadGeometry geo) {
    final headpieceId = config['headpiece'];
    if (headpieceId == null) return;

    // Headpiece rendered as text emoji for now — swappable to SVG asset
    final item = StoreConfig.getItemById(headpieceId);
    if (item == null) return;

    final textPainter = TextPainter(
      text: TextSpan(text: item.emoji, style: TextStyle(fontSize: geo.radius * 0.6)),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        geo.center.dx - textPainter.width / 2,
        geo.hairlineTop.dy - geo.radius * 0.45,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Helpers
  // ═══════════════════════════════════════════════════════════════════════
  static Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  @override
  bool shouldRepaint(covariant AvatarPainter oldDelegate) {
    return !mapEquals(oldDelegate.config, config);
  }
}
