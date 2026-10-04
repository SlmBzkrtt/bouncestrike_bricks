import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/bouncestrike_models.dart';

/// Result of a trajectory raycast for the aiming guide line.
class TrajectoryPreview {
  final Offset start;
  final Offset hitPoint;
  final Offset reflectEnd;

  const TrajectoryPreview({
    required this.start,
    required this.hitPoint,
    required this.reflectEnd,
  });
}

/// High-precision 2D collision & reflection utilities for square, 45-degree
/// right-triangle, diamond, and hexagon matrix bricks, plus pass-through items.
class BounceStrikePhysics {
  /// Proportional padding around each brick cell (`cellSize * 0.08`).
  /// Creates micro-gaps at diagonal corners and between blocks where smaller
  /// projectiles (%84 down to %34) can squeeze through at any coordinate scale!
  static double paddingForCell(double cellSize) => cellSize * 0.08;

  /// Returns the bounding rectangle of a cell at `(col, visualRow)`.
  static Rect cellRect(int col, double visualRow, double cellSize) {
    final pad = paddingForCell(cellSize);
    return Rect.fromLTWH(
      col * cellSize + pad,
      visualRow * cellSize + pad,
      cellSize - pad * 2,
      cellSize - pad * 2,
    );
  }

  /// Returns the convex polygon vertices of a non-square brick in clockwise order.
  static List<Offset> polygonVertices(Rect rect, BrickShape shape) {
    switch (shape) {
      case BrickShape.triangleBL:
        return [rect.topLeft, rect.bottomRight, rect.bottomLeft];
      case BrickShape.triangleBR:
        return [rect.topRight, rect.bottomRight, rect.bottomLeft];
      case BrickShape.triangleTL:
        return [rect.topLeft, rect.topRight, rect.bottomLeft];
      case BrickShape.triangleTR:
        return [rect.topLeft, rect.topRight, rect.bottomRight];
      case BrickShape.diamond:
        final cx = rect.center.dx;
        final cy = rect.center.dy;
        final inset = rect.width * 0.04;
        return [
          Offset(cx, rect.top + inset),
          Offset(rect.right - inset, cy),
          Offset(cx, rect.bottom - inset),
          Offset(rect.left + inset, cy),
        ];
      case BrickShape.hexagon:
        final c = rect.center;
        final rx = rect.width * 0.48;
        final ry = rect.height * 0.48;
        return List.generate(6, (i) {
          final a = (i * math.pi / 3.0) - math.pi / 6.0;
          return Offset(c.dx + math.cos(a) * rx, c.dy + math.sin(a) * ry);
        });
      case BrickShape.square:
        return [rect.topLeft, rect.topRight, rect.bottomRight, rect.bottomLeft];
    }
  }

  /// Backwards-compatible alias for tests & painters.
  static List<Offset> triangleVertices(Rect rect, BrickShape shape) =>
      polygonVertices(rect, shape);

  /// Checks and resolves collision between a [Ball] and a solid [GridEntity] brick.
  /// Returns `true` if a collision occurred and the ball bounced.
  static bool resolveBallBrickCollision(
    Ball ball,
    GridEntity brick,
    double cellSize,
  ) {
    final rect = cellRect(brick.col, brick.visualRow, cellSize);

    // Quick AABB broadphase check
    if (ball.position.dx + ball.radius < rect.left ||
        ball.position.dx - ball.radius > rect.right ||
        ball.position.dy + ball.radius < rect.top ||
        ball.position.dy - ball.radius > rect.bottom) {
      return false;
    }

    if (brick.brickShape == BrickShape.square) {
      return _resolveCircleAABB(ball, rect);
    } else if (brick.brickShape != null) {
      final vertices = polygonVertices(rect, brick.brickShape!);
      return _resolveCirclePolygon(ball, vertices);
    }
    return false;
  }

  /// Resolves circle vs axis-aligned rectangle collision.
  static bool _resolveCircleAABB(Ball ball, Rect rect) {
    final cx = ball.position.dx.clamp(rect.left, rect.right);
    final cy = ball.position.dy.clamp(rect.top, rect.bottom);

    final dx = ball.position.dx - cx;
    final dy = ball.position.dy - cy;
    final distSq = dx * dx + dy * dy;

    if (distSq >= ball.radius * ball.radius) {
      return false;
    }

    Offset normal;
    double penetration;

    if (distSq > 1e-6) {
      final dist = math.sqrt(distSq);
      normal = Offset(dx / dist, dy / dist);
      penetration = ball.radius - dist;

      // Snap near-cardinal normals to exact axes so flat face hits don't drift
      if (normal.dx.abs() > 0.92) {
        normal = Offset(normal.dx.sign, 0);
      } else if (normal.dy.abs() > 0.92) {
        normal = Offset(0, normal.dy.sign);
      }
    } else {
      final dLeft = (ball.position.dx - rect.left).abs();
      final dRight = (rect.right - ball.position.dx).abs();
      final dTop = (ball.position.dy - rect.top).abs();
      final dBottom = (rect.bottom - ball.position.dy).abs();
      final minD = math.min(math.min(dLeft, dRight), math.min(dTop, dBottom));

      if (minD == dLeft) {
        normal = const Offset(-1, 0);
        penetration = ball.radius + dLeft;
      } else if (minD == dRight) {
        normal = const Offset(1, 0);
        penetration = ball.radius + dRight;
      } else if (minD == dTop) {
        normal = const Offset(0, -1);
        penetration = ball.radius + dTop;
      } else {
        normal = const Offset(0, 1);
        penetration = ball.radius + dBottom;
      }
    }

    ball.position += normal * (penetration + 0.35);

    final vn = ball.velocity.dx * normal.dx + ball.velocity.dy * normal.dy;
    if (vn < 0) {
      ball.velocity = Offset(
        ball.velocity.dx - 2 * vn * normal.dx,
        ball.velocity.dy - 2 * vn * normal.dy,
      );
    }
    return true;
  }

