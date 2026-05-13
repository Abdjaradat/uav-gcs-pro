import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/license_tier.dart';

class LicensingService extends ChangeNotifier {
  static const _key = 'license_key';
  static const _tier = 'license_tier';
  static const _activated = 'license_activated';

  LicenseInfo _info = LicenseInfo(tier: LicenseTier.demo);

  LicenseInfo get info => _info;
  bool get isDemo => _info.isDemo;
  bool get isPro => _info.isPro;
  bool get isSub => _info.isSub;

  static const proKey = 'UAV-PRO-TEST123456';
  static const subKey = 'UAV-SUB-TEST123456789';
  static const _trialDays = 7;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_key) ?? '';
    final tierStr = prefs.getString(_tier) ?? '';
    final act = prefs.getBool(_activated) ?? false;

    if (key.isNotEmpty && act) {
      final tier = tierStr == 'pro' ? LicenseTier.pro : LicenseTier.subscription;
      _info = LicenseInfo(tier: tier, activated: true, key: key);
    }
  }

  bool activate(String key) {
    if (key == proKey) {
      _info = LicenseInfo(tier: LicenseTier.pro, activated: true, key: key);
      _save();
      notifyListeners();
      return true;
    } else if (key == subKey) {
      _info = LicenseInfo(tier: LicenseTier.subscription, activated: true, key: key);
      _save();
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _info.key ?? '');
    await prefs.setString(_tier, _info.tier == LicenseTier.pro ? 'pro' : 'sub');
    await prefs.setBool(_activated, _info.activated);
  }

  bool canUseMode(String mode) {
    if (isPro || isSub) return true;
    const allowed = ['MANUAL', 'STABILIZE', 'LOITER', 'LAND'];
    return allowed.contains(mode);
  }

  bool hasFeature(String feature) {
    if (isPro || isSub) return true;
    const free = ['basic_map', 'waypoint_manual'];
    return free.contains(feature);
  }

  int get maxWp => (isPro || isSub) ? 999 : 5;
  double get maxSpd => (isPro || isSub) ? 80 : 30;
}
