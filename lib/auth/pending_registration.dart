class PendingRegistration {
  const PendingRegistration({
    required this.phone,
    required this.smsCode,
    this.lastName = '',
    this.firstName = '',
    this.middleName = '',
    this.email = '',
  });

  final String phone;
  final String smsCode;
  final String lastName;
  final String firstName;
  final String middleName;
  final String email;

  PendingRegistration copyWith({
    String? phone,
    String? smsCode,
    String? lastName,
    String? firstName,
    String? middleName,
    String? email,
  }) {
    return PendingRegistration(
      phone: phone ?? this.phone,
      smsCode: smsCode ?? this.smsCode,
      lastName: lastName ?? this.lastName,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      email: email ?? this.email,
    );
  }
}
