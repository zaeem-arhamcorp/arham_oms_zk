class StockistResponse {
  final int status;
  final String message;
  final List<Stockist> data;

  StockistResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory StockistResponse.fromJson(Map<String, dynamic> json) {
    return StockistResponse(
      status: json['status'] ?? 0,
      message: json['message'] ?? '',
      data: json['data'] != null
          ? List<Stockist>.from(
              (json['data'] as List).map((x) => Stockist.fromJson(x)))
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'message': message,
      'data': data.map((x) => x.toJson()).toList(),
    };
  }
}

class Stockist {
  final String accCd;
  final String accName;
  final String personNm;
  final String city;
  final String state;
  final String pincode;
  final String mobile1;
  final String? email;
  final String accAdd;
  final double lat;
  final double long;
  final String? imageUrl;

  Stockist({
    required this.accCd,
    required this.accName,
    required this.personNm,
    required this.city,
    required this.state,
    required this.pincode,
    required this.mobile1,
    this.email,
    required this.accAdd,
    required this.lat,
    required this.long,
    this.imageUrl,
  });

  factory Stockist.fromJson(Map<String, dynamic> json) {
    return Stockist(
      accCd: json['ACC_CD'] ?? '',
      accName: json['ACC_NAME'] ?? '',
      personNm: json['PERSON_NM'] ?? '',
      city: json['CITY'] ?? '',
      state: json['STATE'] ?? '',
      pincode: json['PINCODE'] ?? '',
      mobile1: json['MOBILE1'] ?? '',
      email: json['EMAIL'],
      accAdd: json['ACC_ADD'] ?? '',
      lat: (json['LAT'] as num?)?.toDouble() ?? 0.0,
      long: (json['LONG'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['IMAGE_URL'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ACC_CD': accCd,
      'ACC_NAME': accName,
      'PERSON_NM': personNm,
      'CITY': city,
      'STATE': state,
      'PINCODE': pincode,
      'MOBILE1': mobile1,
      'EMAIL': email,
      'ACC_ADD': accAdd,
      'LAT': lat,
      'LONG': long,
      'IMAGE_URL': imageUrl,
    };
  }

  @override
  String toString() => accName;
}
