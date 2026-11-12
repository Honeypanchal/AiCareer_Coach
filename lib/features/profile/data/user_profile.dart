class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String photoUrl;
  final String headline;
  final String location;
  final String targetRole;
  final String experienceLevel;
  final List<String> skills;
  final bool onboardingCompleted;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl = '',
    this.headline = '',
    this.location = '',
    this.targetRole = '',
    this.experienceLevel = '',
    this.skills = const [],
    this.onboardingCompleted = false,
  });

  String get firstName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'there';
    return trimmed.split(' ').first;
  }

  String get initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'U';
    return trimmed[0].toUpperCase();
  }

  bool get hasPhoto => photoUrl.isNotEmpty;

  /// Compact line used later as Gemini context (chat / resume / interview).
  String get careerContext {
    final parts = <String>[
      if (targetRole.isNotEmpty) 'Target role: $targetRole',
      if (experienceLevel.isNotEmpty) 'Experience: $experienceLevel',
      if (skills.isNotEmpty) 'Skills: ${skills.join(', ')}',
      if (headline.isNotEmpty) 'Headline: $headline',
      if (location.isNotEmpty) 'Location: $location',
    ];
    return parts.join('\n');
  }

  factory UserProfile.fromMap(String uid, Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    return UserProfile(
      uid: uid,
      name: (map['name'] as String?)?.trim() ?? '',
      email: (map['email'] as String?)?.trim() ?? '',
      photoUrl: (map['photoUrl'] as String?) ?? '',
      headline: (map['headline'] as String?) ?? '',
      location: (map['location'] as String?) ?? '',
      targetRole: (map['targetRole'] as String?) ?? '',
      experienceLevel: (map['experienceLevel'] as String?) ?? '',
      skills:
          (map['skills'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList() ??
          const [],
      onboardingCompleted: map['onboardingCompleted'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'headline': headline,
      'location': location,
      'targetRole': targetRole,
      'experienceLevel': experienceLevel,
      'skills': skills,
      'onboardingCompleted': onboardingCompleted,
    };
  }

  UserProfile copyWith({
    String? name,
    String? email,
    String? photoUrl,
    String? headline,
    String? location,
    String? targetRole,
    String? experienceLevel,
    List<String>? skills,
    bool? onboardingCompleted,
  }) {
    return UserProfile(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      headline: headline ?? this.headline,
      location: location ?? this.location,
      targetRole: targetRole ?? this.targetRole,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      skills: skills ?? this.skills,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }
}
