import 'dart:math' as math;
import 'package:flutter/material.dart';

const String kGameVersion = 'v1.0.0';

/// Current phase of a turn in BounceStrike: Quantum Bricks.
enum TurnPhase {
  aiming,
  shooting,
  slidingDown,
  gameOver,
}

/// The 5 unlockable worlds / themes in BounceStrike: Quantum Bricks (v1.0.0).
enum GameThemeId {
  space, // 🌌 Siber Uzay & Galaksi
  football, // ⚽ Şampiyonlar Arenası (Futbol & Spor)
  ww1, // 🎖️ 1. Dünya Savaşı: Cephe Hattı
  samurai, // ⛩️ Neo-Tokyo Samuray & Ninja
  magma, // 🌋 Magma Krateri & Ejderha Ateşi
}

/// Geometric shape of a destructible brick cell in the matrix.
enum BrickShape {
  square,
  triangleBL, // Solid bottom-left, diagonal from top-left to bottom-right
  triangleBR, // Solid bottom-right, diagonal from top-right to bottom-left
  triangleTL, // Solid top-left, diagonal from bottom-left to top-right
  triangleTR, // Solid top-right, diagonal from bottom-right to top-left
  diamond, // 45-degree rotated rhombus leaving corner micro-channels
  hexagon, // 6-sided prism leaving angled gaps
}

/// Special modifier on a brick.
enum BrickModifier {
  none,
  bomb, // Explodes 3x3 neighbors when destroyed
  electric, // Zaps random nearby bricks with chain lightning when hit
  boss, // High HP armored matrix cube
  goldCore, // Bursts into bonus coins when destroyed
}

/// Pass-through items occupying a grid cell.
enum ItemType {
  addBall, // Green +1 ball pickup
  multiBall, // Blue/Gold +3 ball pickup
  laserHorizontal, // Fires horizontal beam across row on ball pass
  laserVertical, // Fires vertical beam across col on ball pass
  laserCross, // Fires both row & col beams on ball pass
  deflector, // Redirects ball to a random upward angle on pass
  coin, // Collectible gold coin for unlocking themes & balls
}

/// Base silhouette family for projectiles.
enum ProjectileShape {
  circle,
  square,
  triangle,
  star,
  shuriken,
  microNeedle,
}

/// Detailed custom visual style so each theme's balls look unique on Canvas.
enum ProjectileVisualStyle {
  // Space theme
  spaceOrb,
  spaceCube,
  spaceUfo,
  spaceStar,
  spaceProbe,
  spaceNeedle,
  // Football & Sports theme
  soccerBall,
  basketball,
  tennisBall,
  eightBall,
  golfBall,
  dartNeedle,
  // WWI Trench theme
  cannonBall,
  grenade,
  mortarShell,
  propeller,
  rifleBullet,
  sniperNeedle,
  // Samurai & Ninja theme
  taikoDrum,
  smokeBomb,
  chakram,
  shuriken,
  kunai,
  senbonNeedle,
  // Magma Volcano theme
  magmaRock,
  fireOrb,
  obsidianPrism,
  phoenixStar,
  dragonFang,
  plasmaSpark,
}

class BallSkin {
  final String id;
  final GameThemeId themeId;
  final String name;
  final String subtitle;
  final String description;
  final ProjectileShape shape;
  final ProjectileVisualStyle visualStyle;
  final Color color;
  final Color glowColor;
  final Color coreColor;
  final int cost;

  /// Progressively smaller radius multiplier (1.00 -> 0.34) so smaller shapes
  /// squeeze through narrow diagonal & corner channels in the matrix!
  final double radiusMultiplier;

  /// Slight speed multiplier for sleeker, smaller projectiles.
  final double speedMultiplier;

  /// Estimated probability rating (15% -> 98%) of squeezing through tight matrix gaps.
  final int gapPassChancePercent;

  const BallSkin({
    required this.id,
    required this.themeId,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.shape,
    required this.visualStyle,
    required this.color,
    required this.glowColor,
    this.coreColor = Colors.white,
    required this.cost,
    required this.radiusMultiplier,
    this.speedMultiplier = 1.0,
    required this.gapPassChancePercent,
  });

  int get sizePercent => (radiusMultiplier * 100).round();

  /// Default catalog alias (returns the Space theme's 6 shrinking projectiles).
  static List<BallSkin> get catalog => GameTheme.spaceTheme.balls;
}

