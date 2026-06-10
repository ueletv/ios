/// 用户余额工具（对应 User.kt liveCoinValue / formatLiveCoinInteger）
class UserBalanceHelper {
  static double liveCoinValue(Map<String, dynamic> data) {
    final c = _parseNum(data['coin']) ?? 0;
    final cb = _parseNum(data['coin_balance']) ?? 0;
    final bal = _parseNum(data['balance']) ?? 0;
    return [c, cb, bal].reduce((a, b) => a > b ? a : b);
  }

  static String formatLiveCoinInteger(dynamic value) {
    if (value == null) return '0';
    final n = value is num ? value.toDouble() : double.tryParse(value.toString());
    if (n == null || n.isNaN || n.isInfinite) return '0';
    return n.toInt().toString();
  }

  /// 与原生 formatUserBalance 一致（礼物面板余额显示）
  static String formatUserBalance(dynamic value) {
    if (value == null) return '0.00';
    if (value is num) return value.toDouble().toStringAsFixed(2);
    final n = double.tryParse(value.toString());
    return n?.toStringAsFixed(2) ?? value.toString();
  }

  static double? _parseNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
