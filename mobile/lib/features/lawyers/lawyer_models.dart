class LawyerSummary {
  LawyerSummary({
    required this.id,
    required this.fullName,
    this.profilePhotoUrl,
    this.city,
    this.state,
    required this.avgRating,
    required this.totalRatings,
    required this.isOnline,
    required this.languagesSpoken,
    required this.yearsExperience,
  });

  final String id;
  final String fullName;
  final String? profilePhotoUrl;
  final String? city;
  final String? state;
  final double avgRating;
  final int totalRatings;
  final bool isOnline;
  final List<String> languagesSpoken;
  final int yearsExperience;

  factory LawyerSummary.fromJson(Map<String, dynamic> j) {
    return LawyerSummary(
      id: j['id'] as String,
      fullName: j['fullName'] as String,
      profilePhotoUrl: j['profilePhotoUrl'] as String?,
      city: j['city'] as String?,
      state: j['state'] as String?,
      avgRating: (j['avgRating'] as num).toDouble(),
      totalRatings: j['totalRatings'] as int,
      isOnline: j['isOnline'] as bool,
      languagesSpoken: (j['languagesSpoken'] as List<dynamic>? ?? []).cast<String>(),
      yearsExperience: j['yearsExperience'] as int,
    );
  }
}