/// Complete Theme / World configuration including background palette,
/// laser colors, brick hue, and 6 theme-specific shrinking projectiles.
class GameTheme {
  final GameThemeId id;
  final String badge;
  final String name;
  final String subtitle;
  final String description;
  final int cost;
  final Color bgTop;
  final Color bgBottom;
  final Color gridColor;
  final Color accentColor;
  final Color horizontalLaserColor;
  final Color verticalLaserColor;
  final String laserName;
  final double baseBrickHue;
  final List<BallSkin> balls;

  const GameTheme({
    required this.id,
    required this.badge,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.cost,
    required this.bgTop,
    required this.bgBottom,
    required this.gridColor,
    required this.accentColor,
    required this.horizontalLaserColor,
    required this.verticalLaserColor,
    required this.laserName,
    required this.baseBrickHue,
    required this.balls,
  });

  static const GameTheme spaceTheme = GameTheme(
    id: GameThemeId.space,
    badge: '🌌',
    name: 'Siber Uzay',
    subtitle: 'Foton Lazerleri & Kozmik Objeler',
    description:
        'Derin uzay nebulası, astronot siber-bot ve kuantum foton ışınları.',
    cost: 0,
    bgTop: Color(0xFF0A0F24),
    bgBottom: Color(0xFF141B38),
    gridColor: Color(0xFF23325E),
    accentColor: Color(0xFF00E5FF),
    horizontalLaserColor: Color(0xFF00E5FF),
    verticalLaserColor: Color(0xFFE040FB),
    laserName: 'Foton Fazör Işını',
    baseBrickHue: 190.0,
    balls: [
      BallSkin(
        id: 'space_1',
        themeId: GameThemeId.space,
        name: 'Ay Küresi',
        subtitle: 'Çap: %100 • Geçiş: %15',
        description: 'Geniş çaplı klasik kozmik küre. Düz duvarlarda güçlü sekme.',
        shape: ProjectileShape.circle,
        visualStyle: ProjectileVisualStyle.spaceOrb,
        color: Color(0xFFE0F7FA),
        glowColor: Color(0xFF00E5FF),
        coreColor: Color(0xFFFFFFFF),
        cost: 0,
        radiusMultiplier: 1.00,
        speedMultiplier: 1.00,
        gapPassChancePercent: 15,
      ),
      BallSkin(
        id: 'space_2',
        themeId: GameThemeId.space,
        name: 'Siber Küp',
        subtitle: 'Çap: %84 • Geçiş: %35',
        description: 'Kompakt enerji küpü. Orta genişlikteki blok aralıklarından geçer.',
        shape: ProjectileShape.square,
        visualStyle: ProjectileVisualStyle.spaceCube,
        color: Color(0xFF40C4FF),
        glowColor: Color(0xFF00B0FF),
        coreColor: Color(0xFFE1F5FE),
        cost: 30,
        radiusMultiplier: 0.84,
        speedMultiplier: 1.04,
        gapPassChancePercent: 35,
      ),
      BallSkin(
        id: 'space_3',
        themeId: GameThemeId.space,
        name: 'UFO Disk',
        subtitle: 'Çap: %70 • Geçiş: %55',
        description: 'Yassı galaktik disk. Çapraz prizma koridorlarından süzülür.',
        shape: ProjectileShape.triangle,
        visualStyle: ProjectileVisualStyle.spaceUfo,
        color: Color(0xFF69F0AE),
        glowColor: Color(0xFF00E676),
        coreColor: Color(0xFFE8F5E9),
        cost: 65,
        radiusMultiplier: 0.70,
        speedMultiplier: 1.08,
        gapPassChancePercent: 55,
      ),
      BallSkin(
        id: 'space_4',
        themeId: GameThemeId.space,
        name: 'Nötron Yıldızı',
        subtitle: 'Çap: %56 • Geçiş: %75',
        description: 'Elmas ve üçgen blokların köşe boşluklarından rahatça sızar.',
        shape: ProjectileShape.star,
        visualStyle: ProjectileVisualStyle.spaceStar,
        color: Color(0xFFFFD740),
        glowColor: Color(0xFFFF9100),
        coreColor: Color(0xFFFFF8E1),
        cost: 110,
        radiusMultiplier: 0.56,
        speedMultiplier: 1.12,
        gapPassChancePercent: 75,
      ),
      BallSkin(
        id: 'space_5',
        themeId: GameThemeId.space,
        name: 'Plazma Sondası',
        subtitle: 'Çap: %44 • Geçiş: %90',
        description: 'Çok ince çatlaklardan geçip matrisin üstüne sızan uzay sondası.',
        shape: ProjectileShape.shuriken,
        visualStyle: ProjectileVisualStyle.spaceProbe,
        color: Color(0xFFFF4081),
        glowColor: Color(0xFFF50057),
        coreColor: Color(0xFFFF80AB),
        cost: 170,
        radiusMultiplier: 0.44,
        speedMultiplier: 1.17,
        gapPassChancePercent: 90,
      ),
      BallSkin(
        id: 'space_6',
        themeId: GameThemeId.space,
        name: 'Foton İğnesi',
        subtitle: 'Çap: %34 • Geçiş: %98',
        description: 'En ince kuantum çekirdeği! En dar matris aralıklarından bile geçer.',
        shape: ProjectileShape.microNeedle,
        visualStyle: ProjectileVisualStyle.spaceNeedle,
        color: Color(0xFFE040FB),
        glowColor: Color(0xFFD500F9),
        coreColor: Color(0xFFFFFFFF),
        cost: 250,
        radiusMultiplier: 0.34,
        speedMultiplier: 1.24,
        gapPassChancePercent: 98,
      ),
    ],
  );

