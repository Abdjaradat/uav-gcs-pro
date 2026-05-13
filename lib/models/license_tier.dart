enum LicenseTier { demo, pro, subscription }

class LicenseInfo {
  final LicenseTier tier;
  final bool activated;
  final String? key;

  LicenseInfo({required this.tier, this.activated = false, this.key});

  bool get isDemo => tier == LicenseTier.demo || !activated;
  bool get isPro => tier == LicenseTier.pro && activated;
  bool get isSub => tier == LicenseTier.subscription && activated;
}
