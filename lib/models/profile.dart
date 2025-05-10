class Profile {
  final String id;
  final String fullName;
  final String? email;
  final String? bio;
  final String? farmName;
  final String? location;
  final String? farmType;
  final List<String>? products;
  final String? avatarUrl;
  final String? coverImageUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Profile({
    required this.id,
    required this.fullName,
    this.email,
    this.bio,
    this.farmName,
    this.location,
    this.farmType,
    this.products,
    this.avatarUrl,
    this.coverImageUrl,
    required this.createdAt,
    this.updatedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    // Null kontrolü yaparak güvenli bir şekilde oluştur
    return Profile(
      id: json['id'] ?? '',
      fullName: json['full_name'] ?? 'Kullanıcı',
      email: json['email'],
      bio: json['bio'],
      farmName: json['farm_name'],
      location: json['location'],
      farmType: json['farm_type'],
      products:
          json['products'] != null ? List<String>.from(json['products']) : null,
      avatarUrl: json['avatar_url'],
      coverImageUrl: json['cover_image_url'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  // Varsayılan değerlerle yeni bir kopya oluştur
  Profile copyWith({
    String? id,
    String? fullName,
    String? email,
    String? bio,
    String? farmName,
    String? location,
    String? farmType,
    List<String>? products,
    String? avatarUrl,
    String? coverImageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Profile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      farmName: farmName ?? this.farmName,
      location: location ?? this.location,
      farmType: farmType ?? this.farmType,
      products: products ?? this.products,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