  static const GameTheme footballTheme = GameTheme(
    id: GameThemeId.football,
    badge: '⚽',
    name: 'Şampiyonlar Arenası',
    subtitle: 'Stadyum Çimi & Spor Topları',
    description:
        'Çim saha çizgileri, orta saha yuvarlağı, stadyum projektör ışınları ve küçülen spor topları!',
    cost: 110,
    bgTop: Color(0xFF0B2E17),
    bgBottom: Color(0xFF124624),
    gridColor: Color(0xFF2E7D32),
    accentColor: Color(0xFF76FF03),
    horizontalLaserColor: Color(0xFF76FF03),
    verticalLaserColor: Color(0xFFFFD740),
    laserName: 'Stadyum Projektör Şutu',
    baseBrickHue: 95.0,
    balls: [
      BallSkin(
        id: 'sport_1',
        themeId: GameThemeId.football,
        name: 'Futbol Topu',
        subtitle: 'Çap: %100 • Geçiş: %15',
        description: 'Klasik beşgen desenli siyah-beyaz şampiyonluk futbol topu.',
        shape: ProjectileShape.circle,
        visualStyle: ProjectileVisualStyle.soccerBall,
        color: Color(0xFFFFFFFF),
        glowColor: Color(0xFF76FF03),
        coreColor: Color(0xFF212121),
        cost: 0,
        radiusMultiplier: 1.00,
        speedMultiplier: 1.00,
        gapPassChancePercent: 15,
      ),
      BallSkin(
        id: 'sport_2',
        themeId: GameThemeId.football,
        name: 'Basketbol Topu',
        subtitle: 'Çap: %84 • Geçiş: %35',
        description: 'Yüksek zıplama enerjili turuncu oluklu pota topu.',
        shape: ProjectileShape.circle,
        visualStyle: ProjectileVisualStyle.basketball,
        color: Color(0xFFFF6D00),
        glowColor: Color(0xFFFFAB40),
        coreColor: Color(0xFF212121),
        cost: 35,
        radiusMultiplier: 0.84,
        speedMultiplier: 1.05,
        gapPassChancePercent: 35,
      ),
      BallSkin(
        id: 'sport_3',
        themeId: GameThemeId.football,
        name: 'Tenis Topu',
        subtitle: 'Çap: %70 • Geçiş: %55',
        description: 'Fosforlu sarı-yeşil hızlı kort topu; dar koridorlara girer.',
        shape: ProjectileShape.circle,
        visualStyle: ProjectileVisualStyle.tennisBall,
        color: Color(0xFFC6FF00),
        glowColor: Color(0xFF76FF03),
        coreColor: Color(0xFFFFFFFF),
        cost: 70,
        radiusMultiplier: 0.70,
        speedMultiplier: 1.09,
        gapPassChancePercent: 55,
      ),
      BallSkin(
        id: 'sport_4',
        themeId: GameThemeId.football,
        name: 'Bilardo 8-Top',
        subtitle: 'Çap: %56 • Geçiş: %75',
        description: 'Ağır ve küçük 8 numaralı bilardo topu; köşe boşluklarından sızar.',
        shape: ProjectileShape.circle,
        visualStyle: ProjectileVisualStyle.eightBall,
        color: Color(0xFF263238),
        glowColor: Color(0xFF00E5FF),
        coreColor: Color(0xFFFFFFFF),
        cost: 115,
        radiusMultiplier: 0.56,
        speedMultiplier: 1.13,
        gapPassChancePercent: 75,
      ),
      BallSkin(
        id: 'sport_5',
        themeId: GameThemeId.football,
        name: 'Golf Topu',
        subtitle: 'Çap: %44 • Geçiş: %90',
        description: 'Aerodinamik mikro golf topu; çok dar defans aralıklarını deler!',
        shape: ProjectileShape.circle,
        visualStyle: ProjectileVisualStyle.golfBall,
        color: Color(0xFFF5F5F5),
        glowColor: Color(0xFF69F0AE),
        coreColor: Color(0xFFB0BEC5),
        cost: 175,
        radiusMultiplier: 0.44,
        speedMultiplier: 1.18,
        gapPassChancePercent: 90,
      ),
      BallSkin(
        id: 'sport_6',
        themeId: GameThemeId.football,
        name: 'Şampiyon Dart Oku',
        subtitle: 'Çap: %34 • Geçiş: %98',
        description: 'Ultra ince altın dart iğnesi! En sıkışık barajın bile arasından geçer.',
        shape: ProjectileShape.microNeedle,
        visualStyle: ProjectileVisualStyle.dartNeedle,
        color: Color(0xFFFFD740),
        glowColor: Color(0xFFFF5252),
        coreColor: Color(0xFFFFFFFF),
        cost: 255,
        radiusMultiplier: 0.34,
        speedMultiplier: 1.24,
        gapPassChancePercent: 98,
      ),
    ],
  );

