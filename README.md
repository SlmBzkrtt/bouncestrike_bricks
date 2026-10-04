# BounceStrike: Quantum Bricks (v1.0.0)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11+-0175C2?logo=dart)](https://dart.dev)
[![Version](https://img.shields.io/badge/Version-v1.0.0-00FFCC)](https://github.com/SlmBzkrtt/bouncestrike_bricks/releases/tag/v1.0.0)
[![Bundle ID](https://img.shields.io/badge/Bundle%20ID-com.selimbozkurt.bouncestrike__bricks-7C4DFF)](#)

**BounceStrike: Quantum Bricks** is a high-performance, 60–120 FPS physics-based brick breaker arcade game built with **Flutter**, a custom zero-allocation `CustomPainter` vector rendering engine, and a polyphonic 16-bit PCM procedural audio synthesizer. Aim your trajectory, unleash chains of shrinking quantum projectiles that slip through micro-gaps, trigger 3-layer plasma cross-lasers and mega bombs, and conquer **5 distinct visual worlds** with **30 unlockable ball types**.

---

## Key Highlights

- **5 Immersive Visual Worlds & Animated Arenas (`lib/models/bouncestrike_models.dart`, `lib/ui/bouncestrike_painter.dart`)**
  Each theme dynamically transforms the arena backdrop, animated atmospheric elements, grid geometry, particle effects, character mascot, and brick skins:
  1. **Siber Uzay (Galactic Space — *Default / Free*)**: Deep-space nebula, ringed planet with orbital moon, twinkling starfield, animated shooting star streaks, cyber-circuit bricks, and alien UFO / photon projectiles.
  2. **Şampiyonlar Arenası (Soccer / Sports — `110 $`)**: Full stadium turf stripes, floodlight beams, corner arcs, penalty box, goal net, scoreboard-ornamented bricks, and soccer/basketball/tennis/eight-ball/golf/dart projectiles.
  3. **1. Dünya: Cephe Hattı (WWI Trench Front — `160 $`)**: Rotating tactical radar sweep, top-row sandbag fortifications, barbed-wire danger line, riveted steel bunker plates, and artillery/propeller/sniper projectiles.
  4. **Samuray & Ninja (Samurai Dojo — `210 $`)**: Crimson blood moon, Mount Fuji silhouette, Torii gate, drifting Sakura cherry blossom petals, Shoji-lattice bricks, and shuriken/chakram/kunai/senbon projectiles.
  5. **Magma Krateri (Volcanic Magma — `260 $`)**: Pulsing volcanic caldera, arcane rune circle, glowing magma veins, rising fire embers, fissured obsidian blocks, and fireball/meteor/plasma-needle projectiles.

- **30 Shrinking Projectiles (`%100` → `%34` Radius)**
  - Every theme features **6 specialized projectiles** (`5 themes × 6 balls = 30 balls`, unlockable between `30 $` and `270 $`).
  - As you unlock higher-tier projectiles in a theme, the ball radius progressively shrinks from **`24.0 px` (`100%`) down to `8.2 px` (`34%`)** in logical space, allowing balls to thread through tight micro-corridors between bricks and trigger massive top-row cascades.

- **Polyphonic 16-Bit 22050Hz Procedural Audio Engine (`lib/services/audio_service.dart`)**
  - Synthesizes crisp 16-bit PCM WAV buffers at startup with zero runtime disk I/O:
    - **Launcher Pop**: Upward pitch sweep (`300Hz -> 620Hz`) when balls fire.
    - **Musical Combo Hits**: 4-channel polyphonic pool stepping through a pentatonic chord (`C5, E5, G5, A5`) as your turn combo climbs.
    - **Brick Shatter**: Crisp pop + harmonic chime when a brick's HP reaches `0`.
    - **Laser Zap**: Sci-fi downward frequency sweep (`1450Hz -> 280Hz`) on horizontal/vertical/cross laser and electric chain triggers.
    - **Pickup Chime**: Ascending two-note arcade arpeggio (`A5 -> E6`) on `+1 Ball`, `+3 Super Ball`, and Gold pickups.
    - **Mega Explosion**: Deep sub-bass punch + rumble on bomb detonations and boss kills.

- **Balanced Progression & Fair Physics (`v1.0.0`)**
  - **1 Ball = 1 Damage**: Every ball collision deals exactly `1 HP` damage for crisp, predictable tactical planning.
  - **Linear +1 HP Scaling**: Standard bricks start at `1 HP` on Level 1 and increase by `+1 HP` per level (`Level N = N HP`).
  - **2× Boss HP Cap**: Reinforced Elite/Boss bricks spawn with at most **`2×` the current level's HP** (e.g., `180 HP` max at Level 90), keeping late-game stages intense yet fair.
  - **Guaranteed `+1 Ball` Pickup**: Every row wave spawns exactly **1** `+1 Ball` power-up alongside tactical hazards (`Horizontal/Vertical/Cross Lasers`, `Bombs`, `Electric Chains`, and `Deflectors`).

---

## Architecture & Performance Engineering

```text
lib/
├── main.dart                              # Portrait orientation lock & BounceStrikeApp entry
├── constants/
│   └── bouncestrike_constants.dart        # 1080x1470 virtual coordinate constants & physics tuning
├── models/
│   └── bouncestrike_models.dart           # 5 themes, 30 balls, bricks, power-ups, particles
├── engine/
│   ├── bouncestrike_controller.dart       # ChangeNotifier game loop & decoupled repaintNotifier
│   └── bouncestrike_physics.dart          # Sub-stepped Circle-AABB & polygon hypotenuse collision engine
├── services/
│   ├── audio_service.dart                 # 16-bit 22050Hz polyphonic procedural audio service
│   └── storage_service.dart               # Persistent save state via shared_preferences
└── ui/
    ├── bouncestrike_game.dart             # Responsive SafeArea + AspectRatio(1080/1470) + RepaintBoundary
    ├── bouncestrike_painter.dart          # Zero-allocation CustomPainter with 3D glass & LRU TextPainter cache
    └── bouncestrike_shop_sheet.dart       # 5-theme & 30-ball interactive store modal
```

---

## Supported Platforms & Store Identity

| Property | Value |
| :--- | :--- |
| **App Display Name** | `BounceStrike: Quantum Bricks` |
| **Android Application ID** | `com.selimbozkurt.bouncestrike_bricks` |
| **iOS / macOS Bundle ID** | `com.selimbozkurt.bouncestrike-bricks` |
| **Version** | `1.0.0+1` |
| **Orientation** | Portrait Locked (`portraitUp`, `portraitDown`) |
| **Platforms** | Android (API 21+, R8/ProGuard enabled), iOS, macOS |

---

## Local Development

```bash
# 1. Clean and fetch dependencies
flutter clean && flutter pub get

# 2. Run static analysis & unit tests
flutter analyze
flutter test

# 3. Launch the game locally
flutter run -d macos     # macOS Desktop
flutter run -d ios       # iOS Simulator / Device
flutter run -d android   # Android Emulator / Device
```

---

## License

Copyright © 2026 **Selim Bozkurt**. All rights reserved.
