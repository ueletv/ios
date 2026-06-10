/// 提现配置（对应 WithdrawConfig.kt）
class WithdrawConfig {
  final bool enabled;
  final int minAmount;
  final int maxAmount;
  final double feeRate;
  final double coinsRate;
  final Map<String, WithdrawTypeItem>? types;

  WithdrawConfig({
    required this.enabled,
    required this.minAmount,
    required this.maxAmount,
    required this.feeRate,
    required this.coinsRate,
    this.types,
  });

  factory WithdrawConfig.fromJson(Map<String, dynamic> json) {
    Map<String, WithdrawTypeItem>? typeMap;
    if (json['types'] is Map) {
      typeMap = {};
      (json['types'] as Map).forEach((key, value) {
        typeMap![key.toString()] = WithdrawTypeItem.fromJson(value as Map<String, dynamic>);
      });
    }
    return WithdrawConfig(
      enabled: json['enabled'] as bool? ?? false,
      minAmount: (json['min_amount'] as num?)?.toInt() ?? 0,
      maxAmount: (json['max_amount'] as num?)?.toInt() ?? 0,
      feeRate: (json['fee_rate'] as num?)?.toDouble() ?? 0,
      coinsRate: (json['coins_rate'] as num?)?.toDouble() ?? 0,
      types: typeMap,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'min_amount': minAmount,
    'max_amount': maxAmount,
    'fee_rate': feeRate,
    'coins_rate': coinsRate,
    'types': types?.map((k, v) => MapEntry(k, v.toJson())),
  };
}

/// 提现方式（对应 WithdrawTypeItem.kt）
class WithdrawTypeItem {
  final String name;
  final int enabled;

  WithdrawTypeItem({required this.name, required this.enabled});

  factory WithdrawTypeItem.fromJson(Map<String, dynamic> json) {
    return WithdrawTypeItem(
      name: json['name'] as String? ?? '',
      enabled: (json['enabled'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'enabled': enabled};
}