  static const GameTheme ww1Theme = GameTheme(
    id: GameThemeId.ww1,
    badge: '🎖️',
    name: '1. Dünya: Cephe Hattı',
    subtitle: 'Siper Haritası & Topçu Mühimmatı',
    description:
        'Tarihi cephe koordinat haritası, dikenli tel hattı, izli mermi ışınları ve küçülen cephane!',
    cost: 160,
    bgTop: Color(0xFF231F18),
    bgBottom: Color(0xFF332C21),
    gridColor: Color(0xFF5D503C),
    accentColor: Color(0xFFFFB300),
    horizontalLaserColor: Color(0xFFFF6D00),
    verticalLaserColor: Color(0xFFFFD54F),
    laserName: 'İzli Topçu Ateşi',
    baseBrickHue: 32.0,
    balls: [
      BallSkin(
        id: 'ww1_1',
        themeId: GameThemeId.ww1,
        name: 'Sahra Güllesi',
        subtitle: 'Çap: %100 • Geçiş: %15',
        description: 'Ağır dökme demir top güllesi. Siper bloklarını önden döver.',
        shape: ProjectileShape.circle,
        visualStyle: ProjectileVisualStyle.cannonBall,
        color: Color(0xFF90A4AE),
        glowColor: Color(0xFFFFAB00),
        coreColor: Color(0xFFCFD8DC),
        cost: 0,
        radiusMultiplier: 1.00,
        speedMultiplier: 1.00,
        gapPassChancePercent: 15,
      ),
      BallSkin(
        id: 'ww1_2',
        themeId: GameThemeId.ww1,
        name: 'El Bombası',
        subtitle: 'Çap: %84 • Geçiş: %35',
        description: 'Oluklu çelik tahrip bombası. Orta siper gediklerinden sığar.',
        shape: ProjectileShape.square,
        visualStyle: ProjectileVisualStyle.grenade,
        color: Color(0xFF8BC34A),
        glowColor: Color(0xFFFF6E40),
        coreColor: Color(0xFFFFCC80),
        cost: 35,
        radiusMultiplier: 0.84,
        speedMultiplier: 1.04,
        gapPassChancePercent: 35,
      ),
      BallSkin(
        id: 'ww1_3',
        themeId: GameThemeId.ww1,
        name: 'Havan Mermisi',
        subtitle: 'Çap: %70 • Geçiş: %55',
        description: 'Kanatçıklı zırh delici havan. Çapraz koridorlardan süzülür.',
        shape: ProjectileShape.triangle,
        visualStyle: ProjectileVisualStyle.mortarShell,
        color: Color(0xFFFFB74D),
        glowColor: Color(0xFFFF6D00),
        coreColor: Color(0xFFFFF3E0),
        cost: 75,
        radiusMultiplier: 0.70,
        speedMultiplier: 1.09,
        gapPassChancePercent: 55,
      ),
      BallSkin(
        id: 'ww1_4',
        themeId: GameThemeId.ww1,
        name: 'Uçak Pervanesi',
        subtitle: 'Çap: %56 • Geçiş: %75',
        description: 'Çift kanatlı avcı uçağı pervanesi; dar boğazları biçerek geçer.',
        shape: ProjectileShape.shuriken,
        visualStyle: ProjectileVisualStyle.propeller,
        color: Color(0xFFFFCA28),
        glowColor: Color(0xFFFF8F00),
        coreColor: Color(0xFFFFFFFF),
        cost: 120,
        radiusMultiplier: 0.56,
        speedMultiplier: 1.13,
        gapPassChancePercent: 75,
      ),
      BallSkin(
        id: 'ww1_5',
        themeId: GameThemeId.ww1,
        name: 'Tüfek Mermisi',
        subtitle: 'Çap: %44 • Geçiş: %90',
        description: 'Pirinç çekirdekli hızlı mermi; ince siper çatlaklarından sızar.',
        shape: ProjectileShape.triangle,
        visualStyle: ProjectileVisualStyle.rifleBullet,
        color: Color(0xFFFFD54F),
        glowColor: Color(0xFFFF5252),
        coreColor: Color(0xFFFFFFFF),
        cost: 180,
        radiusMultiplier: 0.44,
        speedMultiplier: 1.18,
        gapPassChancePercent: 90,
      ),
      BallSkin(
        id: 'ww1_6',
        themeId: GameThemeId.ww1,
        name: 'Nişancı İğnesi',
        subtitle: 'Çap: %34 • Geçiş: %98',
        description: 'En ince tungsten zırh delici! En dar boşluktan bile cephe arkasına geçer.',
        shape: ProjectileShape.microNeedle,
        visualStyle: ProjectileVisualStyle.sniperNeedle,
        color: Color(0xFFFF5252),
        glowColor: Color(0xFFFFD740),
        coreColor: Color(0xFFFFFFFF),
        cost: 260,
        radiusMultiplier: 0.34,
        speedMultiplier: 1.25,
        gapPassChancePercent: 98,
      ),
    ],
  );

