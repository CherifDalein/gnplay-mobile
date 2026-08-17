class RegisterRequest {
  const RegisterRequest({
    required this.fullName,
    required this.phoneNumber,
    required this.countryIso2,
    required this.password,
  });

  final String fullName;
  final String phoneNumber;
  final String countryIso2;
  final String password;

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'phone_number': phoneNumber,
      'country_iso2': countryIso2,
      'password': password,
    };
  }
}
