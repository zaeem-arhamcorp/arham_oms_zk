class BeatMasterModel {
  final int? id;
  final int? syncId;
  final String? beatCd;
  final String? beatName;
  final String? userCd;
  final String? createdAt;
  final String? createdBy;
  final String? updatedAt;
  final String? updatedBy;
  final String? moduleNo;
  final String? appType;

  BeatMasterModel({
    this.id,
    this.syncId,
    this.beatCd,
    this.beatName,
    this.userCd,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
    this.moduleNo,
    this.appType,
  });

  factory BeatMasterModel.fromJson(Map<String, dynamic> json) {
    return BeatMasterModel(
      id: (json['ID'] as num?)?.toInt(),
      syncId: (json['SYNC_ID'] as num?)?.toInt(),
      beatCd: json['BEAT_CD']?.toString(),
      beatName: json['BEAT_NAME']?.toString(),
      userCd: json['USER_CD']?.toString(),
      createdAt: json['CREATED_AT']?.toString(),
      createdBy: json['CREATED_BY']?.toString(),
      updatedAt: json['UPDATED_AT']?.toString(),
      updatedBy: json['UPDATED_BY']?.toString(),
      moduleNo: json['MODULE_NO']?.toString(),
      appType: json['APP_TYPE']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ID': id,
      'SYNC_ID': syncId,
      'BEAT_CD': beatCd,
      'BEAT_NAME': beatName,
      'USER_CD': userCd,
      'CREATED_AT': createdAt,
      'CREATED_BY': createdBy,
      'UPDATED_AT': updatedAt,
      'UPDATED_BY': updatedBy,
      'MODULE_NO': moduleNo,
      'APP_TYPE': appType,
    };
  }

  static List<BeatMasterModel> listFromJson(List<dynamic>? arr) {
    if (arr == null) return [];
    return arr
        .whereType<Map<String, dynamic>>()
        .map(BeatMasterModel.fromJson)
        .toList();
  }
}