  static const GameTheme samuraiTheme = GameTheme(
    id: GameThemeId.samurai,
    badge: '⛩️',
    name: 'Samuray & Ninja',
    subtitle: 'Kızıl Tapınak & Katana Kesikleri',
    description:
        'Gece tapınağı tatami matrisi, katana kılıç darbesi ışınları ve küçülen suikast silahları!',
    cost: 210,
    bgTop: Color(0xFF1F0A14),
    bgBottom: Color(0xFF321020),
    gridColor: Color(0xFF6A1B3D),
    accentColor: Color(0xFFFF4081),
    horizontalLaserColor: Color(0xFFFF1744),
    verticalLaserColor: Color(0xFFFFD740),
    laserName: 'Ejderha Katana Kesiği',
    baseBrickHue: 335.0,
    balls: [
      BallSkin(
        id: 'sam_1',
        themeId: GameThemeId.samurai,
        name: 'Taiko Davulu',
        subtitle: 'Çap: %100 • Geçiş: %15',
        description: 'Geleneksel savaş davulu küresi. Güçlü sonik sekme yaratır.',
        shape: ProjectileShape.circle,
        visualStyle: ProjectileVisualStyle.taikoDrum,
        color: Color(0xFFFFCDD2),
        glowColor: Color(0xFFFF1744),
        coreColor: Color(0xFFB71C1C),
        cost: 0,
        radiusMultiplier: 1.00,
        speedMultiplier: 1.00,
        gapPassChancePercent: 15,
      ),
      BallSkin(
        id: 'sam_2',
        themeId: GameThemeId.samurai,
        name: 'Duman Küresi',
        subtitle: 'Çap: %84 • Geçiş: %35',
        description: 'Ninja sis bombası; orta genişlikteki tapınak aralıklarından geçer.',
        shape: ProjectileShape.square,
        visualStyle: ProjectileVisualStyle.smokeBomb,
        color: Color(0xFFCE93D8),
        glowColor: Color(0xFFE040FB),
        coreColor: Color(0xFFFFFFFF),
        cost: 40,
        radiusMultiplier: 0.84,
        speedMultiplier: 1.05,
        gapPassChancePercent: 35,
      ),
      BallSkin(
        id: 'sam_3',
        themeId: GameThemeId.samurai,
        name: 'Gölge Chakram',
        subtitle: 'Çap: %70 • Geçiş: %55',
        description: 'Halka bıçak; üçgen ve elmas blokların yanından hızla sıyrılır.',
        shape: ProjectileShape.star,
        visualStyle: ProjectileVisualStyle.chakram,
        color: Color(0xFFFF80AB),
        glowColor: Color(0xFFF50057),
        coreColor: Color(0xFF1F0A14),
        cost: 80,
        radiusMultiplier: 0.70,
        speedMultiplier: 1.10,
        gapPassChancePercent: 55,
      ),
      BallSkin(
        id: 'sam_4',
        themeId: GameThemeId.samurai,
        name: 'Kızıl Shuriken',
        subtitle: 'Çap: %56 • Geçiş: %75',
        description: 'Dönen 4 bıçaklı ninja yıldızı; köşe boşluklarından sızar.',
        shape: ProjectileShape.shuriken,
        visualStyle: ProjectileVisualStyle.shuriken,
        color: Color(0xFFFF5252),
        glowColor: Color(0xFFFF1744),
        coreColor: Color(0xFFFFD740),
        cost: 125,
        radiusMultiplier: 0.56,
        speedMultiplier: 1.14,
        gapPassChancePercent: 75,
      ),
      BallSkin(
        id: 'sam_5',
        themeId: GameThemeId.samurai,
        name: 'Zehirli Kunai',
        subtitle: 'Çap: %44 • Geçiş: %90',
        description: 'İnce suikast hançeri; dar matris koridorlarını delip geçer.',
        shape: ProjectileShape.triangle,
        visualStyle: ProjectileVisualStyle.kunai,
        color: Color(0xFF69F0AE),
        glowColor: Color(0xFF00E676),
        coreColor: Color(0xFFFFFFFF),
        cost: 185,
        radiusMultiplier: 0.44,
        speedMultiplier: 1.19,
        gapPassChancePercent: 90,
      ),
      BallSkin(
        id: 'sam_6',
        themeId: GameThemeId.samurai,
        name: 'Senbon İğnesi',
        subtitle: 'Çap: %34 • Geçiş: %98',
        description: 'Saç teli inceliğinde altın samuray iğnesi! En dar delikten bile sızar.',
        shape: ProjectileShape.microNeedle,
        visualStyle: ProjectileVisualStyle.senbonNeedle,
        color: Color(0xFFFFD740),
        glowColor: Color(0xFFFF4081),
        coreColor: Color(0xFFFFFFFF),
        cost: 265,
        radiusMultiplier: 0.34,
        speedMultiplier: 1.25,
        gapPassChancePercent: 98,
      ),
    ],
  );

