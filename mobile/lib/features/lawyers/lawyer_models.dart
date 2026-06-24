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

  // Defensive parsing: every field defaults instead of hard-casting. A single
  // null/missing field used to throw, and because the whole list is parsed in
  // one map() the entire lawyer list failed to load — the user saw "Could not
  // load lawyers" even though the API call succeeded.
  factory LawyerSummary.fromJson(Map<String, dynamic> j) {
    return LawyerSummary(
      id: j['id'] as String? ?? '',
      fullName: j['fullName'] as String? ?? 'Lawyer',
      profilePhotoUrl: j['profilePhotoUrl'] as String?,
      city: j['city'] as String?,
      state: j['state'] as String?,
      avgRating: (j['avgRating'] as num?)?.toDouble() ?? 0,
      totalRatings: (j['totalRatings'] as num?)?.toInt() ?? 0,
      isOnline: j['isOnline'] == true,
      languagesSpoken: (j['languagesSpoken'] as List<dynamic>? ?? []).cast<String>(),
      yearsExperience: (j['yearsExperience'] as num?)?.toInt() ?? 0,
    );
  }
}
