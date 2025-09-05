class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? photoUrl;
  final String userType; 
  final DateTime createdAt;
  final bool isActive;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? businessName;
  final String? description;
  final String? experience;
  final String? specialization;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.photoUrl,
    required this.userType,
    required this.createdAt,
    this.isActive = true,
    this.latitude,
    this.longitude,
    this.address,
    this.businessName,
    this.description,
    this.experience,
    this.specialization,
  });

  bool get isProvider => userType.toLowerCase() == 'provider';
  bool get isCustomer => userType.toLowerCase() == 'customer';

  factory UserModel.fromRealtimeDatabase(Map<dynamic, dynamic> data) {
    return UserModel(
      id: data['id']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      photoUrl: data['photoUrl']?.toString(),
      userType: data['userType']?.toString() ?? 'customer',
      createdAt: data['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['createdAt'])
          : DateTime.now(),
      isActive: data['isActive'] ?? true,
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      address: data['address']?.toString(),
      businessName: data['businessName']?.toString(),
      description: data['description']?.toString(),
      experience: data['experience']?.toString(),
      specialization: data['specialization'],
    );
  }

  Map<String, dynamic> toRealtimeDatabase() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'photoUrl': photoUrl,
      'userType': userType,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'isActive': isActive,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'experience': experience,
      'specialization': specialization,
      'businessName': businessName,
      'description': description,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
    String? userType,
    DateTime? createdAt,
    bool? isActive,
    double? latitude,
    double? longitude,
    String? address,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      userType: userType ?? this.userType,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
    );
  }
}
