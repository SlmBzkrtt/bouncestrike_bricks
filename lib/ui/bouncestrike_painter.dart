import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/bouncestrike_constants.dart';
import '../engine/bouncestrike_controller.dart';
import '../engine/bouncestrike_physics.dart';
import '../models/bouncestrike_models.dart';

/// High-performance CustomPainter operating in the virtual logical space
/// ([BounceStrikeConstants.logicalWidth] x [BounceStrikeConstants.logicalHeight] = 1080x1470).
///
/// Key optimizations:
/// 1. Class-level reusable [Paint] instances avoid per-frame GC allocations.
/// 2. Zero [MaskFilter.blur] inside entity/ball loops (uses layered alpha halos).
/// 3. LRU-bounded [TextPainter] cache avoids expensive text layout on every frame.
/// 4. Driven directly by `Listenable.merge([controller.repaintNotifier, pulseAnimation])`
///    without rebuilding widget trees.
class BounceStrikePainter extends CustomPainter {
  final BounceStrikeController controller;
  final Animation<double> pulseAnimation;

  // --- Pre-allocated Class-Level Reusable Paint Objects ---
  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Paint _borderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round;
  final Paint _glowPaint = Paint()..style = PaintingStyle.fill;
  final Paint _gridPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.2;
  final Paint _trailPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _particlePaint = Paint()..style = PaintingStyle.fill;

  final math.Random _shakeRng = math.Random();

  // Cached TextPainters for brick HP numbers & HUD counters
  static final Map<String, TextPainter> _textCache = <String, TextPainter>{};

  BounceStrikePainter({
    required this.controller,
    required this.pulseAnimation,
  }) : super(
          repaint: Listenable.merge([
            controller.repaintNotifier,
            pulseAnimation,
          ]),
        );

  double get pulseValue => pulseAnimation.value;

  TextPainter _getCachedTextPainter({
    required String text,
    required double fontSize,
    required Color color,
  }) {
    final key = '$text|${fontSize.toStringAsFixed(1)}|${color.toARGB32()}';
    final existing = _textCache[key];
    if (existing != null) return existing;

    if (_textCache.length > 512) {
      _textCache.clear();
    }

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
          shadows: const [
            Shadow(color: Colors.black, blurRadius: 6.0),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    _textCache[key] = tp;
    return tp;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    canvas.save();

    // Scale physical canvas to virtual logical coordinate space (1080 x 1470)
    final scaleX = size.width / BounceStrikeConstants.logicalWidth;
    final scaleY = size.height / BounceStrikeConstants.logicalHeight;
    canvas.scale(scaleX, scaleY);

    const logicalSize = Size(
      BounceStrikeConstants.logicalWidth,
      BounceStrikeConstants.logicalHeight,
    );

    if (controller.screenShake > 0.1) {
      final dx = (_shakeRng.nextDouble() - 0.5) * controller.screenShake * 4.5;
      final dy = (_shakeRng.nextDouble() - 0.5) * controller.screenShake * 4.5;
      canvas.translate(dx, dy);
    }

    _drawThemeBackground(canvas, logicalSize);
    _drawDangerZone(canvas, logicalSize);
    _drawShockwaves(canvas);
    _drawLaserBeams(canvas, logicalSize);
    _drawEntities(canvas);
    _drawLightningArcs(canvas);
    _drawTrajectory(canvas);
    _drawLauncherAndCharacter(canvas, logicalSize);
    _drawBalls(canvas);
    _drawParticles(canvas);
    _drawFloatingTexts(canvas);

    canvas.restore();
  }

  void _drawThemeBackground(Canvas canvas, Size size) {
    const cellSize = BounceStrikeConstants.cellSize;
    final theme = controller.selectedTheme;
    const playHeight = BounceStrikeConstants.dangerRow * cellSize;

    switch (theme.id) {
      case GameThemeId.football:
        for (int r = 0; r < BounceStrikeConstants.dangerRow; r++) {
          _fillPaint.shader = null;
          _fillPaint.color = r.isEven
              ? const Color(0xFF165B2D).withValues(alpha: 0.55)
              : const Color(0xFF0E401F).withValues(alpha: 0.55);
          canvas.drawRect(
            Rect.fromLTWH(0, r * cellSize, size.width, cellSize),
            _fillPaint,
          );
        }

        _fillPaint.shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.10 + 0.04 * pulseValue),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, playHeight * 0.6));
        final leftBeam = Path()
          ..moveTo(0, 0)
          ..lineTo(size.width * 0.45, 0)
          ..lineTo(size.width * 0.75, playHeight * 0.55)
          ..lineTo(0, playHeight * 0.4)
          ..close();
        canvas.drawPath(leftBeam, _fillPaint);
        _fillPaint.shader = null;

        _strokePaint
          ..color = Colors.white.withValues(alpha: 0.28)
          ..strokeWidth = 5.0;

        final pitchRect =
            Rect.fromLTWH(18, 18, size.width - 36, playHeight - 36);
        canvas.drawRect(pitchRect, _strokePaint);