  static const GameTheme magmaTheme = GameTheme(
    id: GameThemeId.magma,
    badge: '🌋',
    name: 'Magma Krateri',
    subtitle: 'Volkanik Kor & Ejderha Ateşi',
    description:
        'Obsidyen lav çatlakları, güneş patlaması ışınları ve küçülen volkanik kor çekirdekleri!',
    cost: 260,
    bgTop: Color(0xFF1F0D07),
    bgBottom: Color(0xFF38150A),
    gridColor: Color(0xFF6D2611),
    accentColor: Color(0xFFFF6E40),
    horizontalLaserColor: Color(0xFFFF3D00),
    verticalLaserColor: Color(0xFFFFEA00),
    laserName: 'Volkanik Lav Işını',
    baseBrickHue: 12.0,
    balls: [
      BallSkin(
        id: 'mag_1',
        themeId: GameThemeId.magma,
        name: 'Magma Kayası',
        subtitle: 'Çap: %100 • Geçiş: %15',
        description: 'Korlaşmış volkanik meteor kayası.',
        shape: ProjectileShape.circle,
        visualStyle: ProjectileVisualStyle.magmaRock,
        color: Color(0xFFFF8A65),
        glowColor: Color(0xFFFF3D00),
        coreColor: Color(0xFFFFEA00),
        cost: 0,
        radiusMultiplier: 1.00,
        speedMultiplier: 1.00,
        gapPassChancePercent: 15,
      ),
      BallSkin(
        id: 'mag_2',
        themeId: GameThemeId.magma,
        name: 'Ateş Küresi',
        subtitle: 'Çap: %84 • Geçiş: %35',
        description: 'Saf alev çekirdeği; orta genişlikteki bazalt aralıklarından geçer.',
        shape: ProjectileShape.square,
        visualStyle: ProjectileVisualStyle.fireOrb,
        color: Color(0xFFFFAB40),
        glowColor: Color(0xFFFF6D00),
        coreColor: Color(0xFFFFFFFF),
        cost: 45,
        radiusMultiplier: 0.84,
        speedMultiplier: 1.05,
        gapPassChancePercent: 35,
      ),
      BallSkin(
        id: 'mag_3',
        themeId: GameThemeId.magma,
        name: 'Obsidyen Prizma',
        subtitle: 'Çap: %70 • Geçiş: %55',
        description: 'Keskin volkanik cam üçgeni; çapraz geçitlerden süzülür.',
        shape: ProjectileShape.triangle,
        visualStyle: ProjectileVisualStyle.obsidianPrism,
        color: Color(0xFFB388FF),
        glowColor: Color(0xFFFF3D00),
        coreColor: Color(0xFFFFCCBC),
        cost: 85,
        radiusMultiplier: 0.70,
        speedMultiplier: 1.10,
        gapPassChancePercent: 55,
      ),
      BallSkin(
        id: 'mag_4',
        themeId: GameThemeId.magma,
        name: 'Anka Yıldızı',
        subtitle: 'Çap: %56 • Geçiş: %75',
        description: 'Küllerinden doğan güneş yıldızı; elmas köşe boşluklarından sızar.',
        shape: ProjectileShape.star,
        visualStyle: ProjectileVisualStyle.phoenixStar,
        color: Color(0xFFFFEA00),
        glowColor: Color(0xFFFF9100),
        coreColor: Color(0xFFFFFFFF),
        cost: 130,
        radiusMultiplier: 0.56,
        speedMultiplier: 1.15,
        gapPassChancePercent: 75,
      ),
      BallSkin(
        id: 'mag_5',
        themeId: GameThemeId.magma,
        name: 'Ejderha Dişi',
        subtitle: 'Çap: %44 • Geçiş: %90',
        description: 'Sivri kor diş; en ince kaya çatlaklarından üst satırlara çıkar.',
        shape: ProjectileShape.shuriken,
        visualStyle: ProjectileVisualStyle.dragonFang,
        color: Color(0xFFFF5252),
        glowColor: Color(0xFFFF1744),
        coreColor: Color(0xFFFFF9C4),
        cost: 190,
        radiusMultiplier: 0.44,
        speedMultiplier: 1.20,
        gapPassChancePercent: 90,
      ),
      BallSkin(
        id: 'mag_6',
        themeId: GameThemeId.magma,
        name: 'Plazma Kıvılcımı',
        subtitle: 'Çap: %34 • Geçiş: %98',
        description: 'Atomik sıcaklıkta mikro kıvılcım! Matristeki her aralıktan geçer.',
        shape: ProjectileShape.microNeedle,
        visualStyle: ProjectileVisualStyle.plasmaSpark,
        color: Color(0xFFFFFFFF),
        glowColor: Color(0xFFFFEA00),
        coreColor: Color(0xFFFF3D00),
        cost: 270,
        radiusMultiplier: 0.34,
        speedMultiplier: 1.26,
        gapPassChancePercent: 98,
      ),
    ],
  );

