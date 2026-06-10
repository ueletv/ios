/// 彩票列表项（对应 LotteryItem.kt）
class LotteryItem {
  final int id;
  final String nameZh;
  final String? biaoshi;
  final String? icon;
  final String? expects;
  final String? minites;
  final int? status;
  final String? contentZh;

  LotteryItem({
    required this.id,
    required this.nameZh,
    this.biaoshi,
    this.icon,
    this.expects,
    this.minites,
    this.status,
    this.contentZh,
  });

  factory LotteryItem.fromJson(Map<String, dynamic> json) {
    return LotteryItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nameZh: json['name_zh'] as String? ?? '',
      biaoshi: json['biaoshi'] as String?,
      icon: json['icon'] as String?,
      expects: json['expects'] as String?,
      minites: json['minites'] as String?,
      status: (json['status'] as num?)?.toInt(),
      contentZh: json['content_zh'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name_zh': nameZh,
    'biaoshi': biaoshi,
    'icon': icon,
    'expects': expects,
    'minites': minites,
    'status': status,
    'content_zh': contentZh,
  };
}

/// 倍数列表项（对应 BeishuItem.kt）
class BeishuItem {
  final int? id;
  final num? beishu;
  final num? status;

  BeishuItem({this.id, this.beishu, this.status});

  bool get isEnabled => (status?.toInt() ?? 0) == 1;

  int get beishuValue => beishu?.toInt() ?? 0;

  factory BeishuItem.fromJson(Map<String, dynamic> json) {
    return BeishuItem(
      id: (json['id'] as num?)?.toInt(),
      beishu: json['beishu'] as num?,
      status: json['status'] as num?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'beishu': beishu,
    'status': status,
  };
}

/// 彩票玩法
class LotteryWanfa {
  final int id;
  final String name;
  final String? icon;
  final List<LotteryPlayItem>? plays;

  LotteryWanfa({
    required this.id,
    required this.name,
    this.icon,
    this.plays,
  });

  factory LotteryWanfa.fromJson(Map<String, dynamic> json) {
    return LotteryWanfa(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String?,
      plays: json['plays'] != null
          ? (json['plays'] as List)
              .map((e) => LotteryPlayItem.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'plays': plays?.map((e) => e.toJson()).toList(),
  };
}

/// 彩票玩法选项
class LotteryPlayItem {
  final String name;
  final String? rate;
  final String? type;

  LotteryPlayItem({required this.name, this.rate, this.type});

  factory LotteryPlayItem.fromJson(Map<String, dynamic> json) {
    return LotteryPlayItem(
      name: json['name'] as String? ?? '',
      rate: json['rate'] as String?,
      type: json['type'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'rate': rate,
    'type': type,
  };
}
