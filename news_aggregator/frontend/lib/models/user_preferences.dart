class UserPreferences {
  final List<String> selectedTopics;
  final String language;
  final String? country;

  UserPreferences({
    required this.selectedTopics,
    required this.language,
    this.country,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      selectedTopics: List<String>.from(json['selectedTopics'] ?? []),
      language: json['language'] ?? 'en',
      country: json['country'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'selectedTopics': selectedTopics,
      'language': language,
      'country': country,
    };
  }

  // Create a copy with updated values
  UserPreferences copyWith({
    List<String>? selectedTopics,
    String? language,
    String? country,
  }) {
    return UserPreferences(
      selectedTopics: selectedTopics ?? this.selectedTopics,
      language: language ?? this.language,
      country: country ?? this.country,
    );
  }
}