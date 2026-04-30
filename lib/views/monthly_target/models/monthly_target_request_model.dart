class MonthlyTargetRequestModel {
  MonthlyTargetRequestModel({
    required this.targetDate,
    required this.salesmanTargetAmount,
  });

  final DateTime targetDate;
  final int salesmanTargetAmount;

  Map<String, dynamic> toJson() => {
        'targetDate':
            '${targetDate.year.toString().padLeft(4, '0')}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}',
        'type': 'POB',
        'salesmanTargetAmount ': salesmanTargetAmount,
      };
}