        const goalWidth = cellSize * 2.6;
        final goalRect = Rect.fromCenter(
          center: Offset(size.width / 2, 34),
          width: goalWidth,
          height: 38,
        );
        _fillPaint.color = Colors.white.withValues(alpha: 0.12);
        canvas.drawRect(goalRect, _fillPaint);
        canvas.drawRect(goalRect, _strokePaint);

        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(size.width / 2, cellSize * 1.15),
            width: cellSize * 4.8,
            height: cellSize * 2.1,
          ),
          _strokePaint,
        );
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(size.width / 2, cellSize * 2.2),
            width: cellSize * 1.8,
            height: cellSize * 1.1,
          ),
          0,
          math.pi,
          false,
          _strokePaint,
        );

        const centerY = playHeight * 0.52;
        canvas.drawLine(
          const Offset(18, centerY),
          Offset(size.width - 18, centerY),
          _strokePaint,
        );
        canvas.drawCircle(
          Offset(size.width / 2, centerY),
          cellSize * 1.45,
          _strokePaint,
        );
        _fillPaint.color = Colors.white.withValues(alpha: 0.40);
        canvas.drawCircle(
          Offset(size.width / 2, centerY),
          11.0,
          _fillPaint,
        );

        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(size.width / 2, playHeight - cellSize * 1.05),
            width: cellSize * 4.8,
            height: cellSize * 1.9,
          ),
          _strokePaint,
        );
        break;

      case GameThemeId.space:
        _fillPaint.shader = null;
        _fillPaint.color = const Color(0xFF00E5FF).withValues(alpha: 0.06);
        canvas.drawCircle(
          Offset(size.width * 0.3, playHeight * 0.32),
          cellSize * 2.8,
          _fillPaint,
        );
        _fillPaint.color = const Color(0xFFE040FB).withValues(alpha: 0.06);
        canvas.drawCircle(
          Offset(size.width * 0.75, playHeight * 0.62),
          cellSize * 2.4,
          _fillPaint,
        );

        final planetCenter = Offset(size.width * 0.76, playHeight * 0.22);
        _fillPaint.color = const Color(0xFF1E2F6F).withValues(alpha: 0.55);
        canvas.drawCircle(planetCenter, cellSize * 0.85, _fillPaint);

        canvas.save();
        canvas.translate(planetCenter.dx, planetCenter.dy);
        canvas.rotate(-0.35);
        _strokePaint
          ..color = const Color(0xFF00E5FF).withValues(alpha: 0.25)
          ..strokeWidth = 6.5;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: cellSize * 2.6,
            height: cellSize * 0.55,
          ),
          _strokePaint,
        );
        canvas.restore();

        _fillPaint.color =
            Colors.white.withValues(alpha: 0.28 + 0.15 * pulseValue);
        for (int i = 0; i < 24; i++) {
          final sx = ((i * 73) % 97) / 97.0 * size.width;
          final sy = ((i * 41) % 89) / 89.0 * playHeight;
          canvas.drawCircle(
            Offset(sx, sy),
            (i % 4 == 0) ? 5.0 : 3.2,
            _fillPaint,
          );
        }
        break;

      case GameThemeId.ww1:
        final mapCenter = Offset(size.width * 0.5, playHeight * 0.48);
        _strokePaint
          ..color = const Color(0xFFFFB300).withValues(alpha: 0.14)
          ..strokeWidth = 3.6;
        canvas.drawCircle(mapCenter, cellSize * 1.4, _strokePaint);
        canvas.drawCircle(mapCenter, cellSize * 2.4, _strokePaint);
        canvas.drawCircle(mapCenter, cellSize * 3.4, _strokePaint);

        canvas.drawLine(
          mapCenter + const Offset(-cellSize * 3.7, 0),
          mapCenter + const Offset(cellSize * 3.7, 0),
          _strokePaint,
        );
        canvas.drawLine(
          mapCenter + const Offset(0, -cellSize * 3.7),
          mapCenter + const Offset(0, cellSize * 3.7),
          _strokePaint,
        );
        break;

      case GameThemeId.samurai:
        final moonCenter = Offset(size.width * 0.5, playHeight * 0.24);
        _fillPaint.shader = null;
        _fillPaint.color =
            const Color(0xFFFF1744).withValues(alpha: 0.16 + 0.05 * pulseValue);
        canvas.drawCircle(moonCenter, cellSize * 1.65, _fillPaint);

        _strokePaint
          ..color = const Color(0xFFFF4081).withValues(alpha: 0.22)
          ..strokeWidth = 8.0;
        canvas.drawLine(
          moonCenter + const Offset(-cellSize * 1.4, -cellSize * 0.4),
          moonCenter + const Offset(cellSize * 1.4, -cellSize * 0.4),
          _strokePaint,
        );
        canvas.drawLine(
          moonCenter + const Offset(-cellSize * 1.1, -cellSize * 0.1),
          moonCenter + const Offset(cellSize * 1.1, -cellSize * 0.1),
          _strokePaint,
        );
        canvas.drawLine(
          moonCenter + const Offset(-cellSize * 0.85, -cellSize * 0.4),
          moonCenter + const Offset(-cellSize * 0.85, cellSize * 1.1),
          _strokePaint,
        );
        canvas.drawLine(
          moonCenter + const Offset(cellSize * 0.85, -cellSize * 0.4),
          moonCenter + const Offset(cellSize * 0.85, cellSize * 1.1),
          _strokePaint,
        );

        _fillPaint.color = const Color(0xFFFF80AB).withValues(alpha: 0.22);
        for (int i = 0; i < 12; i++) {
          final px = ((i * 61) % 89) / 89.0 * size.width;
          final py = ((i * 53) % 83) / 83.0 * playHeight;
          canvas.drawOval(
            Rect.fromCenter(center: Offset(px, py), width: 16, height: 9.5),
            _fillPaint,
          );
        }
        break;

      case GameThemeId.magma:
        final calderaCenter = Offset(size.width * 0.5, playHeight * 0.48);
        _fillPaint.shader = null;
        _fillPaint.color =
            const Color(0xFFFF3D00).withValues(alpha: 0.11 + 0.05 * pulseValue);
        canvas.drawCircle(calderaCenter, cellSize * 2.8, _fillPaint);

        _strokePaint
          ..color = const Color(0xFFFF6D00)
              .withValues(alpha: 0.24 + 0.10 * pulseValue)
          ..strokeWidth = 6.0;
        final veinPath = Path()
          ..moveTo(size.width * 0.15, playHeight * 0.12)
          ..lineTo(size.width * 0.38, playHeight * 0.35)
          ..lineTo(size.width * 0.28, playHeight * 0.65)
          ..lineTo(size.width * 0.45, playHeight * 0.90)
          ..moveTo(size.width * 0.85, playHeight * 0.18)
          ..lineTo(size.width * 0.60, playHeight * 0.48)
          ..lineTo(size.width * 0.74, playHeight * 0.82);
        canvas.drawPath(veinPath, _strokePaint);
        break;
    }

    _gridPaint.color = theme.gridColor.withValues(alpha: 0.32);

    for (int c = 1; c < BounceStrikeConstants.cols; c++) {
      final x = c * cellSize;
      canvas.drawLine(Offset(x, 0), Offset(x, playHeight), _gridPaint);
    }
    for (int r = 1; r <= BounceStrikeConstants.dangerRow; r++) {
      final y = r * cellSize;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), _gridPaint);
    }
  }

  void _drawDangerZone(Canvas canvas, Size size) {
    const cellSize = BounceStrikeConstants.cellSize;
    const dangerY = BounceStrikeConstants.dangerRow * cellSize;
    final theme = controller.selectedTheme;

    final isCritical = controller.entities
        .any((e) => e.isBrick && e.row >= BounceStrikeConstants.dangerRow - 2);

    final dangerAlpha = isCritical ? (0.60 + 0.38 * pulseValue) : 0.48;
    _strokePaint
      ..color = const Color(0xFFFF1744).withValues(alpha: dangerAlpha)
      ..strokeWidth = isCritical ? 7.5 : 5.5;

    if (theme.id == GameThemeId.ww1) {
      canvas.drawLine(
        const Offset(0, dangerY),
        Offset(size.width, dangerY),
        _strokePaint,
      );
      for (double x = 42; x < size.width; x += 72) {
        canvas.drawLine(
          Offset(x - 12, dangerY - 12),
          Offset(x + 12, dangerY + 12),
          _strokePaint,
        );
        canvas.drawLine(
          Offset(x + 12, dangerY - 12),
          Offset(x - 12, dangerY + 12),
          _strokePaint,
        );
      }
    } else {
      const dashWidth = 24.0;
      const dashSpace = 15.0;
      double startX = 0.0;
      while (startX < size.width) {
        canvas.drawLine(
          Offset(startX, dangerY),
          Offset(math.min(startX + dashWidth, size.width), dangerY),
          _strokePaint,
        );
        startX += dashWidth + dashSpace;
      }
    }

    if (isCritical) {
      final warnRect = Rect.fromLTWH(
        0,
        (BounceStrikeConstants.dangerRow - 2) * cellSize,
        size.width,
        cellSize * 2,
      );
      _fillPaint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFFF1744).withValues(alpha: 0.0),
          const Color(0xFFFF1744).withValues(alpha: 0.24 * pulseValue),
        ],
      ).createShader(warnRect);
      canvas.drawRect(warnRect, _fillPaint);
      _fillPaint.shader = null;
    }
  }

  void _drawShockwaves(Canvas canvas) {
    for (final sw in controller.shockwaves) {
      final ease = Curves.easeOutQuart.transform(sw.progress.clamp(0.0, 1.0));
      final radius = sw.maxRadius * ease;
      final alpha = (1.0 - sw.progress).clamp(0.0, 1.0);

      _strokePaint
        ..color = sw.color.withValues(alpha: alpha * 0.65)
        ..strokeWidth = sw.strokeWidth * 2.5 * alpha;
      canvas.drawCircle(sw.origin, radius, _strokePaint);

      _strokePaint
        ..color = Colors.white.withValues(alpha: alpha * 0.35)
        ..strokeWidth = 4.0;
      canvas.drawCircle(sw.origin, radius * 0.72, _strokePaint);
    }
  }

  void _drawLightningArcs(Canvas canvas) {
    for (final arc in controller.lightningArcs) {
      final alpha = arc.life.clamp(0.0, 1.0);
      final path = Path();
      for (int i = 0; i < arc.jaggedPoints.length; i++) {
        final pt = arc.jaggedPoints[i];
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      _strokePaint
        ..color = arc.color.withValues(alpha: alpha * 0.45)
        ..strokeWidth = 14.0;
      canvas.drawPath(path, _strokePaint);

      _strokePaint
        ..color = Colors.white.withValues(alpha: alpha)
        ..strokeWidth = 5.5;
      canvas.drawPath(path, _strokePaint);
    }
  }

  void _drawEntities(Canvas canvas) {
    const cellSize = BounceStrikeConstants.cellSize;
    for (final entity in controller.entities) {
      final rect =
          BounceStrikePhysics.cellRect(entity.col, entity.visualRow, cellSize);

      canvas.save();
      if (entity.scale != 1.0) {
        final c = rect.center;
        canvas.translate(c.dx, c.dy);
        canvas.scale(entity.scale);
        canvas.translate(-c.dx, -c.dy);
      }

      if (entity.isBrick) {
        _drawBrick(canvas, entity, rect);
      } else if (entity.isItem) {
        _drawItem(canvas, entity, rect);
      }
      canvas.restore();
    }
  }

  void _drawBrick(Canvas canvas, GridEntity brick, Rect rect) {
    final theme = controller.selectedTheme;
    Color baseColor;
    switch (brick.modifier) {
      case BrickModifier.bomb:
        baseColor = const Color(0xFFFF3D00);
        break;
      case BrickModifier.electric:
        baseColor = theme.accentColor;
        break;
      case BrickModifier.goldCore:
        baseColor = const Color(0xFFFFD740);
        break;
      case BrickModifier.boss:
        baseColor = const Color(0xFFE040FB);
        break;
      case BrickModifier.none:
        baseColor = controller.colorForHp(brick.hp);
        break;
    }

    final color = Color.lerp(baseColor, Colors.white, brick.hitFlash * 0.80)!;

    _fillPaint.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        color.withValues(alpha: 0.48),
        color.withValues(alpha: 0.18),
      ],
    ).createShader(rect);

    _strokePaint
      ..color = color.withValues(alpha: 0.25)
      ..strokeWidth = 11.0;

    _borderPaint
      ..color = color
      ..strokeWidth = brick.modifier == BrickModifier.boss ? 7.5 : 5.8;

    Offset textCenter = rect.center;

    if (brick.brickShape == BrickShape.square) {
      final radius = theme.id == GameThemeId.ww1 ? 7.5 : 16.0;
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
      canvas.drawRRect(rrect, _fillPaint);
      canvas.drawRRect(rrect, _strokePaint);
      canvas.drawRRect(rrect, _borderPaint);

      _drawThemeBrickOrnament(canvas, rect, color, theme.id);
    } else {
      final pts = BounceStrikePhysics.polygonVertices(rect, brick.brickShape!);
      final path = Path()..addPolygon(pts, true);
      canvas.drawPath(path, _fillPaint);
      canvas.drawPath(path, _strokePaint);
      canvas.drawPath(path, _borderPaint);

      double sumX = 0, sumY = 0;
      for (final p in pts) {
        sumX += p.dx;
        sumY += p.dy;
      }
      textCenter = Offset(sumX / pts.length, sumY / pts.length);
    }
    _fillPaint.shader = null;

    if (brick.damageRatio < 0.55) {
      _strokePaint
        ..color = Colors.white.withValues(alpha: 0.42)
        ..strokeWidth = 3.5;
      canvas.drawLine(
        textCenter + Offset(-rect.width * 0.20, -rect.height * 0.20),
        textCenter + Offset(rect.width * 0.10, rect.height * 0.14),
        _strokePaint,
      );
    }

    final prefix = _themeModifierIcon(theme.id, brick.modifier);
    final label = '$prefix${brick.hp}';
    final isTriangle = brick.brickShape == BrickShape.triangleBL ||
        brick.brickShape == BrickShape.triangleBR ||
        brick.brickShape == BrickShape.triangleTL ||
        brick.brickShape == BrickShape.triangleTR;

    final fontSize = isTriangle
        ? (rect.width * 0.25).clamp(22.0, 34.0)
        : (rect.width * 0.30).clamp(25.0, 40.0);

    final tp = _getCachedTextPainter(
      text: label,
      fontSize: fontSize,
      color: Colors.white,
    );

    tp.paint(
      canvas,
      textCenter - Offset(tp.width / 2, tp.height / 2),
    );
  }

  void _drawThemeBrickOrnament(
    Canvas canvas,
    Rect rect,
    Color color,
    GameThemeId themeId,
  ) {
    _strokePaint
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 3.0;

    switch (themeId) {
      case GameThemeId.football:
        final inner = rect.deflate(10.0);
        canvas.drawLine(
          Offset(inner.left, inner.top + 8),
          Offset(inner.right, inner.top + 8),
          _strokePaint,
        );
        break;

      case GameThemeId.ww1:
        _fillPaint.shader = null;
        _fillPaint.color = Colors.white.withValues(alpha: 0.32);
        const inset = 12.0;
        canvas.drawCircle(
          rect.topLeft + const Offset(inset, inset),
          3.8,
          _fillPaint,
        );
        canvas.drawCircle(
          rect.topRight + const Offset(-inset, inset),
          3.8,
          _fillPaint,
        );
        canvas.drawCircle(
          rect.bottomLeft + const Offset(inset, -inset),
          3.8,
          _fillPaint,
        );
        canvas.drawCircle(
          rect.bottomRight + const Offset(-inset, -inset),
          3.8,
          _fillPaint,
        );
        break;

      case GameThemeId.samurai:
        final inner = rect.deflate(9.0);
        canvas.drawRect(inner, _strokePaint);
        break;

      case GameThemeId.magma:
        _strokePaint
          ..color = const Color(0xFFFFEA00).withValues(alpha: 0.28)
          ..strokeWidth = 3.8;
        canvas.drawLine(
          rect.topLeft + const Offset(14, 14),
          rect.bottomRight + const Offset(-14, -14),
          _strokePaint,
        );
        break;

      case GameThemeId.space:
        final innerRect = rect.deflate(9.5);
        canvas.drawRRect(
          RRect.fromRectAndRadius(innerRect, const Radius.circular(8.0)),
          _strokePaint,
        );
        break;
    }
  }

  String _themeModifierIcon(GameThemeId themeId, BrickModifier modifier) {
    if (modifier == BrickModifier.none) return '';
    switch (themeId) {
      case GameThemeId.football:
        switch (modifier) {
          case BrickModifier.bomb:
            return '🧨';
          case BrickModifier.electric:
            return '📣';
          case BrickModifier.goldCore:
            return '🏆';
          case BrickModifier.boss:
            return '🧤';
          case BrickModifier.none:
            return '';
        }
      case GameThemeId.ww1:
        switch (modifier) {
          case BrickModifier.bomb:
            return '💣';
          case BrickModifier.electric:
            return '📻';
          case BrickModifier.goldCore:
            return '🎖️';
          case BrickModifier.boss:
            return '🛡️';
          case BrickModifier.none:
            return '';
        }
      case GameThemeId.samurai:
        switch (modifier) {
          case BrickModifier.bomb:
            return '🏮';
          case BrickModifier.electric:
            return '⚡';
          case BrickModifier.goldCore:
            return '🪙';
          case BrickModifier.boss:
            return '👹';
          case BrickModifier.none:
            return '';
        }
      case GameThemeId.magma:
        switch (modifier) {
          case BrickModifier.bomb:
            return '🌋';
          case BrickModifier.electric:
            return '🔥';
          case BrickModifier.goldCore:
            return '💎';
          case BrickModifier.boss:
            return '🐉';
          case BrickModifier.none:
            return '';
        }
      case GameThemeId.space:
        switch (modifier) {
          case BrickModifier.bomb:
            return '💥';
          case BrickModifier.electric:
            return '⚡';
          case BrickModifier.goldCore:
            return '🪐';
          case BrickModifier.boss:
            return '🛸';
          case BrickModifier.none:
            return '';
        }
    }
  }

  void _drawItem(Canvas canvas, GridEntity item, Rect rect) {
    final center = rect.center;
    final baseRadius = rect.width * 0.32;
    final theme = controller.selectedTheme;

    switch (item.itemType!) {
      case ItemType.addBall:
        final ringRadius = baseRadius * (0.95 + 0.12 * pulseValue);
        _fillPaint.shader = null;
        _fillPaint.color = const Color(0xFF00E676).withValues(alpha: 0.22);
        canvas.drawCircle(center, ringRadius * 1.15, _fillPaint);

        _strokePaint
          ..color = const Color(0xFF00E676)
          ..strokeWidth = 6.5;
        canvas.drawCircle(center, ringRadius, _strokePaint);

        _drawShapeBall(
          canvas,
          center,
          baseRadius * 0.48,
          pulseValue * math.pi,
          controller.selectedSkin,
        );
        break;

      case ItemType.multiBall:
        final ringRadius = baseRadius * (1.02 + 0.14 * pulseValue);
        _strokePaint
          ..color = theme.accentColor
          ..strokeWidth = 6.5;
        canvas.drawCircle(center, ringRadius, _strokePaint);
        break;

      case ItemType.laserHorizontal:
        _drawSensorBadge(
          canvas,
          center,
          baseRadius,
          color: theme.horizontalLaserColor,
          drawIcon: (c) {
            _strokePaint
              ..color = Colors.white
              ..strokeWidth = 6.5;
            c.drawLine(
              center + Offset(-baseRadius * 0.58, 0),
              center + Offset(baseRadius * 0.58, 0),
              _strokePaint,
            );
          },
        );
        break;

      case ItemType.laserVertical:
        _drawSensorBadge(
          canvas,
          center,
          baseRadius,
          color: theme.verticalLaserColor,
          drawIcon: (c) {
            _strokePaint
              ..color = Colors.white
              ..strokeWidth = 6.5;
            c.drawLine(
              center + Offset(0, -baseRadius * 0.58),
              center + Offset(0, baseRadius * 0.58),
              _strokePaint,
            );
          },
        );
        break;

      case ItemType.laserCross:
        _drawSensorBadge(
          canvas,
          center,
          baseRadius,
          color: theme.accentColor,
          drawIcon: (c) {
            _strokePaint
              ..color = Colors.white
              ..strokeWidth = 6.5;
            c.drawLine(
              center + Offset(-baseRadius * 0.58, 0),
              center + Offset(baseRadius * 0.58, 0),
              _strokePaint,
            );
            c.drawLine(
              center + Offset(0, -baseRadius * 0.58),
              center + Offset(0, baseRadius * 0.58),
              _strokePaint,
            );
          },
        );
        break;

      case ItemType.deflector:
        _drawSensorBadge(
          canvas,
          center,
          baseRadius,
          color: const Color(0xFFFF9100),
          drawIcon: (c) {
            _strokePaint
              ..color = Colors.white
              ..strokeWidth = 5.5;
            for (int i = 0; i < 4; i++) {
              final a = (i * math.pi / 2) + pulseValue * math.pi * 0.5;
              c.drawLine(
                center +
                    Offset(math.cos(a), math.sin(a)) * (-baseRadius * 0.52),
                center + Offset(math.cos(a), math.sin(a)) * (baseRadius * 0.52),
                _strokePaint,
              );
            }
          },
        );
        break;

      case ItemType.coin:
        final coinRadius = baseRadius * 0.88;
        _fillPaint.shader = null;
        _fillPaint.color = const Color(0xFFFFD740).withValues(alpha: 0.25);
        canvas.drawCircle(center, coinRadius, _fillPaint);

        _strokePaint
          ..color = const Color(0xFFFFD740)
          ..strokeWidth = 6.0;
        canvas.drawCircle(center, coinRadius, _strokePaint);

        final tp = _getCachedTextPainter(
          text: '\$',
          fontSize: 32,
          color: const Color(0xFFFFD740),
        );
        tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
        break;
    }
  }

  void _drawSensorBadge(
    Canvas canvas,
    Offset center,
    double radius, {
    required Color color,
    required void Function(Canvas) drawIcon,
  }) {
    _fillPaint.shader = null;
    _fillPaint.color = color.withValues(alpha: 0.26);
    canvas.drawCircle(center, radius, _fillPaint);

    _strokePaint
      ..color = color
      ..strokeWidth = 6.0;
    canvas.drawCircle(center, radius, _strokePaint);
    drawIcon(canvas);
  }

  void _drawLaserBeams(Canvas canvas, Size size) {
    const cellSize = BounceStrikeConstants.cellSize;
    for (final beam in controller.laserBeams) {
      final alpha = beam.life.clamp(0.0, 1.0);
      _strokePaint
        ..color = beam.color.withValues(alpha: alpha * 0.45)
        ..strokeWidth = cellSize * 0.68 * alpha;

      final isHoriz = beam.isHorizontal;
      final p1 = isHoriz
          ? Offset(0, (beam.index + 0.5) * cellSize)
          : Offset((beam.index + 0.5) * cellSize, 0);
      final p2 = isHoriz
          ? Offset(size.width, (beam.index + 0.5) * cellSize)
          : Offset(
              (beam.index + 0.5) * cellSize,
              BounceStrikeConstants.dangerRow * cellSize,
            );

      canvas.drawLine(p1, p2, _strokePaint);

      _strokePaint
        ..color = Colors.white.withValues(alpha: alpha * 0.95)
        ..strokeWidth = cellSize * 0.20 * alpha;
      canvas.drawLine(p1, p2, _strokePaint);
    }
  }

  void _drawTrajectory(Canvas canvas) {
    final preview = controller.currentTrajectory;
    if (preview == null) return;

    final skinColor = controller.selectedSkin.glowColor;
    final dotRadius = (controller.ballRadius * 0.42).clamp(4.5, 11.0);

    _fillPaint.shader = null;
    _fillPaint.color = skinColor.withValues(alpha: 0.88);

    final delta = preview.hitPoint - preview.start;
    final dist = delta.distance;
    if (dist > 3.0) {
      final dir = delta / dist;
      const spacing = 36.0;
      for (double d = spacing; d < dist; d += spacing) {
        final pos = preview.start + dir * d;
        canvas.drawCircle(pos, dotRadius, _fillPaint);
      }
    }

    _strokePaint
      ..color = skinColor.withValues(alpha: 0.88)
      ..strokeWidth = 5.5;
    canvas.drawCircle(preview.hitPoint, controller.ballRadius, _strokePaint);

    final refDelta = preview.reflectEnd - preview.hitPoint;
    final refDist = refDelta.distance;
    if (refDist > 3.0) {
      final refDir = refDelta / refDist;
      const spacing = 30.0;
      for (double d = spacing; d < refDist; d += spacing) {
        final pos = preview.hitPoint + refDir * d;
        final fade = 1.0 - (d / refDist) * 0.65;
        _fillPaint.color = skinColor.withValues(alpha: 0.6 * fade);
        canvas.drawCircle(pos, dotRadius * 0.8, _fillPaint);
      }
    }
  }

  void _drawLauncherAndCharacter(Canvas canvas, Size size) {
    final y = controller.launchY;
    final skin = controller.selectedSkin;
    final theme = controller.selectedTheme;

    final railY = y + 54.0;
    _strokePaint
      ..color = theme.accentColor.withValues(alpha: 0.48)
      ..strokeWidth = 6.5;
    canvas.drawLine(Offset(0, railY), Offset(size.width, railY), _strokePaint);

    if (controller.nextLaunchX != null &&
        controller.phase == TurnPhase.shooting) {
      final targetPos = Offset(controller.nextLaunchX!, y);
      _strokePaint
        ..color = const Color(0xFF00E676).withValues(alpha: 0.75)
        ..strokeWidth = 5.5;
      canvas.drawCircle(
        targetPos,
        controller.baseBallRadius * 1.5,
        _strokePaint,
      );
      _fillPaint.shader = null;
      _fillPaint.color = const Color(0xFF00E676);
      canvas.drawCircle(targetPos, 11.0, _fillPaint);
    }

    final charX = controller.launchX;
    final recoilOffset = controller.cannonRecoil * 15.0;
    final botCenter = Offset(charX, y + 18.0 + recoilOffset);

    canvas.save();
    canvas.translate(botCenter.dx, botCenter.dy);
    canvas.scale(3.0);

    _fillPaint.shader = null;
    _fillPaint.color = theme.accentColor.withValues(alpha: 0.40);
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, 13),
        width: 28 + 4 * pulseValue,
        height: 7,
      ),
      _fillPaint,
    );

    canvas.save();
    canvas.translate(0, -6);
    canvas.rotate(controller.aimAngle + math.pi / 2);
    final barrelRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(0, -12), width: 10, height: 12),
      const Radius.circular(3),
    );
    _fillPaint.color = theme.accentColor.withValues(alpha: 0.85);
    canvas.drawRRect(barrelRect, _fillPaint);
    canvas.restore();

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 28, height: 22),
      const Radius.circular(8),
    );
    _fillPaint.color = theme.bgBottom;
    canvas.drawRRect(bodyRect, _fillPaint);

    _strokePaint
      ..color = theme.accentColor
      ..strokeWidth = 2.0;
    canvas.drawRRect(bodyRect, _strokePaint);

    switch (theme.id) {
      case GameThemeId.football:
        _strokePaint
          ..color = const Color(0xFFFFD740)
          ..strokeWidth = 3.0;
        canvas.drawLine(
          const Offset(-13, -6),
          const Offset(13, -6),
          _strokePaint,
        );
        break;
      case GameThemeId.ww1:
        final helmetPath = Path()
          ..moveTo(-16, -5)
          ..quadraticBezierTo(0, -17, 16, -5)
          ..close();
        _fillPaint.color = const Color(0xFF5D503C);
        canvas.drawPath(helmetPath, _fillPaint);
        break;
      case GameThemeId.samurai:
        final hornPath = Path()
          ..moveTo(0, -10)
          ..lineTo(-10, -18)
          ..lineTo(-4, -10)
          ..moveTo(0, -10)
          ..lineTo(10, -18)
          ..lineTo(4, -10);
        _strokePaint
          ..color = const Color(0xFFFFD740)
          ..strokeWidth = 2.0;
        canvas.drawPath(hornPath, _strokePaint);
        break;
      case GameThemeId.magma:
        final crownPath = Path()
          ..moveTo(-10, -11)
          ..lineTo(-6, -18)
          ..lineTo(0, -12)
          ..lineTo(6, -18)
          ..lineTo(10, -11);
        _strokePaint
          ..color = const Color(0xFFFF6D00)
          ..strokeWidth = 2.2;
        canvas.drawPath(crownPath, _strokePaint);
        break;
      case GameThemeId.space:
        _strokePaint
          ..color = theme.accentColor
          ..strokeWidth = 2.0;
        canvas.drawLine(
          const Offset(0, -11),
          const Offset(0, -16),
          _strokePaint,
        );
        _fillPaint.color = skin.color;
        canvas.drawCircle(const Offset(0, -17), 2.8, _fillPaint);
        break;
    }

    final visorRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(0, 1), width: 20, height: 9),
      const Radius.circular(4),
    );
    _fillPaint.color = const Color(0xFF090D18);
    canvas.drawRRect(visorRect, _fillPaint);

    final lookDir = Offset(
      math.cos(controller.aimAngle) * 2.5,
      math.sin(controller.aimAngle) * 1.5,
    );
    _fillPaint.color = theme.accentColor;
    canvas.drawCircle(const Offset(-4.5, 1) + lookDir, 2.1, _fillPaint);
    canvas.drawCircle(const Offset(4.5, 1) + lookDir, 2.1, _fillPaint);

    canvas.restore();

    final remainingCount = controller.phase == TurnPhase.shooting
        ? controller.ballsRemainingToSpawn
        : controller.totalBalls;

    if (remainingCount > 0) {
      final origin = Offset(controller.launchX, y - 27.0);
      _drawShapeBall(
        canvas,
        origin,
        controller.ballRadius,
        pulseValue * math.pi,
        skin,
      );

      final tp = _getCachedTextPainter(
        text: 'x$remainingCount',
        fontSize: 36.0,
        color: skin.color,
      );
      tp.paint(
        canvas,
        Offset(controller.launchX + 52, y - 18),
      );
    }
  }

  void _drawBalls(Canvas canvas) {
    final skin = controller.selectedSkin;

    for (final ball in controller.activeBalls) {
      if (ball.trail.length >= 2) {
        for (int i = 0; i < ball.trail.length - 1; i++) {
          final frac = (i + 1) / ball.trail.length;
          _trailPaint
            ..color = skin.glowColor.withValues(alpha: frac * 0.48)
            ..strokeWidth = ball.radius * 1.5 * frac;
          canvas.drawLine(ball.trail[i], ball.trail[i + 1], _trailPaint);
        }
      }

      _drawShapeBall(
        canvas,
        ball.position,
        ball.radius,
        ball.rotation,
        skin,
      );
    }
  }

  void _drawShapeBall(
    Canvas canvas,
    Offset center,
    double radius,
    double rotation,
    BallSkin skin,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    _glowPaint.color = skin.glowColor.withValues(alpha: 0.34);
    _fillPaint.shader = null;
    _fillPaint.color = skin.color;

    switch (skin.visualStyle) {
      case ProjectileVisualStyle.soccerBall:
        canvas.drawCircle(Offset.zero, radius * 1.28, _glowPaint);
        canvas.drawCircle(Offset.zero, radius, _fillPaint);
        final pent = _regularPolygonPath(5, radius * 0.48);
        _fillPaint.color = skin.coreColor;
        canvas.drawPath(pent, _fillPaint);
        _strokePaint
          ..color = skin.coreColor
          ..strokeWidth = radius * 0.14;
        for (int i = 0; i < 5; i++) {
          final a = (i * 2 * math.pi / 5) - math.pi / 2;
          canvas.drawLine(
            Offset(math.cos(a) * radius * 0.45, math.sin(a) * radius * 0.45),
            Offset(math.cos(a) * radius, math.sin(a) * radius),
            _strokePaint,
          );
        }
        canvas.drawCircle(Offset.zero, radius, _strokePaint);
        canvas.restore();
        return;

      case ProjectileVisualStyle.basketball:
        canvas.drawCircle(Offset.zero, radius * 1.28, _glowPaint);
        canvas.drawCircle(Offset.zero, radius, _fillPaint);
        _strokePaint
          ..color = skin.coreColor
          ..strokeWidth = radius * 0.14;
        canvas.drawLine(Offset(-radius, 0), Offset(radius, 0), _strokePaint);
        canvas.drawLine(Offset(0, -radius), Offset(0, radius), _strokePaint);
        canvas.drawCircle(Offset.zero, radius, _strokePaint);
        canvas.restore();
        return;

      case ProjectileVisualStyle.tennisBall:
        canvas.drawCircle(Offset.zero, radius * 1.28, _glowPaint);
        canvas.drawCircle(Offset.zero, radius, _fillPaint);
        _strokePaint
          ..color = Colors.white
          ..strokeWidth = radius * 0.15;
        canvas.drawArc(
          Rect.fromCircle(
            center: Offset(-radius * 0.55, 0),
            radius: radius * 0.7,
          ),
          -math.pi / 3,
          2 * math.pi / 3,
          false,
          _strokePaint,
        );
        canvas.drawArc(
          Rect.fromCircle(
            center: Offset(radius * 0.55, 0),
            radius: radius * 0.7,
          ),
          2 * math.pi / 3,
          2 * math.pi / 3,
          false,
          _strokePaint,
        );
        canvas.restore();
        return;

      case ProjectileVisualStyle.eightBall:
        canvas.drawCircle(Offset.zero, radius * 1.28, _glowPaint);
        canvas.drawCircle(Offset.zero, radius, _fillPaint);
        _fillPaint.color = skin.coreColor;
        canvas.drawCircle(Offset.zero, radius * 0.52, _fillPaint);
        _fillPaint.color = Colors.black;
        canvas.drawCircle(Offset.zero, radius * 0.22, _fillPaint);
        canvas.restore();
        return;

      case ProjectileVisualStyle.golfBall:
        canvas.drawCircle(Offset.zero, radius * 1.28, _glowPaint);
        canvas.drawCircle(Offset.zero, radius, _fillPaint);
        _fillPaint.color = skin.coreColor;
        final dR = radius * 0.12;
        canvas.drawCircle(
          Offset(-radius * 0.35, -radius * 0.25),
          dR,
          _fillPaint,
        );
        canvas.drawCircle(
          Offset(radius * 0.35, -radius * 0.25),
          dR,
          _fillPaint,
        );
        canvas.drawCircle(Offset(0, radius * 0.35), dR, _fillPaint);
        canvas.restore();
        return;

      case ProjectileVisualStyle.dartNeedle:
        final dartPath = Path()
          ..moveTo(0, -radius * 1.6)
          ..lineTo(radius * 0.65, radius * 1.1)
          ..lineTo(0, radius * 0.6)
          ..lineTo(-radius * 0.65, radius * 1.1)
          ..close();
        canvas.drawPath(dartPath, _glowPaint);
        canvas.drawPath(dartPath, _fillPaint);
        _fillPaint.color = skin.coreColor;
        canvas.drawCircle(Offset.zero, radius * 0.38, _fillPaint);
        canvas.restore();
        return;

      case ProjectileVisualStyle.spaceUfo:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: radius * 2.3,
            height: radius * 1.1,
          ),
          _glowPaint,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: radius * 2.1,
            height: radius * 0.95,
          ),
          _fillPaint,
        );
        _fillPaint.color = skin.coreColor;
        canvas.drawCircle(Offset(0, -radius * 0.15), radius * 0.52, _fillPaint);
        canvas.restore();
        return;

      case ProjectileVisualStyle.cannonBall:
        canvas.drawCircle(Offset.zero, radius * 1.22, _glowPaint);
        canvas.drawCircle(Offset.zero, radius, _fillPaint);
        _fillPaint.color = skin.coreColor;
        canvas.drawCircle(
          Offset(-radius * 0.3, -radius * 0.3),
          radius * 0.3,
          _fillPaint,
        );
        _fillPaint.color = const Color(0xFFFF6D00);
        canvas.drawCircle(
          Offset(0, -radius * 1.05),
          radius * 0.28,
          _fillPaint,
        );
        canvas.restore();
        return;

      case ProjectileVisualStyle.grenade:
        final gRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: radius * 1.6,
            height: radius * 1.9,
          ),
          Radius.circular(radius * 0.35),
        );
        canvas.drawRRect(gRect, _glowPaint);
        canvas.drawRRect(gRect, _fillPaint);
        _strokePaint
          ..color = Colors.black45
          ..strokeWidth = radius * 0.12;
        canvas.drawLine(
          Offset(-radius * 0.8, 0),
          Offset(radius * 0.8, 0),
          _strokePaint,
        );
        canvas.drawLine(
          Offset(0, -radius * 0.9),
          Offset(0, radius * 0.9),
          _strokePaint,
        );
        canvas.restore();
        return;

      case ProjectileVisualStyle.propeller:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: radius * 2.4,
            height: radius * 0.55,
          ),
          _fillPaint,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: radius * 0.55,
            height: radius * 2.4,
          ),
          _fillPaint,
        );
        _fillPaint.color = skin.coreColor;
        canvas.drawCircle(Offset.zero, radius * 0.42, _fillPaint);
        canvas.restore();
        return;

      case ProjectileVisualStyle.rifleBullet:
      case ProjectileVisualStyle.mortarShell:
      case ProjectileVisualStyle.sniperNeedle:
        final bulletPath = Path()
          ..moveTo(0, -radius * 1.55)
          ..quadraticBezierTo(
            radius * 0.75,
            -radius * 0.2,
            radius * 0.65,
            radius * 1.1,
          )
          ..lineTo(-radius * 0.65, radius * 1.1)
          ..quadraticBezierTo(-radius * 0.75, -radius * 0.2, 0, -radius * 1.55)
          ..close();
        canvas.drawPath(bulletPath, _glowPaint);
        canvas.drawPath(bulletPath, _fillPaint);
        _fillPaint.color = skin.coreColor;
        canvas.drawCircle(Offset(0, -radius * 0.3), radius * 0.32, _fillPaint);
        canvas.restore();
        return;

      case ProjectileVisualStyle.chakram:
        canvas.drawCircle(Offset.zero, radius * 1.25, _glowPaint);
        _strokePaint
          ..color = skin.color
          ..strokeWidth = radius * 0.42;
        canvas.drawCircle(Offset.zero, radius, _strokePaint);
        canvas.restore();
        return;

      case ProjectileVisualStyle.kunai:
      case ProjectileVisualStyle.senbonNeedle:
        final kunaiPath = Path()
          ..moveTo(0, -radius * 1.65)
          ..lineTo(radius * 0.65, radius * 0.3)
          ..lineTo(0, radius * 1.25)
          ..lineTo(-radius * 0.65, radius * 0.3)
          ..close();
        canvas.drawPath(kunaiPath, _glowPaint);
        canvas.drawPath(kunaiPath, _fillPaint);
        _fillPaint.color = skin.coreColor;
        canvas.drawCircle(Offset(0, radius * 1.35), radius * 0.30, _fillPaint);
        canvas.restore();
        return;

      default:
        break;
    }

    switch (skin.shape) {
      case ProjectileShape.circle:
        canvas.drawCircle(Offset.zero, radius * 1.28, _glowPaint);
        canvas.drawCircle(Offset.zero, radius, _fillPaint);
        _fillPaint.color = skin.coreColor;
        canvas.drawCircle(Offset.zero, radius * 0.46, _fillPaint);
        break;

      case ProjectileShape.square:
        final rect = Rect.fromCenter(
          center: Offset.zero,
          width: radius * 1.8,
          height: radius * 1.8,
        );
        final rrect =
            RRect.fromRectAndRadius(rect, Radius.circular(radius * 0.25));
        canvas.drawRRect(rrect, _glowPaint);
        canvas.drawRRect(rrect, _fillPaint);
        _fillPaint.color = skin.coreColor;
        canvas.drawCircle(Offset.zero, radius * 0.42, _fillPaint);
        break;

      case ProjectileShape.triangle:
        final path = _regularPolygonPath(3, radius * 1.35);
        canvas.drawPath(path, _glowPaint);
        canvas.drawPath(path, _fillPaint);
        _fillPaint.color = skin.coreColor;
        canvas.drawCircle(Offset.zero, radius * 0.38, _fillPaint);
        break;

      case ProjectileShape.star:
        final path = _starPath(5, radius * 1.40, radius * 0.58);
        canvas.drawPath(path, _glowPaint);
        canvas.drawPath(path, _fillPaint);
        _fillPaint.color = skin.coreColor;
        canvas.drawCircle(Offset.zero, radius * 0.36, _fillPaint);
        break;

      case ProjectileShape.shuriken:
        final path = _starPath(4, radius * 1.48, radius * 0.40);
        canvas.drawPath(path, _glowPaint);
        canvas.drawPath(path, _fillPaint);
        _fillPaint.color = skin.coreColor;
        canvas.drawCircle(Offset.zero, radius * 0.32, _fillPaint);
        break;

      case ProjectileShape.microNeedle:
        final path = _starPath(4, radius * 1.55, radius * 0.55);
        canvas.drawPath(path, _glowPaint);
        canvas.drawPath(path, _fillPaint);
        _fillPaint.color = skin.coreColor;
        canvas.drawCircle(Offset.zero, radius * 0.45, _fillPaint);
        break;
    }

    canvas.restore();
  }

  Path _regularPolygonPath(int sides, double radius) {
    final path = Path();
    for (int i = 0; i < sides; i++) {
      final a = (i * 2 * math.pi / sides) - math.pi / 2;
      final pt = Offset(math.cos(a) * radius, math.sin(a) * radius);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    return path;
  }

  Path _starPath(int points, double outerRadius, double innerRadius) {
    final path = Path();
    final total = points * 2;
    for (int i = 0; i < total; i++) {
      final r = i.isEven ? outerRadius : innerRadius;
      final a = (i * math.pi / points) - math.pi / 2;
      final pt = Offset(math.cos(a) * r, math.sin(a) * r);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    return path;
  }

  void _drawParticles(Canvas canvas) {
    for (final p in controller.particles) {
      final alpha = p.life.clamp(0.0, 1.0);
      _particlePaint.color = p.color.withValues(alpha: alpha);

      canvas.save();
      canvas.translate(p.position.dx, p.position.dy);

      final scaledSize = p.size * 2.8;
      switch (p.shape) {
        case ParticleShape.spark:
          final angle = math.atan2(p.velocity.dy, p.velocity.dx);
          canvas.rotate(angle);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: scaledSize * 2.4 * alpha,
                height: scaledSize * 0.45 * alpha,
              ),
              const Radius.circular(4),
            ),
            _particlePaint,
          );
          break;

        case ParticleShape.glowOrb:
          canvas.drawCircle(
            Offset.zero,
            scaledSize * 0.75 * alpha,
            _particlePaint,
          );
          break;

        case ParticleShape.shard:
        case ParticleShape.star:
          canvas.rotate(p.rotation);
          final path = _regularPolygonPath(3, scaledSize * 0.85 * alpha);
          canvas.drawPath(path, _particlePaint);
          break;
      }

      canvas.restore();
    }
  }

  void _drawFloatingTexts(Canvas canvas) {
    for (final ft in controller.floatingTexts) {
      final alpha = ft.life.clamp(0.0, 1.0);
      final tp = _getCachedTextPainter(
        text: ft.text,
        fontSize: 33.0,
        color: ft.color.withValues(alpha: alpha),
      );

      canvas.save();
      canvas.translate(ft.position.dx, ft.position.dy);
      final scale = 0.85 + 0.25 * alpha;
      canvas.scale(scale);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant BounceStrikePainter oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate.pulseAnimation != pulseAnimation;
  }
}

typedef GamePainter = BounceStrikePainter;
