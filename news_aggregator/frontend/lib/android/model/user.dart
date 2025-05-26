class User {
  final int id;
  final String username;
  final String displayName;
  final String email;
  final String bio;
  final String preferredLanguage;
  final String country;
  
  User({
    required this.id,
    required this.username,
    required this.displayName,
    required this.email,
    required this.bio,
    required this.preferredLanguage,
    required this.country,
  });
  
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      displayName: map['display_name'] ?? '',
      email: map['email'] ?? '',
      bio: map['bio'] ?? '',
      preferredLanguage: map['preferred_language'] ?? '',
      country: map['country'] ?? '',
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'display_name': displayName,
      'email': email,
      'bio': bio,
      'preferred_language': preferredLanguage,
      'country': country,
    };
  }
}