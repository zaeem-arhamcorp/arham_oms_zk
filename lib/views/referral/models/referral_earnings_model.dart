class ReferralEarningsResponse {
  final bool status;
  final String message;
  final ReferralEarningsData? data;

  ReferralEarningsResponse({
    required this.status,
    required this.message,
    this.data,
  });

  factory ReferralEarningsResponse.fromJson(Map<String, dynamic> json) {
    return ReferralEarningsResponse(
      status: json['status'] == true,
      message: (json['message'] ?? '').toString(),
      data: json['data'] is Map<String, dynamic>
          ? ReferralEarningsData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ReferralEarningsData {
  final String userCd;
  final String mobileNo;
  final int totalReferrals;
  final int successfulReferrals;
  final int totalEarnings;
  final int pendingEarnings;
  final int paidEarnings;
  final List<dynamic> referralsList;

  ReferralEarningsData({
    required this.userCd,
    required this.mobileNo,
    required this.totalReferrals,
    required this.successfulReferrals,
    required this.totalEarnings,
    required this.pendingEarnings,
    required this.paidEarnings,
    required this.referralsList,
  });

  factory ReferralEarningsData.fromJson(Map<String, dynamic> json) {
    return ReferralEarningsData(
      userCd: (json['USER_CD'] ?? '').toString(),
      mobileNo: (json['MOBILE_NO'] ?? '').toString(),
      totalReferrals: _toInt(json['TOTAL_REFERRALS']),
      successfulReferrals: _toInt(json['SUCCESSFUL_REFERRALS']),
      totalEarnings: _toInt(json['TOTAL_EARNINGS']),
      pendingEarnings: _toInt(json['PENDING_EARNINGS']),
      paidEarnings: _toInt(json['PAID_EARNINGS']),
      referralsList: json['referrals_list'] is List
          ? List<dynamic>.from(json['referrals_list'] as List)
          : const <dynamic>[],
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
