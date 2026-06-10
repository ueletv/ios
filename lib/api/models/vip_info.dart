import 'dart:convert' show JsonDecoder;

/// VIP 套餐信息（对应 VipInfo.kt）
class VipInfo {
  final int type;
  final String? name;
  final num? price;
  final int? minutes;
  final int? hours;
  final int? days;
  final String? timeUnit;
  final int? timeValue;
  final int? sort;

  VipInfo({
    this.type = 0,
    this.name,
    this.price,
    this.minutes,
    this.hours,
    this.days,
    this.timeUnit,
    this.timeValue,
    this.sort,
  });

  String get timeText {
    if (days != null && days! > 0) return '$days天';
    if (hours != null && hours! > 0) return '$hours小时';
    if (minutes != null && minutes! > 0) return '$minutes分钟';
    if (timeUnit != null && timeValue != null) return '$timeValue$timeUnit';
    return '';
  }

  String get priceDisplay {
    if (price == null) return '';
    final v = price is double ? (price as double) : (price as int).toDouble();
    if (v == v.roundToDouble()) return '¥${v.toInt()}';
    return '¥${v.toStringAsFixed(2)}';
  }

  factory VipInfo.fromJson(Map<String, dynamic> json) {
    return VipInfo(
      type: (json['type'] as num?)?.toInt() ?? 0,
      name: json['name'] as String?,
      price: json['price'] as num?,
      minutes: (json['minutes'] as num?)?.toInt(),
      hours: (json['hours'] as num?)?.toInt(),
      days: (json['days'] as num?)?.toInt(),
      timeUnit: json['time_unit'] as String?,
      timeValue: (json['time_value'] as num?)?.toInt(),
      sort: (json['sort'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'name': name,
    'price': price,
    'minutes': minutes,
    'hours': hours,
    'days': days,
    'time_unit': timeUnit,
    'time_value': timeValue,
    'sort': sort,
  };
}

/// VIP 信息解析器（对应 VipInfoParser.kt）
class VipInfoParser {
  static List<VipInfo> parseList(dynamic data) {
    if (data is List) {
      if (data.isEmpty) return [];
      // 新格式：直接是 VipInfo 列表
      if (data.first is Map && (data.first as Map).containsKey('type')) {
        return data.map((e) => VipInfo.fromJson(e as Map<String, dynamic>)).toList();
      }
      // 旧格式：[{key: "vip_price_1", value: "{...json...}"}]
      return data.map((e) => _parseRow(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  static VipInfo _parseRow(Map<String, dynamic> row) {
    if (row.containsKey('type')) {
      return VipInfo.fromJson(row);
    }
    final key = row['key'] as String? ?? '';
    final value = row['value'] as String? ?? '';
    final typeMatch = RegExp(r'vip_price_(\d+)').firstMatch(key);
    final type = typeMatch != null ? int.tryParse(typeMatch.group(1)!) ?? 0 : 0;
    try {
      final inner = _tryParseJson(value);
      if (inner != null) {
        inner['type'] = type;
        return VipInfo.fromJson(inner);
      }
    } catch (_) {}
    return VipInfo(type: type);
  }

  static Map<String, dynamic>? _tryParseJson(String json) {
    try {
      return Map<String, dynamic>.from(
          const JsonDecoder().convert(json) as Map);
    } catch (_) {
      return null;
    }
  }
}
