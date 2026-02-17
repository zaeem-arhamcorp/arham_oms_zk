class StateResponse {
  String? message;
  List<StateModel>? data;

  StateResponse({this.message, this.data});

  StateResponse.fromJson(Map<String, dynamic> json) {
    message = json['message'];
    if (json['data'] != null) {
      data = <StateModel>[];
      json['data'].forEach((v) {
        data!.add(StateModel.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['message'] = message;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class StateModel {
  String? stateCd;
  String? stateName;

  StateModel({this.stateCd, this.stateName});

  StateModel.fromJson(Map<String, dynamic> json) {
    stateCd = json['state_cd'];
    stateName = json['state_name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['state_cd'] = stateCd;
    data['state_name'] = stateName;
    return data;
  }
}
