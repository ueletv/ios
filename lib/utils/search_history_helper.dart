import 'package:shared_preferences/shared_preferences.dart';

/// 搜索历史工具（对应 SearchHistoryHelper.kt）
class SearchHistoryHelper {
  static const String _key = 'search_history';
  static const int _maxItems = 10;

  /// 获取搜索历史
  static Future<List<String>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key);
    if (list == null) return [];
    return list;
  }

  /// 添加搜索记录
  static Future<void> addKeyword(String keyword) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    list.remove(keyword); // 去重
    list.insert(0, keyword); // 插入到最前
    if (list.length > _maxItems) {
      list.removeRange(_maxItems, list.length);
    }
    await prefs.setStringList(_key, list);
  }

  /// 删除单条记录
  static Future<void> removeKeyword(String keyword) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    list.remove(keyword);
    await prefs.setStringList(_key, list);
  }

  /// 清除所有搜索历史
  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
