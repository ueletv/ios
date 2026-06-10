/// 充值规则（对应 RechargeRule.kt）
class RechargeRule {
  final int id;
  final int amount;
  final int coins;
  final int bonusCoins;
  final int totalCoins;
  final String? description;

  RechargeRule({
    required this.id,
    required this.amount,
    required this.coins,
    this.bonusCoins = 0,
    required this.totalCoins,
    this.description,
  });

  factory RechargeRule.fromJson(Map<String, dynamic> json) {
    return RechargeRule(
      id: (json['id'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      bonusCoins: (json['bonus_coins'] as num?)?.toInt() ?? 0,
      totalCoins: (json['total_coins'] as num?)?.toInt() ?? 0,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'coins': coins,
    'bonus_coins': bonusCoins,
    'total_coins': totalCoins,
    'description': description,
  };
}

/// 充值订单（对应 RechargeOrder.kt）
class RechargeOrder {
  final int orderId;
  final String orderNo;
  final int amount;
  final int totalCoins;

  RechargeOrder({
    required this.orderId,
    required this.orderNo,
    required this.amount,
    required this.totalCoins,
  });

  factory RechargeOrder.fromJson(Map<String, dynamic> json) {
    return RechargeOrder(
      orderId: (json['order_id'] as num?)?.toInt() ?? 0,
      orderNo: json['order_no'] as String? ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      totalCoins: (json['total_coins'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'order_id': orderId,
    'order_no': orderNo,
    'amount': amount,
    'total_coins': totalCoins,
  };
}
