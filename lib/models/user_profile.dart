/// Профиль пользователя с [GET .../profile/me.php].
class UserProfile {
  const UserProfile({
    required this.id,
    required this.phone,
    required this.firstName,
    required this.lastName,
    required this.middleName,
    required this.email,
    required this.displayName,
    this.isPro = false,
  });

  final int id;
  final String phone;
  final String firstName;
  final String lastName;
  final String middleName;
  final String email;
  final String displayName;
  final bool isPro;

  static UserProfile fromJson(Map<String, dynamic> json) {
    final Object? rawPro = json['is_pro'];
    final bool pro = rawPro == true ||
        rawPro == 1 ||
        rawPro == '1' ||
        rawPro == 'true';
    return UserProfile(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      phone: '${json['phone'] ?? ''}',
      firstName: '${json['first_name'] ?? ''}',
      lastName: '${json['last_name'] ?? ''}',
      middleName: '${json['middle_name'] ?? ''}',
      email: '${json['email'] ?? ''}',
      displayName: '${json['display_name'] ?? ''}'.trim().isEmpty
          ? 'Пользователь'
          : '${json['display_name']}'.trim(),
      isPro: pro,
    );
  }
}
