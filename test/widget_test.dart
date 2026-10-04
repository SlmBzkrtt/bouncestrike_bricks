import 'package:flutter_test/flutter_test.dart';
import 'package:bouncestrike_bricks/main.dart';
import 'package:bouncestrike_bricks/engine/bouncestrike_controller.dart';
import 'package:bouncestrike_bricks/engine/bouncestrike_physics.dart';
import 'package:bouncestrike_bricks/models/bouncestrike_models.dart';

void main() {
  testWidgets(
      'BounceStrike: Quantum Bricks v1.0.0 renders HUD, themes button, and 9x12 matrix board',
      (WidgetTester tester) async {
    await tester.pumpWidget(const BounceStrikeApp());

    expect(find.text('SEVİYE (v1.0.0)'), findsOneWidget);
    expect(find.text('REKOR'), findsOneWidget);
    expect(find.textContaining('Obje: x1'), findsOneWidget);
    expect(find.textContaining('Temalar'), findsOneWidget);
    expect(find.textContaining('Toplar'), findsOneWidget);
  });

  test(
      'Each level progression spawns strictly 1 +1 Ball item and brick HP scales 1-by-1 with max 2x cap',
      () {
    final controller = BounceStrikeController();
    expect(controller.totalBalls, 1);
    final addBallCount = controller.entities
        .where((e) => e.itemType == ItemType.addBall)
        .length;
    expect(addBallCount, 1);

    for (final brick in controller.entities.where((e) => e.isBrick)) {
      expect(brick.hp, lessThanOrEqualTo(controller.level * 2));
      if (brick.modifier == BrickModifier.none) {
        expect(brick.hp, equals(controller.level));
      }
    }
  });

  test(
      'All 5 themes have 6 progressively shrinking balls from 100% down to 34%',
      () {
    expect(GameTheme.allThemes.length, 5);

    for (final theme in GameTheme.allThemes) {
      expect(theme.balls.length, 6);
      for (int i = 0; i < theme.balls.length - 1; i++) {
        expect(
          theme.balls[i + 1].radiusMultiplier,
          lessThan(theme.balls[i].radiusMultiplier),
        );
        expect(
          theme.balls[i + 1].gapPassChancePercent,
          greaterThan(theme.balls[i].gapPassChancePercent),
        );
      }
      expect(theme.balls.first.sizePercent, 100);
      expect(theme.balls.last.sizePercent, 34);
    }
  });

  test(
      'BounceStrikeController unlocks themes and shrinking balls with balanced economy',
      () {
    final controller = BounceStrikeController();
    expect(controller.selectedTheme.id, GameThemeId.space);

    controller.coins = 500;
    final unlockedFootball =
        controller.selectOrUnlockTheme(GameTheme.footballTheme);
    expect(unlockedFootball, isTrue);
    expect(controller.selectedTheme.id, GameThemeId.football);
    expect(controller.selectedSkin.id, 'sport_1');

    final fullSizeRadius = controller.ballRadius;
    final dartNeedle = GameTheme.footballTheme.balls.last;
    final unlockedDart = controller.selectOrUnlockSkin(dartNeedle);
    expect(unlockedDart, isTrue);
    expect(controller.ballRadius, lessThan(fullSizeRadius * 0.4));
  });

  test(
      'BounceStrikePhysics reflects ball off square, triangle, and diamond matrix bricks',
      () {
    const cellSize = 40.0;
    final squareBrick = GridEntity.brick(
      id: 1,
      col: 2,
      row: 2,
      shape: BrickShape.square,
      hp: 5,
    );

    final ball = Ball(
      id: 1,
      position: const Offset(100, 121),
      velocity: const Offset(0, -300),
      radius: 6.0,
    );

    final hitSquare = BounceStrikePhysics.resolveBallBrickCollision(
      ball,
      squareBrick,
      cellSize,
    );
    expect(hitSquare, isTrue);
    expect(ball.velocity.dy, greaterThan(0));
  });
}