  static const List<GameTheme> allThemes = [
    spaceTheme,
    footballTheme,
    ww1Theme,
    samuraiTheme,
    magmaTheme,
  ];
}

/// Represents either a solid destructible Brick or a pass-through Item in the grid.
class GridEntity {
  final int id;
  int col;
  int row;

  /// Visual row used for smooth slide-down animation between turns.
  double visualRow;

  /// If non-null, this entity is a solid destructible brick.
  final BrickShape? brickShape;
  final BrickModifier modifier;
  int hp;
  final int maxHp;

  /// If non-null, this entity is a pass-through item/power-up.
  final ItemType? itemType;

  bool activatedThisTurn = false;
  final Set<int> overlappingBallIds = {};
  double hitFlash = 0.0;
  double scale = 1.0;

  GridEntity.brick({
    required this.id,
    required this.col,
    required this.row,
    required BrickShape shape,
    required this.hp,
    this.modifier = BrickModifier.none,
  })  : brickShape = shape,
        maxHp = hp,
        itemType = null,
        visualRow = row.toDouble();

  GridEntity.item({
    required this.id,
    required this.col,
    required this.row,
    required ItemType type,
  })  : itemType = type,
        brickShape = null,
        modifier = BrickModifier.none,
        hp = 1,
        maxHp = 1,
        visualRow = row.toDouble();

