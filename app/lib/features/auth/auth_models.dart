/// Mirrors the server's `/me` response. Hand-written for now; once the API
/// surface settles these should be generated from the server's OpenAPI doc
/// (served at /openapi.json) rather than maintained by hand.
class CurrentUser {
  const CurrentUser({
    required this.id,
    required this.onboardingStage,
    required this.tasteProfileCompleteness,
    this.email,
    this.phone,
    this.name,
    this.age,
    this.gender,
    this.intent,
    this.city,
    this.bio,
  });

  final String id;
  final String onboardingStage;
  final int tasteProfileCompleteness;
  final String? email;
  final String? phone;
  final String? name;
  final int? age;
  final String? gender;
  final String? intent;
  final String? city;
  final String? bio;

  bool get hasFinishedOnboarding => onboardingStage == 'complete';

  /// What we call them before they've told us their name.
  String get displayName => (name == null || name!.isEmpty) ? 'there' : name!;

  factory CurrentUser.fromJson(Map<String, dynamic> json) => CurrentUser(
        id: json['id'] as String,
        onboardingStage: json['onboardingStage'] as String? ?? 'basics',
        tasteProfileCompleteness: json['tasteProfileCompleteness'] as int? ?? 0,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        name: json['name'] as String?,
        age: json['age'] as int?,
        gender: json['gender'] as String?,
        intent: json['intent'] as String?,
        city: json['city'] as String?,
        bio: json['bio'] as String?,
      );
}

class OtpRequestResult {
  const OtpRequestResult({required this.channel, required this.expiresInSeconds, this.devCode});

  final String channel;
  final int expiresInSeconds;

  /// Only ever populated by a development server (DEV_ECHO_OTP). When present
  /// the OTP screen prefills it so the loop is testable with no SMS provider.
  final String? devCode;

  factory OtpRequestResult.fromJson(Map<String, dynamic> json) => OtpRequestResult(
        channel: json['channel'] as String? ?? 'email',
        expiresInSeconds: json['expiresInSeconds'] as int? ?? 600,
        devCode: json['devCode'] as String?,
      );
}
