class MonthlyTargetItemModel {
  MonthlyTargetItemModel({
    required this.id,
    required this.syncId,
    required this.targetDesc,
    required this.targetDate,
    required this.targetMonth,
    required this.moduleNo,
    required this.type,
    required this.appType,
    required this.userCd,
    required this.salesmanTargetAmount,
    required this.pobAmount,
    required this.pobLastSyncAt,
    required this.stockistCd,
    required this.primaryTargetAmount,
    required this.secondaryAmount,
    required this.createdBy,
    required this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int syncId;
  final String targetDesc;
  final String targetDate;
  final String targetMonth;
  final String moduleNo;
  final String type;
  final String appType;
  final String userCd;
  final double salesmanTargetAmount;
  final double pobAmount;
  final String pobLastSyncAt;
  final String stockistCd;
  final double primaryTargetAmount;
  final double secondaryAmount;
  final String createdBy;
  final String updatedBy;
  final String createdAt;
  final String updatedAt;

  factory MonthlyTargetItemModel.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic value) {
      if (value == null) {
        return 0;
      }
      if (value is num) {
        return value.toDouble();
      }
      return double.tryParse(value.toString()) ?? 0;
    }

    int toInt(dynamic value) {
      if (value == null) {
        return 0;
      }
      if (value is num) {
        return value.toInt();
      }
      return int.tryParse(value.toString()) ?? 0;
    }

    return MonthlyTargetItemModel(
      id: toInt(json['ID']),
      syncId: toInt(json['SYNC_ID']),
      targetDesc: (json['TARGET_DESC'] ?? '').toString(),
      targetDate: (json['TARGET_DATE'] ?? '').toString(),
      targetMonth: (json['TARGET_MONTH'] ?? '').toString(),
      moduleNo: (json['MODULE_NO'] ?? '').toString(),
      type: (json['TYPE'] ?? '').toString(),
      appType: (json['APP_TYPE'] ?? '').toString(),
      userCd: (json['USER_CD'] ?? '').toString(),
      salesmanTargetAmount: toDouble(json['SALESMAN_TARGET_AMOUNT']),
      pobAmount: toDouble(json['POB_AMOUNT']),
      pobLastSyncAt: (json['POB_LAST_SYNC_AT'] ?? '').toString(),
      stockistCd: (json['STOCKIST_CD'] ?? '').toString(),
      primaryTargetAmount: toDouble(json['PRIMARY_TARGET_AMOUNT']),
      secondaryAmount: toDouble(json['SECONDARY_AMOUNT']),
      createdBy: (json['CREATED_BY'] ?? '').toString(),
      updatedBy: (json['UPDATED_BY'] ?? '').toString(),
      createdAt: (json['CREATED_AT'] ?? '').toString(),
      updatedAt: (json['UPDATED_AT'] ?? '').toString(),
    );
  }
}
