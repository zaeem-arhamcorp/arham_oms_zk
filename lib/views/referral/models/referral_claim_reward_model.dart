class ReferralClaimRewardRequest {
  final String amount;
  final String paymentMethod;

  ReferralClaimRewardRequest({
    required this.amount,
    required this.paymentMethod,
  });

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'payment_method': paymentMethod,
    };
  }
}

class ReferralClaimRewardResponse {
  final bool status;
  final String message;
  final Map<String, dynamic>? data;

  ReferralClaimRewardResponse({
    required this.status,
    required this.message,
    this.data,
  });

  factory ReferralClaimRewardResponse.fromJson(Map<String, dynamic> json) {
    return ReferralClaimRewardResponse(
      status: json['status'] == true,
      message: (json['message'] ?? '').toString(),
      data: json['data'] is Map<String, dynamic>
          ? json['data'] as Map<String, dynamic>
          : null,
    );
  }
}