  bool get isBrick => brickShape != null;
  bool get isItem => itemType != null;
  double get damageRatio => maxHp > 0 ? (hp / maxHp).clamp(0.0, 1.0) : 0.0;
}

/// Active projectile in the arena.
class Ball {
  final int id;
  Offset position;
  Offset velocity;
  final double radius;
  bool isLaunched = false;
  bool isReturned = false;
  double rotation = 0.0;

  int horizontalBounceCount = 0;
  double lastBounceY = 0.0;

  final List<Offset> trail = [];

  Ball({
    required this.id,
    required this.position,
    required this.velocity,
    required this.radius,
  });

  void recordTrail() {
    trail.add(position);
    if (trail.length > 9) {
      trail.removeAt(0);
    }
  }
}

/// Visual laser beam effect when a ball triggers a laser item.
class LaserBeamEffect {
  final bool isHorizontal;
  final int index;
  double life = 1.0;
  final Color color;

  LaserBeamEffect({
    required this.isHorizontal,
    required this.index,
    this.color = const Color(0xFF00E5FF),
  });
}

/// Expanding shockwave ring for explosions, brick shatters, and pickups.
class ShockwaveEffect {
  final Offset origin;
  final Color color;
  final double maxRadius;
  double progress = 0.0;
  final double speed;
  final double strokeWidth;

  ShockwaveEffect({
    required this.origin,
    required this.color,
    required this.maxRadius,
    this.speed = 3.2,
    this.strokeWidth = 4.0,
  });
}

/// Chain lightning arc between electric bricks and targets.
class LightningArcEffect {
  final Offset start;
  final Offset end;
  final Color color;
  double life = 1.0;
  final List<Offset> jaggedPoints;

  LightningArcEffect({
    required this.start,
    required this.end,
    this.color = const Color(0xFF80D8FF),
  }) : jaggedPoints = _generateJagged(start, end);

  static List<Offset> _generateJagged(Offset a, Offset b) {
    final rng = math.Random();
    final pts = <Offset>[a];
    const segments = 5;
    final dir = b - a;
    final perp = Offset(-dir.dy, dir.dx);
    final len = dir.distance;
    final normPerp = len > 1e-3 ? perp / len : Offset.zero;

    for (int i = 1; i < segments; i++) {
      final t = i / segments;
      final base = Offset.lerp(a, b, t)!;
      final jitter = (rng.nextDouble() - 0.5) * 18.0;
      pts.add(base + normPerp * jitter);
    }
    pts.add(b);
    return pts;
  }
}

enum ParticleShape {
  shard,
  spark,
  glowOrb,
  star,
}

class Particle {
  Offset position;
  Offset velocity;
  Color color;
  double size;
  double life;
  double rotation;
  double angularVelocity;
  final ParticleShape shape;

  Particle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    this.life = 1.0,
    this.rotation = 0.0,
    this.angularVelocity = 0.0,
    this.shape = ParticleShape.shard,
  });

  static List<Particle> burst({
    required Offset origin,
    required Color color,
    int count = 16,
    double speed = 210.0,
    bool includeSparks = true,
  }) {
    final rng = math.Random();
    return List.generate(count, (i) {
      final angle = rng.nextDouble() * math.pi * 2;
      final mag = speed * (0.30 + rng.nextDouble() * 0.85);
      final shape = includeSparks && i % 3 == 0
          ? ParticleShape.spark
          : (i % 4 == 0 ? ParticleShape.glowOrb : ParticleShape.shard);
      return Particle(
        position: origin,
        velocity: Offset(math.cos(angle) * mag, math.sin(angle) * mag),
        color: i % 5 == 0 ? Colors.white : color,
        size: 3.5 + rng.nextDouble() * 5.5,
        rotation: rng.nextDouble() * math.pi * 2,
        angularVelocity: (rng.nextDouble() - 0.5) * 14.0,
        shape: shape,
      );
    });
  }
}

class FloatingText {
  Offset position;
  final String text;
  final Color color;
  double life = 1.0;
  final double fontSize;

  FloatingText({
    required this.position,
    required this.text,
    required this.color,
    this.fontSize = 13.5,
  });
}
