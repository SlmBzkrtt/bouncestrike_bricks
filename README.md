# BounceStrike: Quantum Bricks (v1.0.0)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11+-0175C2?logo=dart)](https://dart.dev)
[![Version](https://img.shields.io/badge/Version-v1.0.0-00FFCC)](https://github.com/SlmBzkrtt/bouncestrike_bricks/releases/tag/v1.0.0)
[![Bundle ID](https://img.shields.io/badge/Bundle%20ID-com.selimbozkurt.bouncestrike__bricks-7C4DFF)](#)

**BounceStrike: Quantum Bricks** is a high-performance, 60–120 FPS physics-based brick breaker arcade game built with **Flutter** and a custom zero-allocation `CustomPainter` rendering engine. Aim your trajectory, unleash chains of shrinking quantum projectiles that slip through micro-gaps, trigger cross-lasers and plasma bombs, and conquer **5 distinct visual worlds** with **30 unlockable ball types**.

---

## Key Highlights

- **5 Immersive Visual Themes & Custom Arenas (`lib/models/bouncestrike_models.dart`)**
  Each theme dynamically transforms the arena backdrop, grid cell geometry, particle effects, character mascot, and brick skins:
  1. **Neon Arcade** (*Default — Free*): Synthwave perspective grid, glowing bevelled cyber-blocks, and plasma explosions.
  2. **Şampiyonlar Arenası (Soccer / Sports — `600 🪙`)**: Full football pitch markings (center circle, penalty box, turf stripes), jersey/trophy/red-card obstacles, and referee/VAR mascots.
  3. **Galaktik Uzay (Galactic Space — `1,400 🪙`)**: Deep-space nebula, twinkling starfield, alien UFO saucers, meteoroids, and photon laser beams.
  4. **1. Dünya Savaşı (WWI Trench Front — `2,600 🪙`)**: Barbed-wire trenches, sandbag bunkers, riveted iron armor plates, and artillery smoke bursts.
  5. **Ejderha Zindanı (Dragon's Keep — `4,200 🪙`)**: Molten lava rivers, obsidian castle bricks, crystal runes, and arcane fireballs.

- **30 Shrinking Projectiles (`%100` → `%34` Radius)**
  - Every theme features **6 specialized projectiles** (`5 themes × 6 balls = 30 balls`).
  - As you unlock higher-tier projectiles in a theme, the ball radius progressively shrinks from **`9.0 px` (`100%`) down to `3.1 px` (`34%`)**, allowing balls to thread through tight micro-corridors between bricks and trigger massive top-row cascades.

- **Balanced Progression & Fair Physics (`v1.0.0`)**
  - **1 Ball = 1 Damage**: Every ball collision deals exactly `1 HP` damage for crisp, predictable tactical planning.
  - **Linear +1 HP Scaling**: Standard bricks start at `1 HP` on Level 1 and increase by `+1 HP` per level (`Level N = N HP`).
  - **2× Boss HP Cap**: Reinforced Elite/Boss bricks spawn with at most **`2×` the current level's HP** (e.g., `180 HP` max at Level 90), keeping late-game stages intense yet fair.
  - **Guaranteed `+1 Ball` Pickup**: Every row wave spawns exactly **1** `+1 Ball` power-up alongside tactical hazards (`Horizontal/Vertical/Cross Lasers`, `Bombs`, `Splitters`, and `Bouncers`).

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
│   ├── bouncestrike_controller.dart       # ChangeNotifier game loop & state management
│   └── bouncestrike_physics.dart          # Sub-stepped (4x) Circle-AABB & hypotenuse collision engine
├── services/
│   ├── audio_service.dart                 # Low-latency audio & haptic feedback service
│   └── storage_service.dart               # Persistent save state via shared_preferences
└── ui/
    ├── bouncestrike_game.dart             # Responsive SafeArea + AspectRatio(1080/1470) + RepaintBoundary
    ├── bouncestrike_painter.dart          # Zero-allocation CustomPainter with LRU TextPainter cache
    └── bouncestrike_shop_sheet.dart       # 5-theme & 30-ball interactive store modal
```

### Optimization Highlights
1. **Zero-Allocation `CustomPainter` (`BounceStrikePainter`)**:
   - All `Paint` instances are pre-allocated once at the class level (`_bgPaint`, `_gridPaint`, `_ballPaint`, `_laserCorePaint`, etc.) rather than inside the 60 FPS `paint()` method.
   - Brick HP labels use an LRU-bounded `TextPainter` cache (`_textCache`) so `TextPainter.layout()` is never re-invoked for existing `(text, fontSize, color)` tuples.
   - Driven directly by `BounceStrikeController` (`super(repaint: controller)`), bypassing `setState()` on the surrounding Flutter widget tree during active physics ticks.
2. **Isolated `RepaintBoundary` & Lifecycle Management**:
   - The canvas is wrapped in its own `RepaintBoundary`, isolating 60 FPS canvas repaints from the HUD and bottom controls.
   - Implements `WidgetsBindingObserver` (`didChangeAppLifecycleState`) to automatically pause the `Ticker` and flush storage when the app goes to the background.
3. **Responsive Virtual Resolution (`1080 × 1470`)**:
   - Scales seamlessly across phones, foldables, tablets, and desktop windows via `SafeArea` + `AspectRatio(1080 / 1470)` + `LayoutBuilder`.

---

## Supported Platforms & Store Identity

| Property | Value |
| :--- | :--- |
| **App Display Name** | `BounceStrike: Quantum Bricks` |
| **Package / Bundle ID** | `com.selimbozkurt.bouncestrike_bricks` |
| **Version** | `1.0.0+1` |
| **Orientation** | Portrait Locked (`portraitUp`, `portraitDown`) |
| **Platforms** | Android (API 21+, R8/ProGuard enabled), iOS, macOS |

---

## Getting Started (Local Development)

### Prerequisites
- Flutter SDK `^3.11.0`
- Dart SDK `^3.11.0`
- Xcode (for iOS / macOS) or Android Studio (for Android)

### Run Commands

```bash
# 1. Clean and fetch dependencies
flutter clean && flutter pub get

# 2. Run static analysis & unit tests
flutter analyze
flutter test

# 3. Launch the game
flutter run -d macos     # macOS Desktop
flutter run -d ios       # iOS Simulator / Device
flutter run -d android   # Android Emulator / Device

# 4. Build store-ready release binaries
flutter build appbundle --release   # Google Play (.aab)
flutter build ipa --release         # Apple App Store (.ipa)
```

---

## License

Copyright © 2026 **Selim Bozkurt**. All rights reserved.
