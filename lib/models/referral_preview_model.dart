class ReferralPreview {
  const ReferralPreview({
    required this.valid,
    required this.empty,
    required this.referredGems,
    required this.referrerGems,
    required this.unlockLevel,
  });

  final bool valid;
  final bool empty;
  final int referredGems;
  final int referrerGems;
  final int unlockLevel;

  factory ReferralPreview.empty() => const ReferralPreview(
        valid: false,
        empty: true,
        referredGems: 25,
        referrerGems: 50,
        unlockLevel: 5,
      );

  factory ReferralPreview.fromJson(Map<String, dynamic> json) {
    return ReferralPreview(
      valid: json['valid'] == true,
      empty: json['empty'] == true,
      referredGems: (json['referred_gems'] as num?)?.toInt() ?? 25,
      referrerGems: (json['referrer_gems'] as num?)?.toInt() ?? 50,
      unlockLevel: (json['unlock_level'] as num?)?.toInt() ?? 5,
    );
  }
}
