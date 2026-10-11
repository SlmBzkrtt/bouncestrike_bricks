# BounceStrike: Quantum Bricks (v1.0.0)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11+-0175C2?logo=dart)](https://dart.dev)
[![Version](https://img.shields.io/badge/Version-v1.0.0-00FFCC)](https://github.com/SlmBzkrtt/bouncestrike_bricks/releases/tag/v1.0.0)
[![Target SDK](https://img.shields.io/badge/Target%20SDK-35%20(Android%2015)-brightgreen)](#)
[![AdMob](https://img.shields.io/badge/AdMob-Integrated%20with%20UMP-yellow?logo=googleadmob)](https://admob.google.com)
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

- **Production-Ready Google AdMob & Monetization (`lib/services/ads/`)**
  - **GDPR / UMP Consent:** EU & US privacy compliance via Google User Messaging Platform.
  - **Anchored Adaptive Banner:** Non-intrusive banner positioned cleanly below the game HUD/controls.
  - **Pre-cached Interstitial:** Frequency-capped (1 ad per 3 game-overs) with fail-safe continuation.
  - **Fault-Tolerant Rewarded:** Exponential backoff retry with guaranteed `+50 🪙` coins delivery in the shop.
  - **Environment-Safe IDs:** Zero-risk debug test unit IDs with clean prod flavor switching (`USE_PROD_ADS`).

---

## Architecture & Codebase Map

```text
lib/
├── main.dart                              # Portrait orientation lock & BounceStrikeApp entry
├── constants/
│   └── bouncestrike_constants.dart        # 1080x1470 virtual coordinate constants & physics tuning
├── models/
│   └── bouncestrike_models.dart           # 5 themes, 30 balls, bricks, power-ups, particles
├── engine/
│   ├── bouncestrike_controller.dart       # ChangeNotifier game loop & decoupled repaintNotifier
│   └── bouncestrike_physics.dart          # Sub-stepped Circle-AABB & polygon collision engine
├── services/
│   ├── ads/
│   │   ├── ad_config.dart                 # AdMob test/production IDs & platform guard
│   │   └── ad_manager.dart                # UMP consent flow, banner, interstitial & rewarded service
│   ├── audio_service.dart                 # 16-bit 22050Hz polyphonic procedural audio service
│   ├── logger/
│   │   └── app_logger.dart                # Production-hardened crash & log reporter
│   └── storage_service.dart               # Persistent save state via shared_preferences
└── ui/
    ├── bouncestrike_game.dart             # Responsive SafeArea + AspectRatio(1080/1470) + RepaintBoundary
    ├── bouncestrike_painter.dart          # Zero-allocation CustomPainter with 3D glass & LRU cache
    ├── bouncestrike_shop_sheet.dart       # 5-theme & 30-ball store modal with rewarded ad bonus
    └── widgets/
        └── adaptive_banner_widget.dart    # Anchored adaptive banner widget
```

---

## Supported Platforms & Store Identity

| Property | Value |
| :--- | :--- |
| **App Display Name** | `BounceStrike: Quantum Bricks` |
| **Android Application ID** | `com.selimbozkurt.bouncestrike_bricks` |
| **iOS / macOS Bundle ID** | `com.selimbozkurt.bouncestrike-bricks` |
| **Target SDK / Min SDK** | Target SDK 35 (Android 15) / Min SDK 21 (Android 5.0) |
| **Version** | `1.0.0+1` |
| **Orientation** | Portrait Locked (`portraitUp`, `portraitDown`) |
| **Build Optimization** | R8 Shrinking, Resource Stripping & ProGuard Enabled |

---

## Local Development & Testing

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

## Google Play Store Yayını İçin Kalan Eksikler ve Yol Haritası

Oyunun kod tabanı, vektörel çizimleri, ses sentezleyicisi ve AdMob mimarisi %100 özgün olup herhangi bir telif riski taşımamaktadır. Google Play Store'da resmi yayına çıkmadan önce tamamlanması gereken son teknik ve idari adımlar aşağıda listelenmiştir:

### 1. Release Keystore ve İmzalama Yapılandırması
- **Durum:** Şu an geliştirme ortamında `debug.keystore` fallback'i çalışmaktadır. Google Play, debug anahtarlı paketleri reddeder.
- **Yapılacak İşlem:** Terminalden `upload-keystore.jks` üretilmeli ve `android/key.properties` dosyasına anahtar şifreleri eklenmelidir. (Bu dosya `.gitignore` içinde korunmaktadır).

### 2. Canlı Google AdMob Hesap Bilgileri (Production Ad Units)
- **Durum:** Geliştirici hesabının banlanmasını önlemek için kodda Google'ın resmi Test ID'leri aktiftir.
- **Yapılacak İşlem:** AdMob panelinden Android uygulaması tanımlanıp gerçek App ID `AndroidManifest.xml` içine, Ad Unit ID'leri ise `AdConfig` içine yazılmalı ve derleme `--dart-define=USE_PROD_ADS=true` bayrağı ile alınmalıdır.

### 3. Gizlilik Politikası (Privacy Policy) URL'si
- **Durum:** Google Play, reklam kimliği (`AD_ID`) kullanan tüm uygulamalardan aktif bir gizlilik politikası URL'si zorunlu tutar.
- **Yapılacak İşlem:** AdMob, UMP (GDPR) ve Advertising ID kullanımını açıklayan standart bir metin GitHub Pages veya kişisel bir web sitesine yüklenmeli ve bağlantı Google Play Console'a eklenmelidir.

### 4. Mağaza Tanıtım Varlıkları (Store Listing Assets)
- **Durum:** Oyun içi ekran görüntüleri ve tanıtım grafikleri gerekmektedir.
- **Yapılacak İşlem:**
  - 1024 × 500 px boyutunda **Öne Çıkan Grafik (Feature Graphic)**.
  - En az 4 adet telefon dikey ekran görüntüsü (Screenshot).
  - 512 × 512 px yüksek çözünürlüklü uygulama ikonu.

### 5. Google Play "14 Gün 20 Test Kullanıcısı" (Kapalı Test Süreci)
- **Durum:** 13 Kasım 2023 sonrası açılan tüm bireysel Google Play geliştirici hesapları için zorunlu kuraldır.
- **Yapılacak İşlem:** Üretim öncesinde `.aab` paketi "Kapalı Test (Closed Testing)" kanalına yüklenmeli, en az 20 test kullanıcısı Google Grubu üzerinden davet edilmeli ve 14 gün boyunca aktif test süreci tamamlandıktan sonra üretime geçiş başvurusu yapılmalıdır.

---

## License

Copyright © 2026 **Selim Bozkurt**. All rights reserved.