  /// Resolves circle vs any convex polygon (triangles, diamonds, hexagons).
  static bool _resolveCirclePolygon(Ball ball, List<Offset> poly) {
    double minDistSq = double.infinity;
    Offset closestPoint = Offset.zero;
    Offset bestEdgeNormal = Offset.zero;

    double sumX = 0, sumY = 0;
    for (final p in poly) {
      sumX += p.dx;
      sumY += p.dy;
    }
    final centroid = Offset(sumX / poly.length, sumY / poly.length);

    for (int i = 0; i < poly.length; i++) {
      final a = poly[i];
      final b = poly[(i + 1) % poly.length];
      final ab = b - a;
      final abLenSq = ab.dx * ab.dx + ab.dy * ab.dy;
      if (abLenSq < 1e-6) continue;

      final ap = ball.position - a;
      final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / abLenSq).clamp(0.0, 1.0);
      final proj = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
      final diff = ball.position - proj;
      final dSq = diff.dx * diff.dx + diff.dy * diff.dy;

      if (dSq < minDistSq) {
        minDistSq = dSq;
        closestPoint = proj;

        final len = math.sqrt(abLenSq);
        var edgeNormal = Offset(-ab.dy / len, ab.dx / len);
        final toOutside = proj - centroid;
        if (edgeNormal.dx * toOutside.dx + edgeNormal.dy * toOutside.dy < 0) {
          edgeNormal = -edgeNormal;
        }
        bestEdgeNormal = edgeNormal;
      }
    }

    final inside = _isPointInConvexPolygon(ball.position, poly);
    if (!inside && minDistSq >= ball.radius * ball.radius) {
      return false;
    }

    final dist = math.sqrt(minDistSq);
    Offset normal;
    double penetration;

    if (inside) {
      normal = bestEdgeNormal;
      penetration = ball.radius + dist;
    } else if (dist > 1e-5) {
      final rawNormal = (ball.position - closestPoint) / dist;
      if ((rawNormal.dx * bestEdgeNormal.dx + rawNormal.dy * bestEdgeNormal.dy) >
          0.88) {
        normal = bestEdgeNormal;
      } else {
        normal = rawNormal;
      }
      penetration = ball.radius - dist;
    } else {
      normal = bestEdgeNormal;
      penetration = ball.radius;
    }

    ball.position += normal * (penetration + 0.35);

    final vn = ball.velocity.dx * normal.dx + ball.velocity.dy * normal.dy;
    if (vn < 0) {
      ball.velocity = Offset(
        ball.velocity.dx - 2 * vn * normal.dx,
        ball.velocity.dy - 2 * vn * normal.dy,
      );
    }
    return true;
  }

  static bool _isPointInConvexPolygon(Offset p, List<Offset> poly) {
    bool? positiveSide;
    for (int i = 0; i < poly.length; i++) {
      final a = poly[i];
      final b = poly[(i + 1) % poly.length];
      final cross =
          (b.dx - a.dx) * (p.dy - a.dy) - (b.dy - a.dy) * (p.dx - a.dx);
      if (cross.abs() < 1e-6) continue;
      final isPos = cross > 0;
      positiveSide ??= isPos;
      if (positiveSide != isPos) return false;
    }
    return true;
  }

  /// Computes the aiming trajectory raycast up to the first wall or brick bounce.
  static TrajectoryPreview computeTrajectory({
    required Offset start,
    required double angle,
    required double ballRadius,
    required double boardWidth,
    required double launchY,
    required double cellSize,
    required List<GridEntity> entities,
  }) {
    final dir = Offset(math.cos(angle), math.sin(angle));
    final stepSize = cellSize * 0.08;
    const maxSteps = 380;

    final simBall = Ball(
      id: -1,
      position: start,
      velocity: dir,
      radius: ballRadius,
    );

    Offset hitPoint = start + dir * (cellSize * 10.5);
    Offset reflectDir = dir;

    for (int i = 0; i < maxSteps; i++) {
      simBall.position += simBall.velocity * stepSize;

      if (simBall.position.dx - ballRadius <= 0) {
        simBall.position = Offset(ballRadius, simBall.position.dy);
        simBall.velocity = Offset(-simBall.velocity.dx, simBall.velocity.dy);
        hitPoint = simBall.position;
        reflectDir = simBall.velocity;
        break;
      }
      if (simBall.position.dx + ballRadius >= boardWidth) {
        simBall.position = Offset(boardWidth - ballRadius, simBall.position.dy);
        simBall.velocity = Offset(-simBall.velocity.dx, simBall.velocity.dy);
        hitPoint = simBall.position;
        reflectDir = simBall.velocity;
        break;
      }
      if (simBall.position.dy - ballRadius <= 0) {
        simBall.position = Offset(simBall.position.dx, ballRadius);
        simBall.velocity = Offset(simBall.velocity.dx, -simBall.velocity.dy);
        hitPoint = simBall.position;
        reflectDir = simBall.velocity;
        break;
      }

      bool hitBrick = false;
      for (final entity in entities) {
        if (!entity.isBrick) continue;
        if (resolveBallBrickCollision(simBall, entity, cellSize)) {
          hitPoint = simBall.position;
          reflectDir = simBall.velocity;
          hitBrick = true;
          break;
        }
      }
      if (hitBrick) break;
    }

    return TrajectoryPreview(
      start: start,
      hitPoint: hitPoint,
      reflectEnd: hitPoint + reflectDir * (cellSize * 1.6),
    );
  }
}

typedef PhysicsEngine = BounceStrikePhysics;
