class AccountModel {
  final String accName;
  final String personNm;
  final String mobile1;
  final String add1;
  final String area;
  final String city;
  final String state;
  final String pincode;
  final double latitude;
  final double longitude;

  final String? gstNo;
  final String gstType;
  final String? drugLic1;
  final String? drugLic2;
  final String? fssaiNo;

  AccountModel({
    required this.accName,
    required this.personNm,
    required this.mobile1,
    required this.add1,
    required this.area,
    required this.city,
    required this.state,
    required this.pincode,
    required this.latitude,
    required this.longitude,
    this.gstNo,
    required this.gstType,
    this.drugLic1,
    this.drugLic2,
    this.fssaiNo,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'accName': accName,
      'personNm': personNm,
      "groupCd": "85",
      "blackList": "N",
      "moduleNo": "102",
      'mobile1': mobile1,
      'add1': add1,
      'zone': area,
      'city': city,
      'state': state,
      'pincode': pincode,
      'gstType': gstType,
      'latitude': latitude,
      'longitude': longitude,
    };

    // Optional fields (only if present)
    if (gstNo != null && gstNo!.isNotEmpty) {
      data['gstNo'] = gstNo;
    }
    if (drugLic1 != null && drugLic1!.isNotEmpty) {
      data['drugLic1'] = drugLic1;
    }
    if (drugLic2 != null && drugLic2!.isNotEmpty) {
      data['drugLic2'] = drugLic2;
    }
    if (fssaiNo != null && fssaiNo!.isNotEmpty) {
      data['fssaiNo'] = fssaiNo;
    }

    return data;
  }
}
