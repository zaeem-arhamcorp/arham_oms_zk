class FirmModel {
  final String? firmID; // Make firmID nullable
  final String firmName;
  final String address1;
  final String address2;
  final String address3;
  final String address4;
  final String address5;
  final String firmCity;
  final String firmState;
  final String firmStateCode;
  final String firmZone;
  final String firmMobile1;
  final String firmMobile2;
  final String firmPersonName;
  final String firmEmailId;
  final String firmUpi;
  final String firmGstNo;
  final String firmGstType;
  final String firmPanNo;
  final String firmFssaiNo;
  final String firmRegistrationNo1;
  final String firmRegistrationNo2;
  final double tcsWithPan;
  final double tcsWithoutPan;
  final String tcsAuto;
  final double tcsAbove;
  final DateTime createdAt;
  final String footer1;
  final String footer2;
  final String footer3;
  final String footer4;
  final String footer5;
  final String pinCode;

  FirmModel({
    this.firmID, // Optional firmID
    required this.firmName,
    required this.address1,
    required this.address2,
    required this.address3,
    required this.address4,
    required this.address5,
    required this.firmCity,
    required this.firmState,
    required this.firmStateCode,
    required this.firmZone,
    required this.firmMobile1,
    required this.firmMobile2,
    required this.firmPersonName,
    required this.firmEmailId,
    required this.firmUpi,
    required this.firmGstNo,
    required this.firmGstType,
    required this.firmPanNo,
    required this.firmFssaiNo,
    required this.firmRegistrationNo1,
    required this.firmRegistrationNo2,
    required this.tcsWithPan,
    required this.tcsWithoutPan,
    required this.tcsAuto,
    required this.tcsAbove,
    required this.createdAt,
    required this.footer1,
    required this.footer2,
    required this.footer3,
    required this.footer4,
    required this.footer5,
    required this.pinCode,
  });

  // Empty Constructor
  FirmModel.empty()
      : firmID = '',
        firmName = '',
        address1 = '',
        address2 = '',
        address3 = '',
        address4 = '',
        address5 = '',
        firmCity = '',
        firmState = '',
        firmStateCode = '',
        firmZone = '',
        firmMobile1 = '',
        firmMobile2 = '',
        firmPersonName = '',
        firmEmailId = '',
        firmUpi = '',
        firmGstNo = '',
        firmGstType = '',
        firmPanNo = '',
        firmFssaiNo = '',
        firmRegistrationNo1 = '',
        firmRegistrationNo2 = '',
        tcsWithPan = 0.0,
        tcsWithoutPan = 0.0,
        tcsAuto = '',
        tcsAbove = 0.0,
        createdAt = DateTime.now(),
        footer1 = '',
        footer2 = '',
        footer3 = '',
        footer4 = '',
        footer5 = '',
        pinCode = '';

  factory FirmModel.fromJson(Map<String, dynamic> json) {
    return FirmModel(
      firmID: json['firmID'],
      firmName: json['firmName'] ?? '',
      address1: json['address1'] ?? '',
      address2: json['address2'] ?? '',
      address3: json['address3'] ?? '',
      address4: json['address4'] ?? '',
      address5: json['address5'] ?? '',
      firmCity: json['firmCity'] ?? '',
      firmState: json['firmState'] ?? '',
      firmStateCode: json['firmStateCode'] ?? '',
      firmZone: json['firmZone'] ?? '',
      firmMobile1: json['firmMobile1'] ?? '',
      firmMobile2: json['firmMobile2'] ?? '',
      firmPersonName: json['firmPersonName'] ?? '',
      firmEmailId: json['firmEmailId'] ?? '',
      firmUpi: json['firmUpi'] ?? '',
      firmGstNo: json['firmGstNo'] ?? '',
      firmGstType: json['firmGstType'] ?? '',
      firmPanNo: json['firmPanNo'] ?? '',
      firmFssaiNo: json['firmFssaiNo'] ?? '',
      firmRegistrationNo1: json['firmRegistrationNo1'] ?? '',
      firmRegistrationNo2: json['firmRegistrationNo2'] ?? '',
      tcsWithPan: (json['tcsWithPan'] is int)
          ? json['tcsWithPan'].toDouble()
          : json['tcsWithPan'] ?? 0.0,
      tcsWithoutPan: (json['tcsWithoutPan'] is int)
          ? json['tcsWithoutPan'].toDouble()
          : json['tcsWithoutPan'] ?? 0.0,
      tcsAuto: json['tcsAuto'] ?? '',
      tcsAbove: (json['tcsAbove'] is int)
          ? json['tcsAbove'].toDouble()
          : json['tcsAbove'] ?? 0.0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      footer1: json['footer1'] ?? '',
      footer2: json['footer2'] ?? '',
      footer3: json['footer3'] ?? '',
      footer4: json['footer4'] ?? '',
      footer5: json['footer5'] ?? '',
      pinCode: json['pinCode'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    final data = {
      'firmID': firmID,
      'firmName': firmName,
      'address1': address1,
      'address2': address2,
      'address3': address3,
      'address4': address4,
      'address5': address5,
      'firmCity': firmCity,
      'firmState': firmState,
      'firmStateCode': firmStateCode,
      'firmZone': firmZone,
      'firmMobile1': firmMobile1,
      'firmMobile2': firmMobile2,
      'firmPersonName': firmPersonName,
      'firmEmailId': firmEmailId,
      'firmUpi': firmUpi,
      'firmGstNo': firmGstNo,
      'firmGstType': firmGstType,
      'firmPanNo': firmPanNo,
      'firmFssaiNo': firmFssaiNo,
      'firmRegistrationNo1': firmRegistrationNo1,
      'firmRegistrationNo2': firmRegistrationNo2,
      'tcsWithPan': tcsWithPan,
      'tcsWithoutPan': tcsWithoutPan,
      'tcsAuto': tcsAuto,
      'tcsAbove': tcsAbove,
      'createdAt': createdAt.toIso8601String(),
      'footer1': footer1,
      'footer2': footer2,
      'footer3': footer3,
      'footer4': footer4,
      'footer5': footer5,
      'pinCode': pinCode,
    };

    // Include firmID only if it is not null or empty
    if (firmID != null && firmID!.isNotEmpty) {
      data['firmID'] = firmID!;
    }

    return data;
  }

  @override
  String toString() {
    return 'FirmModel(firmName: $firmName, firmCity: $firmCity, firmState: $firmState, firmMobile1: $firmMobile1,firmGstType:$firmGstType.firmID:$firmID)';
  }
}
