class SignupResponse {
  final bool status;
  final String message;
  final Map<String, dynamic>? data;

  SignupResponse({
    required this.status,
    required this.message,
    this.data,
  });
}
