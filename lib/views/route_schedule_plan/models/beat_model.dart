class Beat {
  final int id;
  final String beatCd;
  final String beatName;

  Beat({required this.id, required this.beatCd, required this.beatName});

  factory Beat.fromJson(Map<String, dynamic> json) {
    return Beat(
      id: (json['ID'] as num?)?.toInt() ?? 0,
      beatCd: (json['BEAT_CD'] ?? '').toString(),
      beatName: (json['BEAT_NAME'] ?? '').toString(),
    );
  }

  static List<Beat> listFromJson(List<dynamic>? arr) {
    if (arr == null) return [];
    return arr.whereType<Map<String, dynamic>>().map(Beat.fromJson).toList();
  }
}

/// Beat scheduled for a specific user on a specific date
class BeatScheduler {
  final int id;
  final String userCd;
  final String beatCd;
  final String beatName;
  final String assignDate; // YYYY-MM-DD format

  BeatScheduler({
    required this.id,
    required this.userCd,
    required this.beatCd,
    required this.beatName,
    required this.assignDate,
  });

  factory BeatScheduler.fromJson(Map<String, dynamic> json) {
    return BeatScheduler(
      id: (json['ID'] as num?)?.toInt() ?? 0,
      userCd: (json['USER_CD'] ?? '').toString(),
      beatCd: (json['BEAT_CD'] ?? '').toString(),
      beatName: (json['BEAT_NAME'] ?? '').toString(),
      assignDate: (json['ASSIGN_DATE'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userCd': userCd,
      'assignDate': assignDate,
      'beatCd': beatCd,
      'moduleNo': '102',
    };
  }

  static List<BeatScheduler> listFromJson(List<dynamic>? arr) {
    if (arr == null) return [];
    return arr
        .whereType<Map<String, dynamic>>()
        .map(BeatScheduler.fromJson)
        .toList();
  }
}
