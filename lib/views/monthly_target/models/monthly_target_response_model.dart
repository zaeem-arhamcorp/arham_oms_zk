class MonthlyTargetResponseModel {
  MonthlyTargetResponseModel({
    required this.message,
    required this.data,
  });

  final String message;
  final Map<String, dynamic>? data;

  factory MonthlyTargetResponseModel.fromJson(Map<String, dynamic> json) {
    final dynamic rawData = json['data'];
    return MonthlyTargetResponseModel(
      message: json['message']?.toString() ?? '',
      data: rawData is Map<String, dynamic> ? rawData : null,
    );
  }
}
