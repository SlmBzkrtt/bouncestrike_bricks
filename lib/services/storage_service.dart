import 'package:shared_preferences/shared_preferences.dart';
import '../constants/bouncestrike_constants.dart';

/// Lightweight local persistence service backed by `shared_preferences`.
class StorageService {
  SharedPreferences? _prefs;

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      // Fallback safely in headless test environments
    }
  }

  int getBestLevel() =>
      _prefs?.getInt(BounceStrikeConstants.prefBestLevel) ?? 1;

  Future<void> setBestLevel(int value) async {
    await _prefs?.setInt(BounceStrikeConstants.prefBestLevel, value);
  }

  int getCoins() =>
      _prefs?.getInt(BounceStrikeConstants.prefCoins) ??
      BounceStrikeConstants.starterCoins;

  Future<void> setCoins(int value) async {
    await _prefs?.setInt(BounceStrikeConstants.prefCoins, value);
  }

  String? getSelectedThemeId() =>
      _prefs?.getString(BounceStrikeConstants.prefSelectedTheme);

  Future<void> setSelectedThemeId(String id) async {
    await _prefs?.setString(BounceStrikeConstants.prefSelectedTheme, id);
  }

  String? getSelectedSkinId() =>
      _prefs?.getString(BounceStrikeConstants.prefSelectedSkin);

  Future<void> setSelectedSkinId(String id) async {
    await _prefs?.setString(BounceStrikeConstants.prefSelectedSkin, id);
  }

  List<String> getUnlockedThemes() =>
      _prefs?.getStringList(BounceStrikeConstants.prefUnlockedThemes) ??
      const ['space'];

  Future<void> setUnlockedThemes(Iterable<String> ids) async {
    await _prefs?.setStringList(
      BounceStrikeConstants.prefUnlockedThemes,
      ids.toList(),
    );
  }

  List<String> getUnlockedSkins() =>
      _prefs?.getStringList(BounceStrikeConstants.prefUnlockedSkins) ??
      const ['space_1'];

  Future<void> setUnlockedSkins(Iterable<String> ids) async {
    await _prefs?.setStringList(
      BounceStrikeConstants.prefUnlockedSkins,
      ids.toList(),
    );
  }

  bool getSoundMuted() =>
      _prefs?.getBool(BounceStrikeConstants.prefSoundMuted) ?? false;

  Future<void> setSoundMuted(bool muted) async {
    await _prefs?.setBool(BounceStrikeConstants.prefSoundMuted, muted);
  }
}
